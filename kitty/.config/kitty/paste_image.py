# Ctrl+V (kitty.conf) that also pastes images into Claude Code over ssh.
#
# Claude Code reads a pasted image from the clipboard of the machine it runs on,
# which over ssh isn't this one. So in a window running ssh, with an image on the
# clipboard, this copies the image to the remote /tmp over the same ssh
# destination and pastes its path: Claude Code attaches a pasted image path as
# the image. Anywhere else Ctrl+V goes through to the program unchanged.
import os
import subprocess
import tempfile
import time

from kittens.tui.handler import result_handler
from kitty.fast_data_types import add_timer, remove_timer

from tab_bar import ssh_destination

# Image types Claude Code takes, best first, with the file extension for each.
IMAGE_TYPES = {'image/png': 'png', 'image/jpeg': 'jpg', 'image/gif': 'gif', 'image/webp': 'webp'}
UPLOAD_TIMEOUT = 20  # seconds


def main(args):
    pass


def clipboard_image_type():
    """The best image type on the local clipboard, or None."""
    try:
        listed = subprocess.run(['wl-paste', '--list-types'], capture_output=True,
                                text=True, timeout=2).stdout.split()
    except Exception:
        return None
    return next((t for t in IMAGE_TYPES if t in listed), None)


def notify(summary, body=''):
    subprocess.Popen(['notify-send', '-a', 'kitty', summary, body],
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


@result_handler(no_ui=True)
def handle_result(args, answer, target_window_id, boss):
    window = boss.window_id_map.get(target_window_id)
    if window is None:
        return
    dest = ssh_destination(window)
    mime = dest and clipboard_image_type()
    if not mime:
        window.send_key('ctrl+v')
        return
    argv, host = dest

    # Through a local file, not a pipe, so a slow connect can't block kitty on a
    # full pipe while it writes the image.
    local = tempfile.NamedTemporaryFile(prefix='kitty-paste-', dir=os.environ.get('XDG_RUNTIME_DIR'))
    subprocess.run(['wl-paste', '--type', mime], stdout=local, timeout=5)
    local.seek(0)
    remote = f'/tmp/kitty-paste-{time.strftime("%Y%m%d-%H%M%S")}.{IMAGE_TYPES[mime]}'
    # Options go before the destination; -T so the image doesn't go through a tty.
    cmd = [argv[0], '-T', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=5', *argv[1:], f'cat > {remote}']
    proc = subprocess.Popen(cmd, stdin=local, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    started = time.monotonic()

    def check(timer_id):
        if proc.poll() is None:
            if time.monotonic() - started < UPLOAD_TIMEOUT:
                return
            proc.kill()
            proc.wait()
        remove_timer(timer_id)
        local.close()
        if proc.returncode != 0:
            error = proc.stderr.read().decode(errors='replace').strip().splitlines()
            notify(f'Image paste to {host} failed', error[-1] if error else 'Upload timed out')
            return
        w = boss.window_id_map.get(target_window_id)
        if w is not None:
            w.paste_text(remote)

    add_timer(check, 0.1, True)

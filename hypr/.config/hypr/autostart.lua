-- Extra autostart processes.
-- o.launch_on_start("my-service")
o.launch_on_start("~/.config/hypr/scripts/kitty-copy-osd")
-- Night light on a schedule (hyprsunset.conf): the bar's toggle only starts
-- hyprsunset when pressed, so the 21:00 switch would not happen after login.
o.launch_on_start("hyprsunset")

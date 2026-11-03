# Environment for every shell: read at login, and from ~/.bashrc for the rest.
# Keep it POSIX and safe to source more than once.
[ -r "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

case ":$PATH:" in
  *":$HOME/.dotnet/tools:"*) ;;
  *) export PATH="$PATH:$HOME/.dotnet/tools" ;;
esac

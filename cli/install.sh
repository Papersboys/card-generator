#!/usr/bin/env bash
set -euo pipefail
source_dir=$(cd -- "$(dirname -- "$0")" && pwd)
target_dir="$HOME/.local/lib/link-card"
mkdir -p "$target_dir" "$HOME/bin"
for name in link-card .link-card-create .link-card-show-select .link-card-show link-card-cancel _link_card_display.py; do
  install -m 644 "$source_dir/$name" "$target_dir/$name"
done
chmod 755 "$target_dir/link-card"
if [[ -e "$HOME/bin/link-card" || -L "$HOME/bin/link-card" ]]; then
  backup=$(mktemp "$HOME/bin/link-card.backup.XXXXXX")
  cp -p "$HOME/bin/link-card" "$backup"
  printf 'Previous launcher backed up to %s\n' "$backup"
fi
cat > "$HOME/bin/link-card" <<'LAUNCHER'
#!/usr/bin/env bash
exec bash "$HOME/.local/lib/link-card/link-card" "$@"
LAUNCHER
chmod 755 "$HOME/bin/link-card"
printf 'Installed: %s/bin/link-card\nEnsure $HOME/bin is on PATH.\n' "$HOME"

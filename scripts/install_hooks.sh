#!/usr/bin/env bash
#
# install_hooks.sh — устанавливает git-хуки из scripts/git-hooks/ в .git/hooks/.
# Хуки ставятся символическими ссылками, поэтому правки в scripts/git-hooks/
# сразу применяются без переустановки.
#
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
SRC="$ROOT/scripts/git-hooks"
DST="$(git rev-parse --git-path hooks)"

[[ -d "$SRC" ]] || { echo "install_hooks: нет каталога $SRC" >&2; exit 1; }
mkdir -p "$DST"

chmod +x "$SRC"/* 2>/dev/null || true

for hook in "$SRC"/*; do
  name="$(basename "$hook")"
  # Относительная ссылка от .git/hooks/ к scripts/git-hooks/.
  rel="$(python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$hook" "$DST" 2>/dev/null || echo "$hook")"
  ln -sf "$rel" "$DST/$name"
  echo "→ $name"
done

echo "Хуки установлены в $DST"

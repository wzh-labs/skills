#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$REPO_DIR/skills"
SKILLS_DEST="$HOME/.claude/skills"

mkdir -p "$SKILLS_DEST"

for skill_dir in "$SKILLS_SRC"/*/; do
  skill_name="$(basename "$skill_dir")"
  target="$SKILLS_DEST/$skill_name"

  if [[ -L "$target" ]]; then
    echo "update  $skill_name"
    ln -sfn "$skill_dir" "$target"
  elif [[ -e "$target" ]]; then
    echo "skip    $skill_name (exists, not a symlink)"
  else
    echo "install $skill_name"
    ln -s "$skill_dir" "$target"
  fi
done

ALIASES_SRC="$REPO_DIR/shell/aliases.sh"
ALIASES_DEST="$HOME/.bread-n-butter-aliases.sh"
ZSHRC="$HOME/.zshrc"
SOURCE_LINE="source \"$ALIASES_DEST\""

if [[ -L "$ALIASES_DEST" ]]; then
  echo "update  aliases"
  ln -sfn "$ALIASES_SRC" "$ALIASES_DEST"
elif [[ -e "$ALIASES_DEST" ]]; then
  echo "skip    aliases (exists, not a symlink)"
else
  echo "install aliases"
  ln -s "$ALIASES_SRC" "$ALIASES_DEST"
fi

if [[ -f "$ZSHRC" ]] && ! grep -Fxq "$SOURCE_LINE" "$ZSHRC"; then
  echo "install aliases source line in $ZSHRC"
  printf '\n# bread-n-butter aliases\n%s\n' "$SOURCE_LINE" >> "$ZSHRC"
fi

echo "done"

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
    ln -sf "$skill_dir" "$target"
  elif [[ -e "$target" ]]; then
    echo "skip    $skill_name (exists, not a symlink)"
  else
    echo "install $skill_name"
    ln -s "$skill_dir" "$target"
  fi
done

echo "done"

# bread-n-butter

Personal Claude Code skills and shell aliases.

## Install

```sh
./install.sh
```

This will:

- Symlink each directory in [skills/](skills/) into `~/.claude/skills/`.
- Symlink [shell/aliases.sh](shell/aliases.sh) to `~/.bread-n-butter-aliases.sh` and add a `source` line to `~/.zshrc` (idempotent).

After install, run `source ~/.zshrc` to pick up the aliases in your current shell.

## Layout

- [skills/](skills/) — Claude Code skills, one per subdirectory.
- [shell/aliases.sh](shell/aliases.sh) — shell aliases.
- [install.sh](install.sh) — installer.

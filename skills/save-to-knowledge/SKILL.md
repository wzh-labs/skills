---
name: save-to-knowledge
description: Save the current conversation's raw transcript into the user's knowledge base at `~/knowledge/conversations/YYYY-MM-DD/{slug}.md` and commit it. Use when the user asks to "save this conversation", "save this to knowledge", "archive this chat", "/save-to-knowledge", or otherwise wants the current session preserved for later search. Takes no arguments — picks the current session's JSONL automatically and derives the slug from the conversation's topic.
---

# Save to knowledge

Goal: copy the raw JSONL transcript for the current conversation into `~/knowledge/conversations/YYYY-MM-DD/{slug}.md` and commit it inside that repo. One file per conversation. The destination doubles as a searchable record once the knowledge base re-indexes.

## Inputs

None. The skill always operates on the current Claude Code session.

## Prerequisites

- `~/knowledge` exists and is a git repository (it is — `git remote` points at `wzh-labs/knowledge`).
- Current directory is inside a project that Claude Code is tracking under `~/.claude/projects/`.

## Method

### 1. Locate the current session's transcript

Claude Code writes the live transcript as JSONL under `~/.claude/projects/<project-slug>/<session-id>.jsonl`, where `<project-slug>` is the absolute path of the project with every `/` replaced by `-` (leading `-` included).

```bash
project_slug=$(pwd | sed 's|/|-|g')
proj_dir="$HOME/.claude/projects/$project_slug"
[ -d "$proj_dir" ] || { echo "no Claude project dir for $(pwd)"; exit 1; }

# The current session is the JSONL most recently written to in that dir.
transcript=$(ls -t "$proj_dir"/*.jsonl 2>/dev/null | head -1)
[ -n "$transcript" ] || { echo "no transcript found in $proj_dir"; exit 1; }
session_id=$(basename "$transcript" .jsonl)
```

Sanity-check: the file's mtime should be within the last few minutes. If it's older than ~15 minutes, the session you're saving may not be the active one — surface the mtime and ask the user to confirm before proceeding.

### 2. Determine the date

Use today's local date for the destination directory:

```bash
date_dir=$(date +%Y-%m-%d)
```

Not the transcript's first-message timestamp — `today` is what the user will reach for when looking this up later.

### 3. Generate the slug

You (the model) generate this — you have the conversation in context, the shell doesn't. Pick a short kebab-case slug (2–6 words, lowercase, hyphen-separated, ASCII only) that captures what this conversation was *about*, not what time it happened. Examples:

- A debugging session on a flaky test → `flaky-auth-test-debug`
- Adding a new skill → `add-save-to-knowledge-skill`
- Researching a company → `research-anthropic-2026`

Avoid generic slugs like `chat`, `conversation`, `session`. If the conversation covered multiple unrelated topics, pick the dominant one.

### 4. Resolve collisions

```bash
dest_dir="$HOME/knowledge/conversations/$date_dir"
mkdir -p "$dest_dir"
dest="$dest_dir/$slug.md"

# If a file with this slug already exists today, append a short suffix from the session ID.
if [ -e "$dest" ]; then
  suffix=$(echo "$session_id" | cut -c1-8)
  dest="$dest_dir/$slug-$suffix.md"
fi
```

### 5. Write the file

Wrap the raw JSONL in fenced code so the file stays valid markdown (and so the KB indexer can chunk by heading without choking on JSON braces). Frontmatter records what the model knew at save-time; the JSONL underneath is the source of truth.

```bash
{
  printf -- '---\n'
  printf 'session_id: %s\n' "$session_id"
  printf 'project: %s\n' "$(pwd)"
  printf 'saved_at: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'title: %s\n' "$title"        # one-line human title you generate alongside the slug
  printf -- '---\n\n'
  printf '# %s\n\n' "$title"
  printf '## Raw transcript\n\n'
  printf '```jsonl\n'
  cat "$transcript"
  printf '\n```\n'
} > "$dest"
```

`$title` is a short human-readable sentence (e.g. `Add the save-to-knowledge skill`) — model-generated, same source as the slug.

### 6. Commit

Stage and commit *only* the new file. Do not run `git add -A` — the knowledge repo has its own working state and may have unrelated changes.

```bash
cd "$HOME/knowledge"
rel="conversations/$date_dir/$(basename "$dest")"
git add "$rel"
git commit -m "conversations/$date_dir: $slug" -m "session: $session_id"
```

Do **not** push. The user pushes on their own cadence.

### 7. Report

Print the destination path, the commit short-sha, and the file size. Keep it to ~3 lines.

```
saved   ~/knowledge/conversations/2026-05-13/add-save-to-knowledge-skill.md  (24 KB)
commit  a1b2c3d  conversations/2026-05-13: add-save-to-knowledge-skill
```

## Safety rules

- **Never overwrite an existing file.** Always resolve collisions via the session-ID suffix; do not clobber a prior save.
- **Never `git add -A` or `git add .`** inside `~/knowledge`. Stage the single new file by path.
- **Never push.** Commit only.
- **Never edit or summarize the transcript** before saving. The user said "raw" — pass the JSONL through unchanged inside the fenced block.
- **Do not delete or move the source JSONL** under `~/.claude/projects/`. Claude Code owns that file.

## Failure modes

- **No project dir for `pwd`:** stop with a clear message. The user is in a directory Claude Code hasn't tracked.
- **No JSONL in the project dir:** same — stop, surface the path checked.
- **`~/knowledge` not a git repo:** stop. Tell the user to clone it.
- **Pre-commit hook fails:** the knowledge repo's pre-commit runs `pnpm kb:index` and is documented as soft-failing. If it hard-fails anyway, surface the error and leave the file staged so the user can resolve.
- **Slug collision even with the session-ID suffix:** extremely unlikely (same session saved twice on the same day) — overwrite is still wrong; append a `-2`, `-3`, ... counter and tell the user.

## Style

- Be terse. This is plumbing — three lines of output is plenty.
- Generate slug and title from the *actual* conversation in context, not from generic placeholders. The whole point of saving is searchability later.
- Absolute dates only (`2026-05-13`), never relative.

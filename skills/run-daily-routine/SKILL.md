---
name: run-daily-routine
description: Run the user's configured daily intelligence routine — trending GitHub refresh, delta updates for tracked private companies, and any other configured tasks — then produce a single consolidated morning brief. Use when the user asks to "run my daily routine", "do the morning brief", "what's new today", "run the morning sweep", or similar. Designed to be invoked manually or via `/schedule` on a daily cron. Idempotent — re-running on the same day shows the existing brief unless explicitly forced.
---

# Run daily routine

Goal: orchestrate the user's configured daily intelligence tasks in one pass, dedupe against today's prior run, and produce a single consolidated brief at `~/knowledge/daily-routine/briefs/<today>.md`. Each underlying task (trending GitHub, tracked-company deltas, etc.) is a separate skill — this skill is the conductor, not the player.

## Inputs

All optional:
- **Date override** — `YYYY-MM-DD`, for backfilling a missed day. Defaults to today.
- **Task filter** — comma-separated subset of configured tasks to run (e.g. `trending-github,companies-refresh`). Defaults to all enabled.
- **Force** — re-run even if today's brief already exists. Default: read the existing brief instead.

If invoked with no input, run all enabled tasks for today.

## Storage layout

Root: `~/knowledge/daily-routine/` (override with `$KNOWLEDGE_ROOT/daily-routine/`).

```
~/knowledge/daily-routine/
  config.yaml                 # what to run, in what order, with what args
  briefs/
    YYYY-MM-DD.md             # consolidated brief, one per run-day
  runlog.jsonl                # one line per task execution: status, duration, brief link
```

Per-task outputs live in their own skill's storage (e.g. `~/knowledge/github-trending/`, `~/knowledge/companies/<slug>/`). This skill does **not** duplicate them — it links to them.

## Config

`config.yaml` drives the routine. If it's missing on first run, write a default that reflects current `~/knowledge/` contents and tell the user where it lives so they can edit it.

```yaml
# ~/knowledge/daily-routine/config.yaml
version: 1

tasks:
  - id: trending-github
    enabled: true
    skill: research-trending-github
    args:
      window: daily
      # language: null      # uncomment to filter
      # top_n: 25

  - id: companies-refresh
    enabled: true
    skill: research-private-company
    # If `slugs` is omitted, refresh every directory under ~/knowledge/companies/.
    # If present, refresh only the listed slugs.
    # slugs: [anthropic, openai, vercel]
    parallel: true          # run all company deltas concurrently
    max_concurrent: 5

  # Example custom shell task — runs the command, captures stdout, includes it
  # as a section in the brief. Stderr and non-zero exit are surfaced as warnings.
  # - id: inbox-zero-check
  #   enabled: false
  #   shell: "gh search prs --review-requested=@me --state=open --json number,title,url"
  #   format: json           # json | text | markdown
  #   timeout_seconds: 30

output:
  # If true, the consolidated brief is the user-facing output.
  # If false, only a one-line summary is shown and the brief path is linked.
  inline_full_brief: false

  # Cap on per-task section length when inlining. Longer sections become a link.
  max_section_lines: 80
```

Default config behavior on first run:
- Set `trending-github` enabled if `~/knowledge/github-trending/` exists; otherwise enabled but flag it as "first run" in the brief.
- Set `companies-refresh` enabled with no `slugs` (refresh-all) if `~/knowledge/companies/` has at least one subdirectory; otherwise disabled with a comment explaining why.
- `output.inline_full_brief: false` — most users want the morning brief to fit on a screen.

## Idempotency

Before running anything:
1. Compute target date (input override, else today).
2. Check `briefs/<target>.md`.
3. If it exists and `force` is not set: print a one-line summary (date, task count, status mix) and the brief path. Stop. Do **not** re-run tasks.
4. If `force` is set: archive the existing file as `briefs/<target>__superseded-<HH-MM>.md` before proceeding. Do not silently overwrite.

## Method

### 1. Load and validate config

- If `config.yaml` is missing, write the default (above) and continue.
- If it's malformed, stop with a clear error pointing at the file. Do not "fix" it silently.
- Filter to enabled tasks; apply task-filter input if provided.

### 2. Run tasks

Each task type has its own runner. All independent tasks run in parallel — do not serialize.

**`research-trending-github` task**
- Invoke the skill in delta mode (it self-detects). Pass `window` and any `language` from args.
- Capture: brief path written, NEW / RISING / SUSTAINED / FELL OFF counts, top-3 NEW slugs.

**`research-private-company` task**
- If `slugs` is given, use it. Else `ls ~/knowledge/companies/` and use every subdirectory whose `brief.md` exists.
- For each slug, invoke the skill in delta mode (it self-detects). Run up to `max_concurrent` in parallel.
- Per-slug capture: `material-changes` (changelog entry written) | `no-changes` | `error: <reason>`.
- A company with no changes contributes a one-liner; a company with changes contributes the changelog entry verbatim.

**Shell task**
- Run the configured command with the given timeout. Capture stdout.
- Format the output per `format`. JSON gets pretty-printed in a fenced block; text/markdown is included as-is.
- Non-zero exit becomes a yellow warning in the brief; do not abort the whole routine.

For every task, record one `runlog.jsonl` line:
```json
{"date": "2026-04-26", "task_id": "companies-refresh", "started_at": "07:02:13Z", "duration_s": 38, "status": "ok", "summary": "3 companies, 1 with changes (cursor)", "artifacts": ["~/knowledge/companies/cursor/changelog.md"]}
```

### 3. Aggregate

Build the consolidated brief in this order — sections that produced no signal are dropped, not stubbed:

```
# Daily brief — <YYYY-MM-DD>

**Tasks:** <n total> · <n ok> ok · <n warn> warn · <n error> error · <total wall time>

## TL;DR
3–6 bullets. The most material things across all tasks today.
Cite each bullet to the section that produced it: (see GitHub trending) / (see Cursor delta).

## GitHub trending
<inline summary of NEW + RISING from today's brief, capped at max_section_lines>
Full brief: ~/knowledge/github-trending/briefs/<today>-daily.md

## Tracked companies
For each company that had material changes, the changelog entry verbatim, headed by the slug.
Companies with no changes get a single trailing line: `No material changes: anthropic, openai, vercel.`

## <Custom task sections, in config order>
...

## Warnings & errors
Per task that failed or warned. One line each, with the runlog timestamp.

## Footer
Run started <HH:MM:SS> · finished <HH:MM:SS> · config: ~/knowledge/daily-routine/config.yaml
```

If `inline_full_brief: false`, the user-facing output is **only TL;DR + Warnings & errors + the brief path**. Otherwise output the whole brief.

### 4. Persist

- Write `briefs/<today>.md`.
- Append the runlog lines.
- **Do not** modify per-task storage from this skill — the underlying skills already did that and committed their own changes.

### 5. Git

`~/knowledge` is a git repo. After a successful run:

```bash
cd ~/knowledge
git add daily-routine/
git commit -m "daily-routine: <YYYY-MM-DD> — <one-line task-mix summary>"
git push
```

Underlying skills will have made their own commits during their runs — that's fine; this commit only covers the consolidated brief and runlog. **One commit per routine run.** Do not bundle with anything else, do not `git add -A`, never force-push, never bypass hooks. If push fails, report and stop — the brief on disk is still fine.

## Output format (user-facing)

Default (concise) output:

```
Daily brief — 2026-04-26 · 3 tasks · 2 ok · 1 warn · 47s

TL;DR
- <bullet 1>  (see GitHub trending)
- <bullet 2>  (see Cursor delta)
- <bullet 3>  (see inbox-zero-check)

Warnings
- inbox-zero-check: gh exited 1 (auth token expired)

Full brief: ~/knowledge/daily-routine/briefs/2026-04-26.md
```

If invoked with `force` or if the user asks for the full brief, print the whole consolidated document.

If today's brief already exists and `force` was not set:

```
Already ran today (2026-04-26 at 07:02:13). 3 tasks · 2 ok · 1 warn.
Brief: ~/knowledge/daily-routine/briefs/2026-04-26.md
Pass force=true to re-run.
```

## Style rules

- **Lead with the deltas, not the inputs.** The user knows they ran the routine; they want to know what changed.
- **Cite each TL;DR bullet** to the section it came from. No naked claims.
- **Don't paraphrase the underlying skills' findings** — copy the relevant excerpt and link to the full file. The underlying skills already did the careful sourcing; re-narrating it is a chance to introduce drift.
- **Drop empty sections.** A skill with no findings today gets one line under "Tracked companies" or similar; it does not get its own header.
- **Time everything.** Per-task duration goes into the runlog. Wall time goes into the brief header.
- **Be honest about partial runs.** If 2 of 3 tasks succeeded and 1 errored, the brief leads with the successes but the header and Warnings section make the failure visible — never hide it.

## Failure handling

- **One task failing does not abort the routine.** Capture the error, set status=`error` in runlog, continue with remaining tasks.
- **A task can mark itself `partial`** (e.g. companies-refresh where 2 of 3 companies succeeded). Treat partial as a warning, not an error.
- **Network/rate-limit failures** in an underlying skill bubble up as `error` — do not retry within the routine. The user can re-run with a task filter.
- **If the entire routine fails** (e.g. config malformed, disk full), do not write `briefs/<today>.md`. Surface the failure plainly so the next scheduled run will retry instead of seeing a stale "ok" brief.

## What to skip

- Don't re-do work the underlying skills already did. This skill is a conductor.
- Don't write per-company or per-repo analysis here — that's the underlying skill's job.
- Don't include a "How the routine works" preamble in the brief — the user knows.
- Don't add new task types in code without updating `config.yaml` schema and this skill's Method section together.
- Don't auto-edit `config.yaml` based on heuristics. The config is the user's source of truth; only write it on genuine first run when no file exists.

## Scheduling

This skill is designed to be run by `/schedule` on a daily cron. Suggested invocation:

```
/schedule "every weekday at 7am" "run my daily routine"
```

When invoked from a scheduled run, the skill behaves identically to a manual run except: if today's brief already exists with status=ok, it exits silently with `runlog` appended (`status: skipped-already-ran`) instead of printing the "already ran today" message. This avoids spamming the user when both `/schedule` and a manual `/run` happen on the same day.

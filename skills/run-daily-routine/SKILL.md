---
name: run-daily-routine
description: Run the user's configured daily intelligence routine — trending GitHub refresh, delta updates for tracked private and public companies, a new company discovery, and any other configured tasks — then produce a single consolidated morning brief. Use when the user asks to "run my daily routine", "do the morning brief", "what's new today", "run the morning sweep", or similar. Designed to be invoked manually or via `/schedule` on a daily cron. Idempotent — re-running on the same day shows the existing brief unless explicitly forced.
---

# Run daily routine

Goal: orchestrate the user's daily intelligence tasks in one pass and produce a single consolidated brief at `~/knowledge/daily-routine/briefs/<today>.md`. Each underlying task (trending GitHub, private company deltas, public company deltas, company discovery) is a separate skill — this skill is the conductor, not the player.

## Inputs

All optional:
- **Force** — re-run even if today's brief already exists. Default: read the existing brief instead.

## Tasks

Run these tasks on every invocation:

1. **research-trending-github** — invoke in delta mode (it self-detects) with `window: daily`.
   - Capture: brief path written, NEW / RISING / SUSTAINED / FELL OFF counts, top-3 NEW slugs.

2. **research-private-company** — refresh every subdirectory under `~/knowledge/companies/` whose `brief.md` exists. Invoke each slug in delta mode (it self-detects). Run all slugs concurrently (up to 5 at a time).
   - Per-slug capture: `material-changes` (changelog entry written) | `no-changes` | `error: <reason>`.
   - A company with no changes contributes a one-liner; a company with changes contributes the changelog entry verbatim.
   - If `~/knowledge/companies/` does not exist or has no `brief.md` files, skip silently (no error).

3. **research-public-company** — refresh every subdirectory under `~/knowledge/public-companies/` whose `brief.md` exists. Invoke each ticker/slug in delta mode (it self-detects). Run all concurrently (up to 5 at a time).
   - Per-company capture: `material-changes` (changelog entry written) | `no-changes` | `error: <reason>`.
   - A company with no changes contributes a one-liner; a company with changes contributes the changelog entry verbatim.
   - If `~/knowledge/public-companies/` does not exist or has no `brief.md` files, skip silently (no error).

4. **discover-company** — invoke once per routine to surface one noteworthy company not yet in the knowledge base. It will pick the company, research it, and store its brief.
   - Capture: company name/slug discovered, one-sentence reason it was selected.
   - If discovery fails (e.g. no strong signal), record `no-discovery` and continue.

## Storage layout

Root: `~/knowledge/daily-routine/`.

```
~/knowledge/daily-routine/
  briefs/
    YYYY-MM-DD.md             # consolidated brief, one per run-day
  runlog.jsonl                # one line per task execution: status, duration, brief link
```

Per-task outputs live in their own skill's storage (e.g. `~/knowledge/github-trending/`, `~/knowledge/companies/<slug>/`). This skill does **not** duplicate them — it links to them.

## Idempotency

Before running anything:
1. Check `briefs/<today>.md`.
2. If it exists and `force` is not set: print a one-line summary (date, task count, status mix) and the brief path. Stop. Do **not** re-run tasks.
3. If `force` is set: archive the existing file as `briefs/<today>__superseded-<HH-MM>.md` before proceeding. Do not silently overwrite.

## Method

### 1. Run tasks

All tasks run in parallel — do not serialize.

For every task, record one `runlog.jsonl` line:
```json
{"date": "2026-04-26", "task_id": "companies-refresh", "started_at": "07:02:13Z", "duration_s": 38, "status": "ok", "summary": "3 companies, 1 with changes (cursor)", "artifacts": ["~/knowledge/companies/cursor/changelog.md"]}
```

### 2. Aggregate

Build the consolidated brief in this order — sections that produced no signal are dropped, not stubbed:

```
# Daily brief — <YYYY-MM-DD>

## GitHub trending
<what's new today: NEW repos, notable RISING movers, anything that fell off>
Full brief: ~/knowledge/github-trending/briefs/<today>-daily.md

## Tracked private companies
For each company that had material changes, the changelog entry verbatim, headed by the slug.
Companies with no changes get a single trailing line: `No material changes: anthropic, openai, vercel.`
(Section omitted if no private companies are tracked.)

## Tracked public companies
For each company that had material changes, the changelog entry verbatim, headed by the ticker/slug.
Companies with no changes get a single trailing line: `No material changes: AAPL, NVDA.`
(Section omitted if no public companies are tracked.)

## Company discovery
<name of company discovered, one-sentence rationale, and brief path>
(Section omitted if discover-company returned no-discovery.)

## Warnings & errors
Per task that failed or warned. One line each, with the runlog timestamp.
```

Output the full brief inline in the conversation.

### 3. Persist

- Write `briefs/<today>.md`.
- Append the runlog lines.
- **Do not** modify per-task storage from this skill — the underlying skills already did that and committed their own changes.

### 4. Git

`~/knowledge` is a git repo. After a successful run:

```bash
cd ~/knowledge
git add daily-routine/
git commit -m "daily-routine: <YYYY-MM-DD> — <one-line task-mix summary>"
git push
```

Underlying skills will have made their own commits during their runs — that's fine; this commit only covers the consolidated brief and runlog. **One commit per routine run.** Do not bundle with anything else, do not `git add -A`, never force-push, never bypass hooks. If push fails, report and stop — the brief on disk is still fine.

## Output format (user-facing)

After tasks complete, output the full inline brief directly in the conversation — no truncation, no "see the file" redirect. Structure:

```
# Daily brief — 2026-04-26

## GitHub trending
<what's new today: NEW repos, notable RISING movers, anything that fell off>

## Tracked private companies
<for each company with material changes: the changelog entry>
<companies with no changes: one trailing line listing them>
(omitted if no private companies tracked)

## Tracked public companies
<for each company with material changes: the changelog entry>
<companies with no changes: one trailing line listing them>
(omitted if no public companies tracked)

## Company discovery
<company discovered and rationale>
(omitted if no discovery)

## Warnings & errors
<only if any task failed or warned>
```

If today's brief already exists and `force` was not set:

```
Already ran today (2026-04-26 at 07:02:13). 2 tasks · 2 ok.
Brief: ~/knowledge/daily-routine/briefs/2026-04-26.md
Pass force=true to re-run.
```


## Failure handling

- **One task failing does not abort the routine.** Capture the error, set status=`error` in runlog, continue with remaining tasks.
- **A task can mark itself `partial`** (e.g. companies-refresh where 2 of 3 companies succeeded). Treat partial as a warning, not an error.
- **Network/rate-limit failures** in an underlying skill bubble up as `error` — do not retry within the routine. The user can re-run with `force=true`.
- **If the entire routine fails** (e.g. disk full), do not write `briefs/<today>.md`. Surface the failure plainly so the next scheduled run will retry instead of seeing a stale "ok" brief.

## What to skip

- Don't re-do work the underlying skills already did. This skill is a conductor.
- Don't write per-company or per-repo analysis here — that's the underlying skill's job.
- Don't include a "How the routine works" preamble in the brief — the user knows.


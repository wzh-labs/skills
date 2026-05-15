---
name: full-repo-review
description: Review the repository at the current working directory end-to-end, produce a structured assessment, then build an incremental improvement plan ordered by importance and execute it one PR at a time. Covers architecture, code quality, security, dependencies, tests, CI/CD, and documentation — grounded in the actual code, not vibes. Persists a per-repo profile under `~/knowledge/repos/<slug>/` so re-runs detect repo drift (what changed in the code) and ecosystem drift (what changed in the wider world — deprecations, CVEs, official successors — even if the repo didn't). Takes no arguments and always operates on pwd. After the review, generates an ordered task list and walks through tasks one by one, opening a focused PR for each (gated on explicit user confirmation before the first write). Use when the user asks to "review this repo", "audit this codebase", "do a full repo review", "/full-repo-review", or otherwise wants a holistic read of the repo they're currently in. Distinct from `review-pr` (single PR diff) and the built-in `/review` (local uncommitted changes only).
---

# Full Repo Review

Goal: read the whole repository at `pwd` — not just a diff — and produce a review the user can act on. What's solid, what's weak, what's risky, where to look first. Grounded in the actual code, manifests, and history. Re-runs surface what changed in the repo *and* what changed in the wider ecosystem (deprecations, CVEs, official successors) since the last review. Then convert the findings into an ordered improvement plan and ship them as a sequence of focused PRs — one task per PR, in priority order, gated on user confirmation. The review itself is chat-only and read-only; persistent state lives under `~/knowledge/repos/<slug>/`. Code changes only happen during the execution phase (§11), and only after the user has approved the plan.

## Persistence

State lives under `~/knowledge/repos/<slug>/` and mirrors the existing knowledge-base layout (see `~/knowledge/private-companies/<name>/`):

- **`brief.md`** — the most recent review, in the same structured shape as the chat output.
- **`state.json`** — machine-diffable facts: stack (language, framework, runtime versions), key dependencies + versions, build system, deploy target, default branch, license, last-reviewed commit SHA, last-reviewed timestamp (ISO-8601 UTC). This is what drives drift detection.
- **`changelog.md`** — append-only log of deltas across runs. Each entry: timestamp, *repo drift* lines (what changed in the code), *ecosystem drift* lines (what changed in the world).
- **`snapshots/<YYYY-MM-DDTHHMM>.md`** — timestamped copy of `brief.md` at each run, so old reviews aren't lost when `brief.md` is overwritten.
- **`sources.jsonl`** — one JSON object per line, capturing the URLs hit during ecosystem-drift research (release notes, deprecation announcements, CVE advisories). `{ "url": "...", "title": "...", "fetched_at": "...", "purpose": "..." }`.

**Slug derivation:**
1. If `git remote get-url origin` matches `github.com[:/]<owner>/<repo>(\.git)?` → `<owner>-<repo>` (lowercase, kebab — matches the `private-companies` convention).
2. Else → `basename "$(git rev-parse --show-toplevel)"` (lowercase, kebab).
3. If a collision is plausible (common name like `web` or `api`), prefix with parent directory name.

Create `~/knowledge/repos/<slug>/` (and `snapshots/`) on first run. Never delete existing state — even if the user re-runs and the new review looks different, append to changelog and snapshot the old brief rather than overwriting silently.

## Inputs

**None.** This skill always runs against the current working directory. Do not ask for a path, URL, or repo identifier — if the user offers one, point them at `cd` and re-run from there.

## Prerequisites

- `pwd` must be inside a git repo (`git rev-parse --show-toplevel`). If not, stop with a one-line note.
- `gh` CLI authenticated (`gh auth status`) is **optional** — used for issues, PRs, releases, and CI signal when there's a GitHub remote. If not authenticated or no remote, skip those sections and say so in the output. Do not fail.
- For very large repos: be prepared to sample rather than read every file (see §5).

## Method

### 0. Load prior profile (if any)

Compute the slug per the rules above. Check `~/knowledge/repos/<slug>/state.json`:

- **First run** (no `state.json`): note this — the review will write a fresh profile and there will be no drift sections.
- **Re-run** (`state.json` exists): load it. Record `prior.last_reviewed_sha`, `prior.last_reviewed_at`, `prior.stack`, `prior.dependencies`. You'll use these in §7 and §8.

### 1. Snapshot the repo

Confirm `pwd` is a git repo with `git rev-parse --show-toplevel`. Operate from the repo root regardless of where inside the tree `pwd` is.

Gather a fast snapshot — run these in parallel, they're independent:

```bash
git log --oneline -50                                      # recent activity
git log --format='%an' | sort -u | wc -l                   # contributor count
git log --format='%ad' --date=short | head -1              # last commit date
git log --format='%ad' --date=short | tail -1              # first commit date
git ls-files | wc -l                                        # tracked file count
git ls-files | awk -F. '{print $NF}' | sort | uniq -c | sort -rn | head -10   # file extensions
tokei . 2>/dev/null || cloc . 2>/dev/null || true          # LOC by language if available
```

If the repo has a GitHub remote (`git remote get-url origin` returns a `github.com` URL) and `gh` is authenticated, also fetch repo-health signal — these are optional, skip silently if `gh` errors:

```bash
gh repo view --json name,description,stargazerCount,forkCount,defaultBranchRef,licenseInfo,isArchived,pushedAt,openIssuesCount,languages,topics
gh issue list  --state open --limit 20 --json number,title,labels,createdAt
gh pr list     --state open --limit 20 --json number,title,isDraft,createdAt
gh release list --limit 5 2>/dev/null
```

(`gh` infers `--repo` from the cwd's remote — no need to pass `owner/repo`.)

### 2. Read intent before judging code

Before scanning for issues, read:

- **README** (and `docs/` index, if present) — what is this trying to be?
- **Top-level manifests** — `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `Gemfile`, etc. They reveal language, framework, target runtime, and stated dependencies.
- **`CHANGELOG.md` / recent releases** — what's been shipping?
- **`CONTRIBUTING.md`, `CODEOWNERS`, `.github/`** — what conventions does the project expect?
- **Recent commits + open issues/PRs** — what's the team currently fighting?

A "missing feature" or "weird abstraction" that the README explains away is not a finding. Many bad reviews come from skipping this step.

### 3. Map the architecture

Walk the top-level directory and identify:

- **Entry points** — `main.*`, `index.*`, `app/`, `cmd/`, `bin/`, `pages/`, `server/`.
- **Layers** — frontend, backend, infra, shared libs, generated code.
- **Build system** — `Makefile`, `turbo.json`, `nx.json`, `pnpm-workspace.yaml`, `tsconfig*.json`, `vite.config.*`, `next.config.*`, etc.
- **Runtime / deploy target** — Vercel, Docker, k8s manifests, serverless framework, GitHub Actions workflows.

Sketch the architecture in 2–4 sentences. If you can't, that itself is a finding — the repo's structure is unclear without an architecture doc.

### 4. Verify unfamiliar APIs and frameworks against current docs

If the repo uses third-party APIs, framework patterns, or config you don't recognize confidently from training, **look them up before flagging anything as wrong or outdated**. Training data goes stale. Use `WebFetch` or `WebSearch` against the library's current docs. Only flag a misuse after confirming the current shape of the API.

Skip this for plainly internal code, typos, renames, and obvious one-line issues.

### 5. Scan focus areas

For each area, note issues with `file:line` (or `dir/`) precision. Be specific — vague findings are noise.

**Sampling strategy for large repos.** Don't try to read every file. Cover:
- All top-level entry points and manifests.
- The 10–20 largest non-generated source files (`git ls-files | xargs wc -l | sort -rn | head -30` — filter out lockfiles/vendored).
- 1–2 files per significant subdirectory.
- Files touched in the last 20 commits (recent activity is where bugs live).
- Test directories — sample, don't exhaust.

Note coverage explicitly at the end (§8).

**Architecture & organization**
- Unclear module boundaries; circular dependencies; "kitchen sink" utility files.
- Layering violations (UI reaching into DB, etc.).
- Generated code mixed with hand-written code without clear separation.
- Public surface that leaks internals.

**Code quality & maintainability**
- Dead code, commented-out blocks, TODO/FIXME debt — count and spot-check.
- Functions/files that are far too long; obvious duplication.
- Error handling: swallowed exceptions, generic catches, missing context.
- Inconsistent patterns across similar files (e.g. some routes do auth, others don't).
- Tests that exist but don't actually assert the behavior they claim to.

**Security**
- Secrets in the repo or git history (`git log -p -S 'API_KEY' -S 'SECRET' -S 'PASSWORD' | head -200`, plus a scan of `.env*` files that aren't gitignored).
- Injection sinks reachable from user input (SQL, shell, template, SSRF).
- Authn/authz gaps: missing checks, IDOR patterns, overly broad tokens.
- Unsafe deserialization, path traversal, unsafe `eval`/`exec`/dynamic require.
- Crypto misuse: hardcoded keys, weak primitives, custom crypto.
- CORS / CSP / cookie flags on web endpoints.
- Dependency CVEs — run `npm audit`, `pnpm audit`, `pip-audit`, `cargo audit`, or `gh api /repos/<o>/<r>/dependabot/alerts` if available. Summarize counts; cite the worst.

**Dependencies & supply chain**
- Unmaintained packages (last published >2 years, no recent commits upstream).
- Typosquats or suspicious package names you can't verify on the registry.
- Pinning hygiene: `^` vs exact pins, lockfile committed, multiple lockfiles in conflict.
- License compatibility — surface anything in `node_modules`/manifests that's GPL/AGPL/SSPL when the repo's own license is permissive (or vice versa).
- Native deps / postinstall scripts on packages with low download counts.

**Performance**
- N+1 queries, sync I/O on hot paths, unbounded loops over remote calls.
- Bundle-size red flags on the client (heavy top-level imports, no code-splitting).
- Missing indexes hinted at by query shapes in the data layer.
- Memory: reading whole files when streaming would do, unbounded caches.

**Tests & CI**
- Test coverage by directory (which areas are tested, which aren't). Don't quote a coverage % unless one is generated — eyeball the test/source ratio.
- Are tests run in CI? Required for merge? Look at `.github/workflows/`, `.gitlab-ci.yml`, `circleci/`, etc.
- Flaky-looking tests (network calls without mocks, time-based assertions).
- E2E / integration coverage vs. unit-only.

**Documentation**
- Is the README enough to get someone running locally?
- Are public APIs / exported types documented?
- Are architectural decisions captured anywhere (ADRs, `docs/`)?
- Stale docs — references to removed features, outdated install commands.

**Conventions & consistency**
- Linter/formatter configured + enforced in CI?
- Type checking enforced?
- Commit message / PR template discipline (look at recent commits).
- Naming consistency across the codebase.

### 6. Check repo-health signal (remote only)

From `gh` queries in §1:
- Is the repo archived? Last push date.
- Open issue / PR backlog — count and oldest.
- Release cadence — gaps between recent releases.
- CI: do recent commits on the default branch show green? (`gh run list --branch <default> --limit 10`)

Don't rephrase what `gh` already says — but flag a stale repo, a red default branch, or a months-old open PR backlog as findings.

### 7. Detect drift (re-runs only)

Skip if §0 found no prior profile.

**Repo drift** — diff the prior `state.json` against what you just measured. Surface only meaningful deltas, not cosmetic noise:
- Stack changes: language version bumps, framework major-version bumps, new/removed runtime targets.
- Dependency changes: added/removed top-level deps, version bumps that cross a major boundary, lockfile churn that suggests an upgrade attempt.
- Architecture changes: new top-level directories, abandoned directories, switched build system or deploy target.
- Default branch / license / activity: archived, license changed, default branch renamed.

For each, name the *what changed* and *when* (use `git log -- <path>` if useful).

**Ecosystem drift** — for each significant stored stack item (language, framework, major deps), check the world *now* against where the repo is. This is the part that needs fresh web research — do not rely on training data. Use `WebFetch` / `WebSearch` against official sources:
- Is the version the repo uses **EOL** or past official support? (Cite the vendor's support-matrix page.)
- Does the version have a **known CVE** that's fixed in a later release? (Cite the advisory.)
- Has the upstream project been **deprecated**, **renamed**, **archived**, or **transferred** to a different maintainer? (Cite the announcement.)
- Is there an **official successor or migration guide** published by the same maintainer? (Cite the migration doc — community alternatives don't count.)

Filter discipline: only flag the four categories above. Do NOT flag "there's a newer minor version", "library X is more popular now", or "you could refactor to Y". Those are noise. The bar is *the maintainer or a CVE database told you this matters*.

Record every URL hit during this step for `sources.jsonl`.

### 8. Produce the review

Print one structured block. No preamble.

```
## Repo review — <name> (<pwd>)

**Stack:** <primary language(s) + framework(s)> · **Size:** <LOC or file count> · **Age:** <first commit → last commit>
**Activity:** <commits last 30d> · <contributors total> · <open issues / open PRs if available>
**License:** <license or —> · **Default branch CI:** <green/red/unknown>
**Stated purpose:** <1 sentence from README>
**Profile:** <fresh — first review> | <updated — last reviewed YYYY-MM-DD at SHA <short-sha>>

### Architecture (2–4 sentences)
<What this repo is, how it's laid out, what the major moving parts are.>

### Repo drift (re-runs only; omit section entirely on first run)
<What changed in this repo since the last review. One line per change, with the prior → current values and a citation (`<path>` or commit SHA). Empty section → omit.>

### Ecosystem drift (re-runs only; omit section entirely on first run)
<What changed in the wider world that now matters for this repo's stack. One line per finding: **<tech> <current version>** — <EOL | CVE | deprecated | successor available> per <cited source>. Strict filter per §7. Empty section → omit.>

### Blockers
<Issues that should be fixed before this repo is used / shipped / merged-from. Each: **[area] file:line or dir/** — what's wrong + suggested fix. Empty section if none.>

### Should-fix
<Real issues, not blockers. Same format.>

### Nits & questions
<Style nits, questions for the maintainer, things worth clarifying. Mark questions with `?`.>

### Strengths
<Short. Non-obvious decisions that were clearly right. Skip if nothing stands out — no praise theater.>

### Out of scope (noted, not flagged)
<Things you noticed but won't pursue — pre-existing issues, intentional per the docs, etc. Keep short.>

### Coverage
Read: <N> files across <M> directories. Sampled: <list of areas>. Skipped: <list>.

---
_Profile written to `~/knowledge/repos/<slug>/` — `brief.md`, `state.json`, `changelog.md`, `snapshots/<timestamp>.md`._
```

Each issue line should be one sentence (two if the fix is non-obvious). Cite `file:line` always — no vague "in the auth code". Quote the offending snippet only when the line number alone is ambiguous.

If you couldn't fetch part of the data (e.g. `gh` not authed, no CI configured, empty README), say so explicitly in the relevant section rather than omitting it silently.

### 9. Persist the profile

After printing the chat output, write to `~/knowledge/repos/<slug>/`:

1. **`snapshots/<YYYY-MM-DDTHHMM>.md`** — copy of the chat output (without the footer line). Create the `snapshots/` directory if needed.
2. **`brief.md`** — overwrite with the new chat output. This is always the latest review.
3. **`state.json`** — overwrite with the structured facts you measured:
   ```json
   {
     "slug": "<slug>",
     "last_reviewed_at": "<ISO-8601 UTC>",
     "last_reviewed_sha": "<git rev-parse HEAD>",
     "default_branch": "...",
     "license": "...",
     "archived": false,
     "stack": { "language": "...", "language_version": "...", "framework": "...", "framework_version": "...", "runtime": "...", "deploy_target": "..." },
     "build_system": "...",
     "dependencies": { "<name>": "<version>", ... },
     "size": { "loc": 0, "files": 0 }
   }
   ```
   Include only fields you actually determined — omit unknowns rather than writing `null`.
4. **`changelog.md`** — append (don't overwrite) a new entry:
   ```
   ## <YYYY-MM-DD HH:MM UTC> · <short-sha>

   **Repo drift:**
   - <one line per change, or "—" if none>

   **Ecosystem drift:**
   - <one line per finding, or "—" if none>

   **New findings:** <count of Blockers + Should-fix new since last run, or "first run">
   ```
5. **`sources.jsonl`** — append one JSON line per URL hit during §7's ecosystem-drift research. Skip on first run (no §7).

All writes go to `~/knowledge/repos/<slug>/`. Nothing is written into the repo under review during §1–§9.

### 10. Build an incremental improvement plan

After printing the review and persisting the profile, turn the findings into a concrete task list. Print it in chat under a `## Improvement plan` heading. Also save it to `~/knowledge/repos/<slug>/plan.md` so it survives across sessions.

**What goes in:** every Blocker and Should-fix from §8, plus Nits that are cheap and worth doing. Skip "questions", "out of scope", and anything you flagged as speculative — the plan is for things you're confident are worth changing.

**Ordering rules** (apply in this order — earlier rules outrank later ones):
1. **Severity** — security/correctness blockers before should-fixes before nits.
2. **Risk reduction** — issues that, left alone, will get worse (CVEs, EOL runtimes, growing dead code) before steady-state cleanups.
3. **Dependencies** — if task B is much easier after task A lands (e.g. typecheck-on-CI before fixing type errors), A goes first.
4. **Blast radius** — prefer foundational changes (lint config, CI gate) before broad sweeps that depend on the foundation.
5. **Effort, tiebreaker only** — when two tasks are otherwise equal, smaller PRs first to build momentum and unblock review.

Do NOT reorder by "what's easy to implement" — that produces a plan that ignores risk. Severity wins.

**Each task entry** (numbered, in execution order):

```
### N. [<tag>] <title — imperative, PR-friendly, <60 chars including tag>>

- **Severity:** Blocker | Should-fix | Nit
- **Tag:** <category — see tag list below>
- **Scope:** <files/dirs touched, or "global config">
- **Why:** <1 sentence — what breaks or degrades without this>
- **Change:** <2–4 sentences — what the PR will actually do>
- **Verification:** <how we'll know it worked — tests added, command output, type-check passes>
- **Effort:** S (<1h) | M (a few hours) | L (half-day+)
- **Depends on:** <task N> or —
- **Source:** <link back to the §8 finding it came from — file:line>
```

**Tag categories** (pick the one that best describes the *purpose* of the change — exactly one tag per task, lowercase, in square brackets). Every change technically rearranges code, so **do not use a generic `[refactor]` tag** — pick the tag that names *why* the change exists:
- `[security]` — vulnerability fix, hardening, secret removal, authn/authz fix
- `[bug-fix]` — fixes incorrect behavior
- `[performance]` — speed, memory, bundle size, query efficiency
- `[reliability]` — error handling, retries, timeouts, crash/data-loss prevention
- `[maintainability]` — reducing complexity, dead-code removal, breaking up god-files, clarifying APIs (use only when no more specific tag fits)
- `[deps]` — dependency bumps, removals, lockfile changes
- `[ci]` — CI/CD pipeline, GitHub Actions, build gates
- `[test]` — adding or fixing tests
- `[docs]` — README, comments, ADRs, inline docs
- `[a11y]` — accessibility fixes
- `[i18n]` — localization / internationalization
- `[dx]` — developer-experience improvements (scripts, local-dev ergonomics, error messages)
- `[chore]` — config, formatting, tooling, housekeeping with no behavioral effect
- `[feat]` — new functionality (rare in a review-driven plan; usually only for filling stated-but-missing pieces)

If two tags could apply, pick the one closer to the user-visible outcome (e.g. an N+1 fix is `[performance]`, not `[maintainability]`; sanitizing input is `[security]`, not `[bug-fix]`).

Keep PR scope tight: one task = one PR. If a finding is too big for one PR (e.g. "rewrite auth"), break it into staged tasks (1: add new path behind flag, 2: migrate callers, 3: remove old path) and list them as separate entries with `Depends on:`.

After printing the plan, **stop and ask the user**: "Plan looks like N tasks. Start with task 1, or skip ahead / drop / reorder anything first?" Do not start writing code yet — the plan is a checkpoint, not a green light.

### 11. Execute tasks one PR at a time

Once the user confirms the plan (or a subset / reordering), work through the list in order. **One task → one branch → one PR.** Never batch.

**Pre-flight checks** (run once before starting the first task):

- `git status` is clean. If not, stop and ask the user how to handle the dirty tree.
- **Base branch is `main`.** Every PR opened by this skill targets `main` — no exceptions for stacked PRs, feature branches, or release branches without explicit user direction. Confirm `main` exists locally and on `origin` (`git show-ref --verify refs/heads/main` and `git ls-remote --heads origin main`). If the repo uses `master` or another name as its default, stop and ask the user how to proceed — do not silently substitute.
- `git fetch origin main` and confirm local `main` is up-to-date with `origin/main`. If behind, fast-forward before branching.
- Checkout `main` if you aren't already on it.
- `gh auth status` succeeds (PRs need it). If not, stop — fall back to chat-only output and tell the user to authenticate.

**For each task, in order:**

1. **Restate the task** in one line in chat ("Task 3/8: add typecheck to CI"). This is the cue the user can interrupt before any write.
2. **Branch from `main`.** Re-confirm you're on an up-to-date local `main` (`git fetch origin main && git checkout main && git pull --ff-only origin main`), then `git checkout -b <type>/<short-slug>`. `<type>` matches the change kind in conventions visible in `git log --oneline -50` (commonly `fix/`, `chore/`, `refactor/`, `feat/`, `security/`). Examples: `security/sanitize-redirect-target`, `chore/pin-node-version`. Keep slugs under ~40 chars. Never branch from another feature branch — every PR is rooted at `main`.
3. **Make the change.** Stay strictly within the task's stated scope. If you discover the fix is bigger than scoped, stop, report what you found, and propose splitting — do not silently expand the PR.
4. **Verify the change works.** Run the project's tests / typecheck / linter that actually exercise the change. If the task added a regression test, confirm it fails before the fix and passes after. If the repo has no test infra and verification isn't possible, say so explicitly in the PR body — do not claim "tested" when you didn't.
5. **Commit.** Match the repo's existing commit-message style (look at `git log --oneline -30`). Default to Conventional Commits if the repo has no clear style. One commit per PR is preferred; squash locally if you needed exploratory commits.
6. **Verify the PR contents before submitting.** Before pushing or calling `gh pr create`, audit exactly what the PR will contain by inspecting the diff against `main` — this is the maintainer's first impression and your last chance to catch unintended changes. Run:
   - `git diff main...HEAD --stat` — every file in the PR; confirm each one belongs to the task.
   - `git diff main...HEAD` — read the whole diff. Look for: changes outside the stated scope, leftover debug prints / `console.log` / `dbg!`, commented-out code, TODO markers added by you, secrets or local paths, large auto-formatter sweeps unrelated to the task, accidental whitespace-only churn across many files.
   - `git log main..HEAD --oneline` — the commits the PR will contain match what you intended (no exploratory commits leaked through).
   - `git status` — no stray uncommitted or untracked files that should have been included or `.gitignore`'d.

   If anything looks off, fix it before pushing: `git restore --staged <file>` / `git restore <file>` for unintended changes, amend the commit to drop debug code, or split the PR if the scope ballooned. **Do not push and then fix in follow-up commits** — the human reviewer should see a clean PR, not a noisy history. State in chat what you verified ("Diff is 3 files, 47 lines, all under `src/auth/`. No debug code. ✓") before moving to step 7.
7. **Push and open the PR** with `gh pr create --base main`. PR body template:

   ```
   ## Summary
   <1–3 bullets — what changed and why, in the user's own words>

   ## Why
   From full-repo-review on <YYYY-MM-DD>: <severity> — <one-line finding from §8>.

   ## Changes
   - <file:line> — <what changed>

   ## Verification
   - [x] <command run and what it confirmed>
   - [ ] <anything the reviewer still needs to check manually>

   ## Related
   Task <N> of <total> in the improvement plan (`~/knowledge/repos/<slug>/plan.md`).
   ```

   Set the PR title to the task title from §10, **including the leading `[<tag>]` annotation** (e.g. `[security] sanitize redirect target in auth callback`, `[performance] memoize expensive selector in dashboard`). The tag must match the task's `Tag:` field from §10 — do not invent new tags or drop the brackets. Always pass `--base main` explicitly — do not rely on the remote's default-base inference. Do NOT add `Co-Authored-By` or `Generated with Claude Code` lines unless the user has asked for them — match what the repo's existing PRs do.
8. **Report back** in chat with the PR URL and a one-line status. Then stop and wait. Do not start the next task automatically — the user reviews, merges (or asks for revisions), and tells you to proceed.

**When the user says "do them all" or "keep going without asking":** still pause briefly after each PR to print the URL, but proceed to the next task without waiting. Continue until: the plan is exhausted, a verification fails, a task expands beyond its scoped diff, the user interrupts, or `gh pr create` fails (rate limit, conflict, etc.). On any of those, stop and report.

**Updating the plan as PRs land:** after each merged PR, append a line to `~/knowledge/repos/<slug>/plan.md` under that task: `- Shipped in #<PR>, merged <YYYY-MM-DD>.` If the work changed shape mid-flight (split into two PRs, dropped, deferred), note that on the task too. The plan file is the running record of the improvement effort across sessions.

**Final summary after the last PR.** Once all PRs in the run have been created (plan exhausted, or the user stops the loop), print a single review-order summary in chat — **sorted by effort ascending (S → M → L)** so the smallest, fastest-to-review PRs go first. Ties within an effort bucket: severity (Blocker → Should-fix → Nit). The goal is to give the user a review queue, not a chronological log.

```
## PRs opened — review queue (low effort first)

### S (<1h)
- #<PR> · [Blocker|Should-fix|Nit] · <task title> — <PR URL>
- ...

### M (a few hours)
- #<PR> · ...

### L (half-day+)
- #<PR> · ...
```

Omit any effort bucket that has no PRs. If a task was blocked or skipped, list it in a trailing `### Not shipped` section with the reason — don't silently drop it. This summary is chat-only; do not write it to `plan.md` (per-task shipping lines already live there).

**Failure handling inside a task:**
- Verification fails after the change → fix forward inside the same PR if obvious; otherwise revert local changes, mark the task as blocked in `plan.md`, and surface the blocker to the user before moving on.
- `gh pr create` fails → print the error verbatim, leave the branch in place, do not retry blindly.
- Conflict with main during the task → rebase if trivial; if not, stop and ask. Never `--force` push or `git reset --hard` without explicit user OK.

## Style

- **Be specific.** "Consider refactoring" is noise. Either say what to change or don't say it.
- **Severity discipline.** Most findings are nits; very few are blockers. If everything is a blocker, nothing is.
- **No praise theater.** The user wants problems and a plan, not affirmation. Strengths section is optional and short.
- **Don't speculate.** If you're unsure whether something is a bug, frame it as a question, not a Blocker.
- **Diff what's in front of you.** Don't compare against a hypothetical "ideal" repo. Compare against the project's own stated intent and the conventions visible inside the repo.

## Output destination

The skill has two distinct phases with different write rules.

**Phases §1–§10 (review + plan) are read-only on the repo.** Writes during these phases go only to `~/knowledge/repos/<slug>/` (`brief.md`, `state.json`, `changelog.md`, `snapshots/`, `sources.jsonl`, `plan.md`). Do NOT during these phases:
- Run `gh issue create`, `gh pr comment`, or any other write against issues/discussions.
- Write files into the repo under review.
- Branch, commit, or push.

**Phase §11 (execution) writes to the repo and opens PRs**, but only after the user has explicitly confirmed the plan from §10. Allowed during execution:
- Create branches off the default branch.
- Edit/add/delete files for the scoped task.
- Commit and push the task branch.
- Run `gh pr create` for the task's PR.

Still never, even in execution:
- Push or force-push to the default branch.
- Run `git reset --hard`, delete branches, or rewrite published history without explicit user OK.
- Open more than one PR per task, or bundle multiple tasks into one PR.
- Skip hooks (`--no-verify`) or bypass signing.
- Run `gh issue create` or post comments on existing issues/PRs unless the user asks for it.

If the user only wants the review (and not the plan/execution), they can stop after §9 — confirm with them at the §10 checkpoint. If they want issues filed instead of PRs, that's a separate ask — confirm exactly what to file before running any write.

## Failure modes

- **`pwd` is not inside a git repo:** stop with a one-line note pointing them at `cd`.
- **`gh` not authenticated or no GitHub remote:** review proceeds with local-only signal; skip issue/PR/CI sections and say so in the output. The plan (§10) can still be produced, but warn the user that §11 execution will be blocked until `gh` is authenticated or they switch to a manual workflow.
- **Empty repo / no commits:** stop with a one-line note. Nothing to review.
- **Monorepo with many independent packages:** ask the user whether to review the whole tree or scope to one package before diving in. (If they pick a package, prefix the slug with the package name so it gets its own profile.) PRs from §11 should also stay scoped to that package.
- **Archived / read-only repo (per `gh repo view`):** review anyway, but note the archived state at the top. Skip §11 — opening PRs against an archived repo is a waste of time. Tell the user.
- **`state.json` exists but is malformed:** treat as first run for drift purposes, but back up the broken file to `state.json.bak.<timestamp>` instead of overwriting it silently.
- **Dirty working tree at start of §11:** stop and ask the user how to handle it (stash, commit, or abandon). Do not blindly stash — the dirty state may be in-progress work.
- **No write access to the repo (fork required):** `gh pr create` will fail or ask to fork. Stop and confirm with the user whether to fork-and-PR or just produce patches. Do not auto-fork.
- **Default branch is protected and direct push is required (unusual):** stop and ask — the standard PR flow assumes a branch + PR, not direct pushes.

---
name: research-trending-github
description: Produce a structured brief on what is trending on GitHub right now — daily, weekly, or monthly — with per-repo cards explaining what each project actually is and why it is climbing. Use when the user asks to "show GitHub trending", "what's hot on GitHub", "what AI repos are trending this week", "scan trending Rust projects", "what's new on GitHub today", or similar. Re-runs produce a delta against the last run so the user sees new entrants and movers, not a re-list of the same projects.
---

# Research trending GitHub repos

Goal: produce an honest, signal-dense brief on what is currently trending on GitHub for a given time window. Translate hype into substance — what each project actually does, who is behind it, why it's climbing, and whether it's likely to matter in 30 days.

## Inputs

Required:
- Time window: `daily` (default) | `weekly` | `monthly`

Optional (do not block on these — infer from context):
- Language filter (e.g. `rust`, `python`, `typescript`) — maps to GitHub's language slug
- Topic/category lens (e.g. "AI", "devtools", "databases", "security")
- Number of repos to cover (default 25, hard cap 50)
- "Just new entries" mode — skip repos already covered in the last brief of the same window

If the user just says "what's trending on GitHub", default to `daily`, no language filter, top 25.

## Storage layout

Two roots:

**Knowledge** (`~/knowledge/github-trending/`, override with `$KNOWLEDGE_ROOT`) — briefs and metadata:

```
~/knowledge/github-trending/
  briefs/
    YYYY-MM-DD-<window>[-<lang>].md   # one brief per run
  repos/
    <owner>__<repo>.md                # cumulative per-repo profile, appended each time it trends
  seen.jsonl                           # one line per (date, window, lang, repo) appearance
```

**Source clones** (`~/src/`, override with `$SRC_ROOT`) — every covered repo's working tree:

```
~/src/
  <repo>/                              # `git clone` of each trending repo (depth=1 by default)
```

If two trending repos share a name (`foo/bar` and `baz/bar`), disambiguate the second with `<repo>__<owner>` so we never silently overwrite an existing clone.

`<window>` is `daily` | `weekly` | `monthly`. `<lang>` is the language slug if filtered, otherwise omitted from the filename.

**Mode selection:** look for the most recent brief matching the same `(window, lang)` tuple in `briefs/`.
- No prior brief → **initial mode**.
- Prior brief exists → **delta mode**.

Always check first with `ls ~/knowledge/github-trending/briefs/` before deciding.

## Modes

### Initial mode

1. Run the full method below.
2. Write `briefs/<today>-<window>[-<lang>].md`.
3. For every covered repo, create or append to `repos/<owner>__<repo>.md` (see per-repo profile format).
4. Append one line per repo to `seen.jsonl`.
5. Output the full brief to the user.

### Delta mode

1. Load the previous matching brief and the slugs it covered.
2. Run the full method, biasing toward this window's data.
3. Bucket each currently-trending repo as **NEW** (not in last brief), **RISING** (was in last brief, rank improved), **SUSTAINED** (was in last brief, similar rank), **FALLING** (was in last brief, dropped significantly), **FELL OFF** (was in last brief, no longer in top N).
4. Output structure favors NEW and RISING. Do not re-summarize SUSTAINED repos in detail — just list them with a one-line "still trending" note.
5. Update `repos/<owner>__<repo>.md` for every covered repo (new appearance row + any changed metadata).
6. Append `seen.jsonl` records.
7. Write the new brief to `briefs/`.
8. User-facing output: the delta brief itself. Do not silently say "no changes" — the trending list always changes some between runs; if the entire top N is identical, that itself is the finding and is worth saying explicitly.

## Method

### 1. Fetch the trending list

Primary source: `https://github.com/trending` (HTML page, scrapable via WebFetch).
- Daily: `https://github.com/trending`
- Weekly: `https://github.com/trending?since=weekly`
- Monthly: `https://github.com/trending?since=monthly`
- Language filter: `https://github.com/trending/<language>?since=<window>` (e.g. `/trending/rust?since=weekly`)

WebFetch the page and extract the ordered list of repos with: `<owner>/<repo>`, one-line description, primary language, total stars, stars gained in the window, today's "Built by" avatars (proxy for contributor cohort), forks.

If the page is unreachable or rate-limited, fall back to GitHub Search API via `gh` CLI if available:
```
gh api -X GET search/repositories \
  -f q='created:>YYYY-MM-DD stars:>500' \
  -f sort=stars -f order=desc -f per_page=50
```
This is a *fallback*, not a substitute — the search API does not perfectly match `/trending` ranking (which uses GitHub's internal momentum signal). Note in the brief if you fell back.

### 2. Enrich each repo (parallel)

For each of the top N repos, in parallel, gather:
- Repo metadata: full description, license, default branch, primary + secondary languages, topics/tags, archived status, fork status, age (created date), last commit date.
- Stars total + stars-this-window (already from trending page).
- Open issues count, open PRs count.
- README first ~200 lines (enough to know what it actually does).
- Owner type (User vs Organization) and any signal on who they are (bio, other notable repos, company affiliation).

Use `gh repo view <owner>/<repo> --json ...` if available, otherwise WebFetch the repo page + `/blob/<default>/README.md`.

### 3. Clone & analyze each repo (parallel)

For every covered repo, materialize it locally so analysis is grounded in real code, not the README's claims.

**Clone:**
```
cd ~/src
# Skip if directory exists
[ -d "<repo>" ] && (cd "<repo>" && git fetch --depth=1 origin && git reset --hard origin/<default>) \
                || git clone --depth=1 https://github.com/<owner>/<repo>.git
```

- Use `--depth=1` by default. If the analysis needs commit history (e.g. measuring contributor breadth), `git fetch --unshallow` on demand for that repo only.
- If the repo is large (`> 500 MB` shown on the GitHub page or clone takes > 60s), abort the clone and fall back to a sparse checkout of just `README*`, `package.json`/`Cargo.toml`/`pyproject.toml`/`go.mod`, `LICENSE`, and the top 20 source files. Note in the card that the analysis was shallow.
- If cloning fails (private, rate-limit, network), record the failure in the card and proceed with API+README data only — do not block the brief on a single clone.
- Run clones in parallel (background Bash) but bound concurrency to ~5 to avoid hammering GitHub.

**Analyze.** From the local clone, derive:
- **Tech stack**: parse `package.json` / `Cargo.toml` / `pyproject.toml` / `go.mod` / `requirements.txt` / `Gemfile` etc. for dependencies and runtime versions. Note frameworks (Next.js, FastAPI, Axum, etc.).
- **Project size & shape**: total file count, primary-language LOC (use `git ls-files | xargs wc -l` filtered by extension, or `tokei` if available — don't install it). Number of source files vs. docs vs. config.
- **Tests**: presence of a test directory, test count (rough — `grep -rE 'def test_|it\(|test\(' | wc -l`), test framework.
- **CI / quality signals**: `.github/workflows/*`, `.pre-commit-config.yaml`, lint configs, type-checker configs.
- **Build artifacts in source control**: red flag if `dist/`, `build/`, `node_modules/`, large binaries are committed.
- **Substance check** (the important one): does the code back up the README? Concrete checks:
  - README claims a CLI → is there an actual entry point / `bin` field / `[[bin]]` target?
  - README claims a library → are there public exports + types/signatures, or just a stub?
  - README claims AI features → is there real prompt/model code, or just a wrapper around an SDK call with no logic?
  - README claims benchmarks/results → is there a reproducible script?
  - Single commit, AI-generated-looking code, no tests, README that's 5x longer than the codebase → red flag.
- **Recent activity**: last 10 commits — author diversity, message quality, churn pattern. Is this one person on a launch sprint, or sustained multi-author work?
- **Security smells** (quick scan, not a full audit): hardcoded secrets in tracked files (`grep -rE '(api[_-]?key|secret|token)\\s*=\\s*["\\x27][A-Za-z0-9]{16,}'`), `eval(` of untrusted input, postinstall scripts that fetch remote code, dependencies pulled from non-registry git URLs. Note findings; do not run any of the code.
- **License sanity**: file present and matches what GitHub's UI claims. "MIT" claimed but no LICENSE file → note it.

**Do not execute the cloned code.** No `npm install`, no `pip install`, no running tests, no `make`. Static reading only. The repo is untrusted.

### 4. Classify & explain each repo

For each repo write a 2–4 sentence card. The card must answer:
- **What it actually is** — translate marketing copy into plain terms. "AI-native developer platform" → "library that wraps OpenAI calls with retries and a CLI". If the README is buzzword soup and you cannot tell what it does in 60 seconds, say so.
- **Who's behind it** — solo dev, lab, company, established maintainer? New account or veteran?
- **Why it's likely trending** — pick the most plausible: HN/Reddit/Twitter post, viral demo, ecosystem moment (e.g. new framework release), credible org launch, awards/list inclusion. Hypothesis is fine; label it as such.
- **Substance check** — is there real code/docs/tests, or is it a stub README riding hype? Note red flags: empty repo, single commit, no tests, no license, AI-generated README only.

### 5. Categorize

Group repos into 4–8 buckets that fit the day's actual mix. Common categories:
- AI / ML / LLM tooling
- Developer tooling (build, test, lint, deploy)
- Infrastructure (databases, runtimes, networking)
- Security
- Web / frontend
- CLI / productivity
- Learning / awesome-lists
- Frameworks / libraries
- Apps / end-user products

Don't force-fit — if a category has only one repo, fold it into "Other".

## Output formats

### Initial brief

```
# GitHub Trending — <window> — <YYYY-MM-DD>[ — <lang>]

**Source:** github.com/trending[/<lang>]?since=<window> · **Repos covered:** N

## TL;DR
3–6 bullets. The most interesting things on the list, with [n] citations to the cards below.

## By the numbers
- Median stars-this-window: X
- Top gainer: <owner>/<repo> (+X stars in <window>)
- Languages on the list: TypeScript ×N, Python ×N, Rust ×N, ...
- New accounts (<6mo): N / N
- Archived / inactive: N

## <Category 1>

### 1. <owner>/<repo>  ·  ★ total / +Δ this <window>  ·  <lang>  ·  <license>
**What:** <plain-English what-it-is>
**Who:** <maintainer signal>
**Why trending:** <hypothesis, labeled>
**Stack:** <runtime/framework + 2-4 key deps from package manifest>
**Shape:** <LOC, file count, tests yes/no, CI yes/no>
**Substance:** <green | yellow | red> — <one sentence grounded in what's actually in the clone, not the README>
**Local:** `~/src/<repo>` <(shallow)|(sparse)|(clone failed: reason)>
[link]

### 2. ...

## <Category 2>
...

## Skips & red flags
Repos in the trending list that look like noise (empty, AI-spam README, scam, etc.) and were intentionally not given a full card. One line each.

## Sources
Numbered URLs cited in TL;DR.
```

### Delta brief

```
# GitHub Trending — <window> — <YYYY-MM-DD>[ — <lang>]   (delta vs <prev-date>)

**Movement:** N new · N rising · N sustained · N fell off

## NEW this <window>
Full cards for every NEW repo, grouped by category.

## Rising
Cards for repos that climbed materially. Note rank delta or stars-gained delta.

## Sustained
One-line entries: `<owner>/<repo> — still trending (rank ~X, +Δ stars).` No re-summary.

## Fell off
One-line entries for repos that were in the last brief but are no longer in the top N. Worth noting: a repo that trended hard then vanished in 24h is itself a signal.

## Sources
```

### Per-repo profile (`repos/<owner>__<repo>.md`)

Frontmatter is the source of truth — keep it stable across appearances so trend rollups work later.

```yaml
---
slug: <owner>/<repo>
url: https://github.com/<owner>/<repo>
local_path: ~/src/<repo>
clone_status: ok | shallow | sparse | failed
language: <primary>
languages: [<primary>, <secondary>, ...]
license: <spdx | unknown>
created: YYYY-MM-DD
owner_type: user | org
stack:
  runtime: <node20 | python3.12 | rust1.79 | ...>
  framework: <next | fastapi | axum | ...>
  key_deps: [<dep>, <dep>, <dep>]
shape:
  files: <int>
  primary_loc: <int>
  has_tests: true | false
  has_ci: true | false
substance: green | yellow | red
appearances:
  - date: YYYY-MM-DD
    window: daily | weekly | monthly
    rank: <int>
    stars_total: <int>
    stars_in_window: <int>
    lang_filter: <lang | null>
    head_sha: <short-sha-at-time-of-analysis>
---
```

Below the frontmatter, a free-form notes section appended each time the repo trends — what changed since last appearance (new release, dependency churn, fork from another project), and any code-level observations from the local analysis worth surfacing. Newest entry on top.

### seen.jsonl format

One JSON object per line:

```json
{"date": "2026-04-26", "window": "daily", "lang": null, "slug": "vercel/ai", "rank": 3, "stars_in_window": 412}
```

## Style rules

- **Plain English over marketing.** "GPT-powered terminal assistant" beats "AI-native developer experience platform". If the README is buzzword soup, say "marketing copy is unclear" rather than parroting it.
- **Honest hypotheses, labeled.** "Likely trending due to a Hacker News post on <date> (unverified)" is fine. Confident-sounding fake explanations are not.
- **Star counts in context.** A repo gaining 5K stars in a day is different from a repo at 80K total gaining 200. Always show both.
- **Substance over hype.** Treat 1-day-old repos with a polished README and no code as suspicious. Single-commit repos with `awesome-` in the name are usually content marketing — note it.
- **Cite links inline.** Every card ends with the GitHub URL. TL;DR claims that reference external context (a viral tweet, an HN thread) get a `[n]` citation.
- **Be skeptical of "AI" label inflation.** Half of GitHub trending will claim AI relevance. Reserve the AI bucket for projects where AI is the actual point, not where it's a feature.
- **Don't pad.** A trending list with 5 substantive repos and 20 noise repos should be a brief with 5 cards and a "Skips" section, not 25 forced cards.
- **Frontmatter consistency.** If you mention a fact in the per-repo profile body, mirror it in the frontmatter when it fits a defined field.
- **Code analysis is grounded, not guessed.** Every `Stack` / `Shape` / `Substance` claim must come from a file you actually read in the local clone. If a clone failed, say so on the card — don't infer stack from the README.
- **End the brief with a footer** pointing at the local clones: `Local clones in ~/src/ — read-only analysis, do not run.`

## Safety

- **Never execute cloned code.** No `npm install`, `pip install`, `cargo build`, `make`, `./script.sh`, no running tests, no `node -e`, no `python -c`. Static reading and `git` operations only.
- **Never source / dot-include / open in an interpreter** any file from a clone. Treat every clone as untrusted, even from well-known orgs — typosquatted forks land on trending too.
- **Never paste cloned content into a chat tool, gist, or external service.** Some trending repos are exfil bait.
- If the user later asks to *run* a trending repo, that's a separate request — they should review it themselves first, and ideally use [vercel-plugin:vercel-sandbox] for isolation.

## What to skip

- Don't lecture about how GitHub trending works.
- Don't include "Conclusion" or "Why this matters" generic sections.
- Don't fabricate star counts, contributor counts, or "trending because of <viral post>" if you didn't actually find the post.
- In delta mode, don't re-summarize SUSTAINED repos — the user already saw them yesterday.
- Don't recommend installing or using any of the trending repos. The brief reports; it does not endorse.
- Don't delete or `git clean` clones from previous runs unless the user asks. They're useful for diffing across days.

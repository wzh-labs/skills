---
name: research-private-company
description: Produce a structured intelligence brief on a private company, or a delta if the company has been researched before. Use when the user asks to research, look up, refresh, do diligence on, or build/update a profile of a non-public company (e.g. "research Anthropic", "what's new with Cursor", "due diligence on Linear"). Aggregates funding, people, product, market, traction, and risk signals from multiple public web sources, and stores findings so re-runs only surface what changed.
---

# Research a private company

Goal: produce an accurate, well-sourced brief about a private (non-public) company, OR — if the company has been researched before — produce a *delta* showing only what has changed since the last run. Optimize for *signal density* — every claim should be useful and traceable to a source.

## Inputs

Required:
- Company name

Optional (ask only if the name is genuinely ambiguous):
- Website / domain
- Country or HQ city
- Approximate stage
- Specific angle the user cares about (investment diligence, competitive analysis, sales prep, partnership eval)

If the user didn't specify the angle, infer from context but don't block on it.

## Storage layout

All findings live under `~/knowledge/private-companies/` (override with `$KNOWLEDGE_ROOT`). One directory per company:

```
~/knowledge/private-companies/<slug>/
  brief.md          # current canonical brief: YAML frontmatter + narrative
  changelog.md      # append-only delta log, newest on top
  snapshots/
    YYYY-MM-DD.md   # frozen point-in-time copies of brief.md
  sources.jsonl     # every cited URL with first-seen date and content hash
```

`<slug>` is `kebab-case-of-company-name`. **If `brief.md` exists, run in delta mode. Otherwise run in initial mode.** Always check first with `ls` or equivalent before deciding.

## Modes

### Initial mode (first time researching)

1. Run the full method (below).
2. Write `brief.md` with frontmatter + narrative.
3. Copy it to `snapshots/<today>.md`.
4. Create `changelog.md` with one entry: `## <today>\n- Initial brief.`
5. Write every cited URL into `sources.jsonl` with today's date.
6. **Commit and push** (see *Git workflow* below).
7. Output the full brief to the user.

### Delta mode (re-researching)

1. Load `brief.md`'s frontmatter and `sources.jsonl`.
2. Run the full method, but bias searches toward recency (e.g. add `after:<last_researched>` or current-year qualifiers). The goal is to find what's new, not to re-confirm what's known.
3. Compute the delta:
   - **Frontmatter diffs:** new funding round, headcount change, founder/exec additions or departures, stage change, new investors, new disclosed customers/competitors, status change (acquired/shutdown).
   - **New sources:** any cited URL not already in `sources.jsonl`.
   - **Content drift:** if a previously-cited URL still resolves, hash its current content. If the hash changed materially (e.g. About page rewrite), note it.
4. If the delta is empty, output one line: *"No material changes since YYYY-MM-DD."* Do not modify any files.
5. If the delta is non-empty:
   - Update `brief.md` frontmatter to current values; update narrative sections that materially changed.
   - Freeze a new `snapshots/<today>.md` copy.
   - Prepend a new dated entry to `changelog.md` with the deltas.
   - Append new cited URLs to `sources.jsonl`; update `cited_in` arrays for re-cited URLs.
   - **Commit and push** (see *Git workflow* below).
   - Output **only the changelog entry** to the user — not the full brief. Mention the brief path so they can open it for context.

Defaults for what counts as a change:
- **Strict frontmatter fields**: funding, arr, people, headcount, stage, investors, customers, competitors, status. Always reported.
- **Cited-only source ledger**: only URLs actually cited in the brief land in `sources.jsonl` — not every URL searched. Keeps the ledger meaningful and small.

## Git workflow

`~/knowledge` is a git repository. Every successful research run must be committed and pushed so the corpus has a durable history.

Run from `$KNOWLEDGE_ROOT` (default `~/knowledge`):

```bash
git add private-companies/<slug>/
git commit -m "<message>"
git push
```

Commit message format:
- **Initial mode:** `research(<slug>): initial brief`
- **Delta mode:** `research(<slug>): <YYYY-MM-DD> — <one-line delta summary>` (e.g. `research(cursor): 2026-05-10 — Series C $80M, CFO departed, headcount 240→310`)

Rules:
- **Stage explicitly** — `git add private-companies/<slug>/`. Never `git add -A` or `git add .` (other unrelated work may be in flight elsewhere in the repo).
- **No commit on empty delta.** If the run produced no file changes, do not create a commit.
- **One commit per company per run.** Don't bundle multiple companies in one commit.
- **If `git push` fails** (no upstream, network, conflict), report the failure and stop. Do not force-push, do not rewrite history, do not bypass hooks. The local commit is still on disk; the user can resolve and push manually.
- **Never** run destructive git operations (`reset --hard`, `push --force`, branch deletion) as part of this skill.

## Method

### 1. Disambiguate first

If the name could match multiple companies (common word, namespace clash, defunct vs. active), do **one** quick web search and ask a single clarifying question only if real ambiguity remains.

### 2. Gather in parallel

Issue web searches and fetches in parallel — do not serialize them. 6–12 searches in the first batch covering distinct angles:

- `<company> funding round investors crunchbase`
- `<company> founders CEO leadership team`
- `<company> employees headcount linkedin`
- `<company> product pricing customers`
- `<company> competitors vs alternatives`
- `<company> revenue ARR growth`
- `<company> news <current year>`
- `<company> layoffs OR lawsuit OR controversy`
- `<company> jobs hiring engineering`
- `site:<company-domain> about` and `site:<company-domain> blog` if a domain is known
- `<company> github` if it's plausibly technical / dev-tools

Then `WebFetch` the highest-value pages: company About, Crunchbase profile, Wikipedia entry, recent reputable news, jobs page.

### 3. Cross-check

Quantitative claims (funding total, valuation, headcount, ARR) require **two independent sources** or get labeled `(reported by <source>, unverified)`. Be skeptical of:
- Self-reported headcount (LinkedIn count is a floor, not truth)
- Valuations from press leaks vs. confirmed rounds
- ARR claims in PR / blog posts
- Stale snapshots (a 2022 Crunchbase figure is not current)

Surface disagreements rather than picking one silently.

### 4. Note what's missing

A private company brief is always incomplete. Call out unknowns explicitly (e.g. "no public revenue figure", "burn rate not disclosed", "board composition unclear"). Missing data is itself a signal.

## Frontmatter schema

`brief.md` starts with this YAML block. Keep field names stable across companies — they're how trend queries work later.

```yaml
---
name: <Company Name>
slug: <kebab-case>
domain: <example.com>
hq: <City, Country>
founded: <YYYY>
status: active           # active | acquired | shutdown | unknown
stage: series-b          # pre-seed | seed | series-a | ... | series-d-plus | growth | late
sectors: [ai-infra, devtools]
last_researched: <YYYY-MM-DD>

founders:
  - name: <Name>
    role: CEO
    prior: [<Company>, <Company>]
executives:
  - name: <Name>
    role: <Title>
    joined: <YYYY-MM>

headcount:
  value: <int>
  as_of: <YYYY-MM-DD>
  source: <linkedin | press | self-reported>

funding:
  total_raised_usd: <int|null>
  last_round:
    round: series-b
    date: <YYYY-MM>
    amount_usd: <int>
    lead: <Investor>
    post_money_usd: <int|null>
  rounds:
    - round: <seed|series-a|...>
      date: <YYYY-MM>
      amount_usd: <int>
      lead: <Investor>

arr:
  value_usd: <int|null>     # most recent disclosed/reported ARR
  as_of: <YYYY-MM>          # period the figure refers to
  source: <press | self-reported | leaked | estimate>
  confidence: <high | reported-unverified | rumor>
  history:                  # prior data points, oldest first — enables growth-rate trend
    - value_usd: <int>
      as_of: <YYYY-MM>
      source: <...>

investors: [<Investor>, <Investor>]
competitors: [<Co>, <Co>]
customers: [<Co>, <Co>]   # publicly disclosed only
---
```

Use `null` for unknown numerics. Omit list fields entirely when unknown rather than writing `[]` — `[]` means "actively confirmed none".

## Output formats

### Initial brief (initial mode)

After the frontmatter, the narrative `brief.md` body:

```
# <Company Name>

**One-liner:** <what they do, in one sentence>
**HQ:** <city, country> · **Founded:** <year> · **Stage:** <stage>
**Website:** <url>

## Snapshot
3–6 bullets: the things a smart reader most needs to know first.

## Product & business
What the product is, who buys it, pricing, GTM motion.

## People
Founders (with prior-company signal). Key execs / recent senior hires. Headcount + trend.

## Funding & financials
| Round | Date | Amount | Lead | Post-money |
|-------|------|--------|------|------------|
Total raised, notable investors. **ARR**: state the most recent figure with `as_of` period, source, and confidence label; if multiple data points exist, compute and call out the implied growth rate (e.g. "$40M ARR as of 2025-Q4, up from $12M in 2024-Q4 — ~3.3x YoY [n], reported, unverified"). If no public ARR figure exists, say so explicitly — don't omit the line.

## Market & competition
Market, named competitors, positioning.

## Traction & momentum signals
Customer logos, partnerships, hiring velocity, product launches, press trend.

## Risks & open questions
Concrete risks. Things you couldn't verify and why they matter.

## Sources
Numbered list of URLs actually used, with one-line annotation each.
```

### Changelog entry (delta mode)

Prepend to `changelog.md`:

```
## <YYYY-MM-DD>
- **Funding:** <round / amount / lead, or omit line if no change>
- **ARR:** <prev → curr (+/- %, since prev_as_of), source, confidence label>
- **People:** <hires, departures, role changes>
- **Headcount:** <prev → curr (+/- %, since prev_date)>
- **Product:** <new launches, pricing changes, positioning shifts>
- **News:** <1–3 most material items, with [n] citations>
- **Risks:** <new risks or risks resolved>
- **Sources added:** <n> new URLs — summarize what they say, don't just count
```

Drop any bullet whose answer is "no change". The user-facing output in delta mode is exactly this entry plus a single trailing line: *"Full brief at `<path>`. Snapshot frozen at `<snapshot-path>`."*

### sources.jsonl format

One JSON object per line:

```json
{"url": "https://...", "first_seen": "2026-04-26", "cited_in": ["2026-04-26", "2026-05-10"], "content_hash": "<sha256-prefix>", "note": "Crunchbase profile"}
```

## Style rules

- **Cite inline** with `[1]`, `[2]`, ... matching the Sources list. Every non-trivial claim gets a citation.
- **Dates matter.** Prefer "as of <month year>" over "recently". Note when a figure is stale.
- **No marketing language.** Don't repeat the company's own taglines as fact. Translate "AI-native platform for X" into what it actually is.
- **No fabrication.** If you don't have a number, say so. Never estimate a valuation, headcount, or revenue unless you label it clearly as an estimate and show the reasoning.
- **Confidence labels** on soft claims: `(high confidence)`, `(reported, unverified)`, `(rumor)`.
- **Be concise.** A useful brief is 400–900 words plus the funding table.
- **Frontmatter is the source of truth for trends.** If you state a fact in the narrative, mirror it in frontmatter — otherwise corpus rollups will miss it.

## What to skip

- Don't lecture about how to research private companies — just do it.
- Don't include generic "Why this matters" / "Conclusion" sections.
- Don't speculate about acquisition prospects unless asked.
- Don't pull from sources you didn't actually fetch (no phantom citations).
- In delta mode, don't re-output the full brief — the user wants the diff.

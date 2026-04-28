---
name: research-public-company
description: Produce a structured intelligence brief on a public company from fundamentals to industry trends, or a delta if the company has been researched before. Use when the user asks to research, analyze, or profile a public company by ticker symbol (e.g. "$GOOGL", "$AAPL", "$NVDA") or company name. Covers financials, business segments, management, competitive position, industry trends, analyst sentiment, and risk factors.
---

# Research a public company

Goal: produce a dense, well-sourced intelligence brief on a publicly traded company, from financial fundamentals to industry positioning — OR, if the company has been researched before, a *delta* showing only what changed since the last run. Prioritize accuracy and recency over comprehensiveness; call out stale or unverified data explicitly.

## Inputs

Required (one of):
- Ticker symbol — `$GOOGL`, `NVDA`, `MSFT` (strip the `$` prefix if present; normalize to uppercase)
- Company name — resolve to the primary ticker before proceeding

**Ticker resolution**: if the user gives a company name without a ticker, do a quick web search (`<company> stock ticker`) and confirm before proceeding. If the ticker maps to multiple share classes (e.g. GOOG vs GOOGL), use the more liquid class and note the other.

## Storage layout

All findings live under `~/knowledge/public-companies/` (override with `$KNOWLEDGE_ROOT`). One directory per ticker:

```
~/knowledge/public-companies/<TICKER>/
  brief.md          # current canonical brief: YAML frontmatter + narrative
  changelog.md      # append-only delta log, newest on top
  snapshots/
    YYYY-MM-DD.md   # frozen point-in-time copies of brief.md
  sources.jsonl     # every cited URL with first-seen date and content hash
```

`<TICKER>` is the uppercase ticker symbol (e.g. `GOOGL`, `NVDA`). **If `brief.md` exists, run in delta mode. Otherwise run in initial mode.** Always check with `ls` or equivalent before deciding.

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
2. Run the full method, biasing searches toward recency (e.g. add `after:<last_researched>` or the current quarter as a qualifier). Goal: find what's new, not re-confirm what's known.
3. Compute the delta:
   - **Frontmatter diffs:** revenue or earnings revision, guidance change, new segment, CEO/CFO change, M&A announcement, material dividend/buyback change, rating change, index inclusion/exclusion.
   - **New sources:** any cited URL not already in `sources.jsonl`.
   - **Content drift:** if a previously-cited page still resolves and its content hash changed materially (e.g. IR page updated guidance), note it.
4. If the delta is empty, output one line: *"No material changes since YYYY-MM-DD."* Do not modify any files.
5. If the delta is non-empty:
   - Update `brief.md` frontmatter to current values; update narrative sections that materially changed.
   - Freeze a new `snapshots/<today>.md` copy.
   - Prepend a new dated entry to `changelog.md` with the deltas.
   - Append new cited URLs to `sources.jsonl`; update `cited_in` arrays for re-cited URLs.
   - **Commit and push** (see *Git workflow* below).
   - Output **only the changelog entry** to the user — not the full brief. Mention the brief path so they can open it for context.

Defaults for what counts as a change:
- **Strict frontmatter fields**: revenue, eps, guidance, market cap, price, dividend, buyback, key executives, segment mix, rating consensus. Always reported.
- **Cited-only source ledger**: only URLs actually cited in the brief land in `sources.jsonl`. Keeps it small and meaningful.

## Git workflow

`~/knowledge` is a git repository. Every successful research run must be committed and pushed.

Run from `$KNOWLEDGE_ROOT` (default `~/knowledge`):

```bash
git add public-companies/<TICKER>/
git commit -m "<message>"
git push
```

Commit message format:
- **Initial mode:** `research($TICKER): initial brief`
- **Delta mode:** `research($TICKER): <YYYY-MM-DD> — <one-line delta summary>` (e.g. `research($NVDA): 2026-04-28 — Q1 beat, raised FY guidance, Jensen interview`)

Rules:
- **Stage explicitly** — `git add public-companies/<TICKER>/`. Never `git add -A` or `git add .`.
- **No commit on empty delta.** If the run produced no file changes, do not create a commit.
- **One commit per ticker per run.** Don't bundle multiple companies in one commit.
- **If `git push` fails** (no upstream, network, conflict), report it and stop. Do not force-push or rewrite history. The local commit remains on disk.
- **Never** run destructive git operations as part of this skill.

## Method

### 1. Resolve and orient

Confirm the ticker. Check what exchange it trades on, what index it's in (S&P 500, Nasdaq 100, Russell 2000, …), and what sector/industry classification it carries (GICS preferred). This frames the peer group for the rest of the research.

### 2. Gather in parallel

Issue web searches and fetches in parallel — do not serialize them. 10–15 searches in the first batch covering distinct angles:

**Fundamentals**
- `<ticker> OR <company> revenue earnings EPS latest quarter`
- `<ticker> annual report 10-K fiscal year`
- `<ticker> guidance outlook <current year>`
- `<ticker> free cash flow margin operating income`
- `<ticker> balance sheet debt cash`

**Business & strategy**
- `<ticker> business segments revenue breakdown`
- `<ticker> product roadmap strategy`
- `<company> CEO CFO leadership`
- `<ticker> M&A acquisition partnership <current year>`
- `<ticker> investor day presentation`

**Industry & competition**
- `<company> market share competitors <current year>`
- `<company> industry trends headwinds tailwinds`
- `<ticker> vs <peer> comparison`

**Sentiment & risk**
- `<ticker> analyst rating price target <current year>`
- `<ticker> risk factors lawsuit regulatory`
- `<ticker> news <current month and year>`

Then `WebFetch` the highest-value pages:
- Company Investor Relations page (earnings releases, presentations)
- SEC EDGAR: latest 10-K and most recent 10-Q (`https://www.sec.gov/cgi-bin/browse-edgar?action=getcompany&CIK=<ticker>&type=10-K`)
- Yahoo Finance or similar for live fundamentals snapshot
- Recent earnings call transcript or summary
- Reputable analyst coverage (Seeking Alpha, Bloomberg, Reuters, WSJ)

### 3. Cross-check financials

Quantitative claims (revenue, EPS, margin, market cap) require **two independent sources** or get labeled `(reported by <source>, unverified)`. Be alert to:
- Reported vs. adjusted (non-GAAP) figures — always name which metric you're quoting
- TTM (trailing twelve months) vs. latest quarter vs. fiscal year — always specify the period
- Consensus estimates vs. company guidance vs. actuals — distinguish them clearly
- Analyst price targets are opinions, not facts — present the range and consensus

### 4. Note what's missing

Call out unknowns explicitly (e.g. "segment-level margins not disclosed", "no granular geographic breakdown", "guidance paused due to macro uncertainty"). Missing data is itself a signal.

## Frontmatter schema

`brief.md` starts with this YAML block. Keep field names stable across tickers.

```yaml
---
ticker: GOOGL
name: Alphabet Inc.
exchange: NASDAQ
sector: Communication Services      # GICS sector
industry: Interactive Media & Services
indices: [S&P 500, Nasdaq 100]
hq: Mountain View, CA, USA
founded: 1998
last_researched: YYYY-MM-DD

market_cap_usd: 2100000000000       # as of last_researched
price_usd: 170.00                   # as of last_researched
price_date: YYYY-MM-DD

financials:
  fiscal_year_end: December
  latest_annual:
    period: FY2025
    revenue_usd: 350000000000
    operating_income_usd: null
    net_income_usd: null
    eps_diluted: null
    free_cash_flow_usd: null
    gross_margin_pct: null
    operating_margin_pct: null
  latest_quarter:
    period: Q1 2026
    revenue_usd: null
    eps_diluted: null
    eps_beat_miss: null             # beat | miss | inline
    revenue_beat_miss: null
  guidance:
    period: Q2 2026
    revenue_low_usd: null
    revenue_high_usd: null
    notes: null

segments:
  - name: Google Services
    revenue_share_pct: null
  - name: Google Cloud
    revenue_share_pct: null
  - name: Other Bets
    revenue_share_pct: null

dividend:
  annual_usd: null                  # null if no dividend
  yield_pct: null

buyback:
  authorized_usd: null
  ttm_usd: null

executives:
  - name: Sundar Pichai
    role: CEO
    since: 2015
  - name: Anat Ashkenazi
    role: CFO
    since: 2024

analyst_consensus:
  rating: Buy                       # Strong Buy | Buy | Hold | Underperform | Sell
  price_target_low_usd: null
  price_target_high_usd: null
  price_target_median_usd: null
  as_of: YYYY-MM-DD

competitors: [Meta, Microsoft, Amazon, Apple]
---
```

Use `null` for unknown numerics. Omit list fields entirely when actively unknown rather than writing `[]`.

## Output formats

### Initial brief (initial mode)

After the frontmatter, the narrative `brief.md` body:

```
# <Company Name> (<TICKER>)

**One-liner:** <what the business does, in one sentence — no marketing language>
**Sector:** <GICS sector> · **Exchange:** <NASDAQ/NYSE/…> · **Indices:** <S&P 500, Nasdaq 100, …>
**Market Cap:** $<X>T/B · **Price:** $<price> (as of <date>)
**Website / IR:** <url>

## Snapshot
5–7 bullets: the most important things a smart reader needs first (recent quarter result, guidance, big strategic move, key risk, analyst view).

## Business & segments
What the company does, revenue breakdown by segment, geographic mix, pricing model, major products.

## Financials
| Metric | Latest Quarter | Prior Quarter | YoY | Latest FY | Prior FY |
|--------|---------------|---------------|-----|-----------|----------|
| Revenue | | | | | |
| Gross Margin | | | | | |
| Operating Margin | | | | | |
| EPS (diluted) | | | | | |
| Free Cash Flow | | | | | |

Guidance for next period. Balance sheet highlights (cash, debt, net cash position).
Capital return (dividend yield, buyback authorization and pace).

## Management
CEO, CFO, and key operational leaders. Tenure, prior-company signal, any recent changes.

## Competitive position & moat
Named competitors. Market share where available. Durable advantages (network effects, switching costs, scale, IP, regulatory moat). Positioning vs. peers.

## Industry trends
Tailwinds and headwinds for the sector/industry. Macro factors relevant to this company. Regulatory environment. Technology shifts.

## Analyst sentiment
Consensus rating (Buy/Hold/Sell split), price target range and median, notable upgrades/downgrades since last quarter. Street expectations for next quarter.

## Recent news & catalysts
Last 3–6 months: earnings, M&A, product launches, leadership changes, regulatory actions, activist investors, macro events that moved the stock.

## Risks & open questions
Top 3–5 concrete risks: regulatory, competitive, macro, execution, governance. Things that couldn't be verified and why they matter.

## Sources
Numbered list of URLs actually used, with one-line annotation each.
```

### Changelog entry (delta mode)

Prepend to `changelog.md`:

```
## <YYYY-MM-DD>
- **Earnings:** <quarter, beat/miss on revenue and EPS, key metrics>
- **Guidance:** <updated guidance vs. prior, if changed>
- **Financials:** <material changes to margin, FCF, balance sheet>
- **Management:** <hires, departures, role changes>
- **Strategy:** <M&A, new products, pivots, investor day highlights>
- **Analyst:** <consensus shift, notable upgrades/downgrades, target changes>
- **Industry:** <material macro or sector developments affecting the company>
- **News:** <1–3 most material items, with [n] citations>
- **Risks:** <new risks or risks resolved>
- **Sources added:** <n> new URLs — summarize what they say, don't just count
```

Drop any bullet whose answer is "no change". User-facing output in delta mode is exactly this entry plus: *"Full brief at `<path>`. Snapshot frozen at `<snapshot-path>`."*

### sources.jsonl format

One JSON object per line:

```json
{"url": "https://...", "first_seen": "2026-04-28", "cited_in": ["2026-04-28"], "content_hash": "<sha256-prefix>", "note": "Alphabet Q1 2026 earnings release"}
```

## Style rules

- **Cite inline** with `[1]`, `[2]`, … matching the Sources list. Every non-trivial claim gets a citation.
- **Always name the period.** Never say "revenue was $X" — say "Q1 2026 revenue was $X" or "FY2025 revenue was $X".
- **GAAP vs. non-GAAP.** Always state which you're quoting. When both exist, quote GAAP first, non-GAAP second.
- **No marketing language.** Strip adjectives like "revolutionary", "industry-leading", "transformative". State what the product actually does.
- **No fabrication.** If a figure isn't sourced, say so. Never invent earnings estimates or price targets.
- **Confidence labels:** `(high confidence)`, `(reported, unverified)`, `(estimate)`.
- **Analyst opinions are opinions.** Present price targets as a range + consensus; don't state them as fact.
- **Be concise.** A useful brief is 600–1,200 words of narrative plus the financials table.
- **Frontmatter is the source of truth for trends.** Mirror every key fact from narrative into frontmatter so future queries can roll up the corpus.

## What to skip

- Don't explain how stock markets work or what a P/E ratio is.
- Don't include a generic "Why this matters" or "Conclusion" section.
- Don't speculate on acquisition targets unless the user asks.
- Don't pull from sources you didn't actually fetch (no phantom citations).
- In delta mode, don't re-output the full brief — the user wants the diff.
- Don't editorialize about whether the stock is a "buy" — surface the analyst consensus and let the user decide.

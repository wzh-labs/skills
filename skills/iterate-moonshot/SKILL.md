---
name: iterate-moonshot
description: Walk through the user's moonshot ideas under `~/knowledge/moonshots/ideas/`, one folder at a time, and for each one do an extensive web research pass focused on opportunities and improvements. Writes a dated research note to `idea-xxxx/research/YYYY-MM-DD.md` and a consolidated `PLAN.md` at the idea root. Use when the user says "iterate my moonshots", "go through my moonshot ideas", "research the moonshots", "/iterate-moonshot", or otherwise wants every idea pushed forward with fresh research and an updated plan. Takes no required arguments — operates on every `idea-xxxx` directory. Accepts an optional idea slug or number to scope to one.
---

# Iterate moonshots

Goal: take the user's standing list of moonshot ideas and *push each one forward* — fresh web research focused on opportunities and improvements, then an updated, opinionated `PLAN.md`. Re-running on a later date produces a *delta* research note dated for that day; the plan rolls forward.

The skill does **not** scaffold code, and it does **not** write product copy. The deliverables per idea are exactly two artifacts:

1. `~/knowledge/moonshots/ideas/idea-xxxx/research/YYYY-MM-DD.md` — that day's research note (additive, never overwritten across days).
2. `~/knowledge/moonshots/ideas/idea-xxxx/PLAN.md` — the current consolidated plan (overwritten in place; prior versions live in git history).

## Inputs

The skill takes **no required arguments**. By default it iterates every `idea-xxxx` subdirectory of `~/knowledge/moonshots/ideas/` in numeric order.

Optional argument:
- A single idea identifier — either the folder slug (`idea-0003`) or the bare number (`3`, `0003`). If passed, scope the run to that idea only.

If `~/knowledge/moonshots/ideas/` does not exist or contains no `idea-xxxx` directories, stop the skill and tell the user the directory is empty — do not create scaffolding without being asked.

## Layout per idea

```
~/knowledge/moonshots/ideas/idea-xxxx/
  IDEA.md                       # user-authored pitch (input)
  PLAN.md                       # consolidated current plan (this skill writes)
  research/
    2026-05-15.md               # dated research notes (this skill writes; additive)
    2026-07-02.md
    ...
```

Treat `IDEA.md` as canonical input — never rewrite it, never "clean it up". The `research/` folder is append-only across days; same-day re-runs update the day's file in place rather than creating dupes.

## Phase 0 — Discover ideas

1. List `~/knowledge/moonshots/ideas/` and collect every `idea-*` directory. Sort by the numeric suffix.
2. If the user passed an identifier, filter to that one. Reject (and tell the user) if it doesn't match.
3. For each idea, check `IDEA.md`:
   - **Missing**: skip the idea, note it in the run summary.
   - **Empty (0 bytes or whitespace only)**: skip the idea, note it in the run summary so the user can fill it in.
   - **Non-empty**: queue it for processing.
4. Announce the run plan in one line: *"Iterating N idea(s): idea-0001, idea-0003, idea-0007 — skipping idea-0002 (empty IDEA.md)."*

Process queued ideas **sequentially** (one full Phase 1 + Phase 2 + Phase 3 cycle per idea, in order). Within a single idea's research phase, web searches and fetches run in parallel.

## Phase 1 — Research (per idea)

Per global CLAUDE.md: research first, verify against current docs, never claim a finding without a citation. Training data goes stale; web search is the source of truth for anything version-, market-, or competitor-sensitive.

### Inputs

`IDEA.md` for this idea, plus any prior dated notes already in `research/`. The prior notes set the floor — new research should find *what's new or what was missed*, not re-state what's already on file.

### Method

1. **Plan the angles.** From the pitch, identify the domain, the problem being solved, the likely user, the technology surface, and the obvious adjacent markets. Write down 10–20 distinct research angles before searching. Bias the angle list toward three themes the user explicitly asked for:
   - **Opportunities** — new markets, adjacent use cases, distribution channels, unmet demand signals, regulatory tailwinds, demographic shifts, partner ecosystems, monetization angles.
   - **Improvements** — better technical approaches, stronger differentiators, faster paths to validation, smarter MVP shapes, things competitors do better that this idea should adopt, things competitors get wrong that this idea can avoid.
   - **Previous attempts** — who has *tried this before* (even partially), what they shipped, what worked, what failed, and *why*. Includes shutdown startups, abandoned OSS projects, side projects that fizzled, internal team experiments people wrote about, and HN/Reddit "I tried X and here's what I learned" posts. The point is to **inherit their lessons**, not just to map competitors. Search angles: `<problem> postmortem`, `<problem> shut down`, `why <product> failed`, `lessons learned building <X>`, `<problem> graveyard site:news.ycombinator.com`, `tried building <X> reddit`, `<idea space> retrospective`. A clean "nobody has tried this" finding is itself a result worth surfacing — but only after honest searching.
2. **Search in parallel.** Issue all `WebSearch` calls in a single batch. Then `WebFetch` the highest-signal pages (primary sources, official docs, well-known engineering or industry analyses, recent press). Skip SEO-bait listicles.
3. **Cross-check claims.** Anything quantitative (market size, funding totals, competitor headcount, pricing, growth rate) needs **two independent sources** or gets labeled `(reported by <source>, unverified)`. Surface disagreements rather than picking one silently.
4. **Mine prior research.** If `research/` already has notes from earlier dates, read the most recent one in full and the second-most-recent's TL;DR. The new note should explicitly call out what *changed* — new entrants, new funding events, deprecated tools, shifted consensus.
5. **Invoke relevant `vercel:*` skills** if the idea has obvious Vercel-platform shape (web app, AI agent, serverless backend). At minimum `vercel:knowledge-update` whenever the idea has any web/AI surface. Their guidance overrides general knowledge when it conflicts.
6. **Stay scoped.** The brief should be useful, not exhaustive. Stop when you can't find a fresh angle that materially changes the plan.

### Coverage (apply selectively — only what the idea actually touches)

- **Problem validation** — Is the problem real? Who has it? How are they solving it today? Pain-point signals (forum threads, Reddit, HN, Twitter, support communities).
- **Prior art & competitors** — 3–7 closest *currently active* analogs. What they do well. What they get wrong. Where there's white space.
- **Previous attempts & lessons learned** — Distinct from current competitors. People who *tried this problem* and either shipped-then-shut-down, abandoned it mid-build, or wrote a postmortem about it. For each: what they built, what they learned, and the single most transferable lesson for this idea. Sources skew toward founder retrospectives, postmortem blog posts, "lessons from N years of building X" essays, HN threads on shut-down products, and Reddit/IndieHackers debrief posts. If a thorough search genuinely turns up nothing, say so — that absence is signal.
- **Market sizing & momentum** — TAM if knowable; growth rate; recent funding in adjacent companies; analyst commentary. Note staleness explicitly.
- **Technical landscape** — Current state of the libs, models, APIs, or platforms the idea depends on. Breaking changes since training cutoff. Idiomatic patterns. Known footguns.
- **Distribution** — How comparable products acquire users (paid, viral, integrations, marketplaces). Which channels are saturated vs. underused for this audience.
- **Regulatory / policy** — Anything pending or recent that opens or closes the door for this idea.
- **Risks** — Concrete failure modes other people in the space have hit. Don't invent abstract risks; cite specific incidents.
- **Opportunities you didn't expect** — Adjacent markets the pitch didn't mention, integrations the user hasn't considered, audiences the idea would serve better than the stated one.

### Research-note file

Write to `~/knowledge/moonshots/ideas/idea-xxxx/research/YYYY-MM-DD.md` using today's local date. If the file already exists from earlier today, treat it as a draft to extend — read it, fold new findings in, and rewrite it once. Do not create `2026-05-15-2.md` or similar.

Structure:

```markdown
# Research — <Idea Name>
_<YYYY-MM-DD> · idea-xxxx_

## TL;DR
3–6 bullets. Lead with **what changed the plan** (vs. the prior research note, or vs. a naive reading of IDEA.md if this is the first note). One sentence each.

## Delta from last research
_Only if a prior dated note exists in `research/`. Otherwise skip this section entirely._
- **New entrants / competitors:** ...
- **Funding & market events:** ...
- **Tech-stack shifts:** ...
- **Resolved unknowns:** ...
- **New unknowns:** ...

## Problem validation
What evidence exists that this problem is real and that someone will pay (in time, attention, or money) to solve it. Cite specific signals — forum threads, job posts, funded competitors — not abstractions. [n]

## Prior art & competitors
- **<Name>** — what they do, what's good, what's broken, what we'd take or avoid. [n]
- ...
3–7 entries. Skip if genuinely no comparable exists, but say so explicitly.

## Previous attempts & lessons learned
People who tried this (or something close) and what we should inherit from their experience. Distinct from "Prior art" — that section maps the *current* field; this one mines *prior* attempts, including failed ones, for transferable lessons. Each entry:

- **<Person / team / product>** _(year built · year ended · outcome: shipped & shut down / abandoned / pivoted / still alive but lessons published)_ — what they built in one sentence, the single most transferable lesson for this idea in one sentence, and *why* they say it failed or succeeded. [n]
- ...

If thorough searching genuinely surfaces no prior attempts, write: `_No prior attempts surfaced after searching for <X>, <Y>, <Z>. Treat as a yellow flag: either the problem is genuinely novel, or our searches missed it._` — don't quietly omit the section.

## Opportunities
Concrete, actionable. Each bullet should answer *what could this idea do that it isn't already planning to* — adjacent audiences, partnership angles, monetization, distribution channels, expanded scope. Tie each opportunity to a signal you actually found. [n]

## Improvements
Concrete, actionable. Each bullet should answer *how could the current idea be sharper* — better tech choice, better MVP shape, better differentiator, better positioning. Tie each improvement to evidence (a competitor's failure mode, a new SDK feature, a research finding). [n]

## Technical landscape
Current state of the relevant tools/APIs/models. Versions, breaking changes since training cutoff, idiomatic usage. Date-stamp version claims. [n]

## Risks & known pitfalls
Concrete failure modes other people in this space have hit. Avoid generic "execution risk" hand-waves. [n]

## Open questions
What you couldn't verify and why it matters. Missing data is signal.

## Sources
1. [Title](url) — one-line annotation
2. ...
```

### Style rules for research

- **Cite or don't claim.** Every non-trivial fact gets a `[n]` marker tied to the Sources list. No phantom citations — only URLs you actually fetched.
- **Date-stamp version and market claims.** "AI SDK v6 streaming pattern (as of 2026-05)", not "the modern pattern."
- **Surface disagreement.** When two reputable sources contradict, say so.
- **Note what you couldn't verify.** Goes under Open questions, not silently omitted.
- **No marketing language.** Translate competitor taglines into what they actually are.
- **No fabrication.** If a number is unknown, write that. Never estimate market size or competitor revenue without explicitly labeling it as an estimate plus the reasoning.

## Phase 2 — Plan (per idea)

After the research note is written, refresh `PLAN.md` at the idea root. This file is the *current consolidated plan* — it gets overwritten in place each run; the prior version lives in git history.

### When the plan already exists

1. Read the current `PLAN.md` in full.
2. For each section, decide: keep as-is, refine based on new research, or rewrite. Most of the plan should be stable across runs — only the parts the research actually changed should move.
3. If today's research surfaced opportunities or improvements that didn't fit the prior plan, fold them into the appropriate section (Opportunities, Risks, Build path) — don't bolt them on at the end.
4. Bump the `_Last updated_` line to today.

### When the plan does not exist

Write it from scratch using `IDEA.md` + today's research note.

### `PLAN.md` structure

```markdown
# <Idea Name> — Plan
_idea-xxxx · Last updated <YYYY-MM-DD>_

## Pitch
One paragraph, in your own words, of what this idea is. Faithful to IDEA.md — do not change the intent. Sharper than IDEA.md is fine; off-the-rails is not.

## Why now
2–4 bullets. What's true in the world right now that makes this idea timely. Cite the research note: `[research/YYYY-MM-DD.md §<section>]`.

## Target user
Who specifically. If IDEA.md was vague, propose a primary audience and label it `(proposed)`.

## Opportunity surface
The 3–5 biggest opportunities surfaced by the most recent research. Each one is one sentence + a citation to the research note section that backs it.

## Improvement backlog
The 3–7 sharpest improvements vs. the naive read of IDEA.md. Ordered by impact-to-effort. Each one cites the research note.

## Lessons from prior attempts
2–5 bullets distilling what previous attempts (from the research note's *Previous attempts & lessons learned* section) tell us to *do* or *not do* on this idea. Each bullet names the attempt it came from and the concrete action it implies (e.g. "Don't gate the core action behind sign-up — Project X lost ~80% of intent traffic at the wall [research/2026-05-15.md §Previous attempts]"). If the research note found no prior attempts, write `_None — no prior attempts surfaced this run._`.

## Differentiator
The one thing this idea does that nothing else does (or does as well). If you can't write a crisp differentiator yet, write `Unresolved — see Open questions` rather than padding.

## MVP shape
What the smallest demonstrable version looks like. 3–6 bullets. Concrete enough that an engineer could start tomorrow.

## Build path (rough sequencing)
Ordered list of milestones from "nothing" to "first ten users". Each milestone is 1–3 weeks of work, named concretely (e.g. *"Working ingest pipeline for one source, schema landed in Postgres"* — not *"build the backend"*).

## Distribution
How the first 10 / 100 / 1000 users find this. Concrete channels, not "go viral".

## Risks
The 3–5 things most likely to kill this. Each one cites the research note where the risk was identified.

## Open questions
Unresolved decisions. Carry over from prior plan unless answered. Add any new ones surfaced today.

## Research log
- `research/YYYY-MM-DD.md` — one-line summary of what that pass found
- `research/YYYY-MM-DD.md` — ...
Newest on top. Every dated note in `research/` should appear here.
```

If a section has no real content, write `_None._` — don't pad with boilerplate.

## Phase 3 — Commit per idea

`~/knowledge` is a git repo. Commit and push after each idea is fully processed (research note + plan written). One idea = one commit. Do **not** bundle multiple ideas into a single commit.

Run from `~/knowledge`:

```bash
git add moonshots/ideas/idea-xxxx/
git commit -m "moonshots(idea-xxxx): <YYYY-MM-DD> — <one-line summary of what shifted>"
git push
```

Rules (mirror the rules from `research-private-company`):

- **Stage explicitly.** `git add moonshots/ideas/idea-xxxx/`. Never `git add -A` or `git add .` — other unrelated work may be in flight elsewhere in the repo.
- **No commit if nothing changed.** If the research note is unchanged from a same-day prior run and `PLAN.md` is byte-identical, do not commit.
- **One commit per idea per run.** Multiple ideas in one run produce multiple commits.
- **If `git push` fails** (no upstream, network, conflict), report the failure and stop the run. Do not force-push, do not rewrite history, do not bypass hooks. The local commits are still on disk; the user can resolve and push manually.
- **Never** run destructive git operations (`reset --hard`, `push --force`, branch deletion) as part of this skill.

## Phase 4 — Run summary (after all ideas)

Once every idea in the queue has been processed (or explicitly skipped), output a single condensed summary to the user. One block per idea, plus a footer for any skips. Example:

```
Iterated 3 ideas:

idea-0001 — <Name>
  Research: research/2026-05-15.md (delta from 2026-04-02)
  Plan: 2 new opportunities, 1 risk added, MVP scope unchanged
  Top opportunity: <one line>
  Top risk: <one line>

idea-0003 — <Name>
  ...

Skipped: idea-0002 (empty IDEA.md — add a pitch and re-run)
```

Keep the summary tight — no commentary, no exhortations to keep building. The detailed work is on disk.

## Style rules

- **Research first, every run.** Never skip Phase 1 because "the idea hasn't changed". The *world* changes between runs; that's the point.
- **Cite inline** with `[n]` markers and a numbered Sources list at the bottom of each research note. Every non-trivial claim.
- **One question is not the same as one search.** Plan 10–20 angles before searching, then batch.
- **Be opinionated.** Opportunities and improvements are the point — present them as recommendations, not as a neutral landscape survey.
- **Dates everywhere.** `YYYY-MM-DD` for note filenames and `Last updated` lines. Use the user's current local date.
- **The plan is a hypothesis.** Carry forward the riskiest assumption explicitly — don't quietly resolve unresolved questions just because the plan needs to "look done".

## What to skip

- Don't write product code in this skill. The deliverable is research + plan.
- Don't restructure or rewrite `IDEA.md`. It's input.
- Don't create new `idea-xxxx` folders or seed empty IDEA files. The user owns idea creation.
- Don't dump full research into the chat — the file on disk is the artifact. The chat summary is the run summary in Phase 4.
- Don't pad with generic "Conclusion" or "Considerations" sections.
- Don't claim a research finding without a citation. Phantom sources are worse than missing sections.

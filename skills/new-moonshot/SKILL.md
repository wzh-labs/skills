---
name: new-moonshot
description: Generate a new AI-agent-driven, one-person business idea that is orthogonal to the user's existing moonshots, pitch it for approval, and on yes create `~/knowledge/moonshots/ideas/idea-XXXX/IDEA.md` with the next available number. Reads every existing `IDEA.md` under `~/knowledge/moonshots/ideas/` first so the proposal is genuinely new — not a rehash. Use when the user says "new moonshot", "give me a new moonshot idea", "pitch me an AI business", "/new-moonshot", or otherwise asks for a fresh moonshot to add to the list. Takes no arguments.
---

# New moonshot

Goal: propose **one** AI-agent-driven, one-person business idea that is *orthogonal* to everything already in `~/knowledge/moonshots/ideas/`, pitch it tightly to the user, and on explicit approval write a new `idea-XXXX/IDEA.md` with the next available number.

The skill produces exactly one artifact on the happy path: `~/knowledge/moonshots/ideas/idea-XXXX/IDEA.md`. No `PLAN.md`, no `research/` notes — those are `iterate-moonshot`'s job. Hand the file off and stop.

## Hard constraints on the idea

Every proposal must satisfy *all* of these. If you can't make a candidate satisfy them, throw it out and find another — don't soften the constraints.

1. **AI-agent-driven.** The business only exists because LLM agents do the work. A version of the idea that pre-dates current-gen LLMs is disqualified. The agent is the labor, not a feature bolted onto a SaaS shell.
2. **One-person operable.** A single founder can run it end-to-end — no ops team, no sales team, no human-in-the-loop labeling sweatshop. Customer support, ops, and delivery should fit within reasonable solo bandwidth (or themselves be agent-driven).
3. **Orthogonal to existing moonshots.** Different problem, different audience, *and* different mechanism than every idea already in `~/knowledge/moonshots/ideas/`. "Same idea with a tweak" is not orthogonal. If the closest existing idea shares two of {problem, audience, mechanism}, pick a new candidate.
4. **Has a plausible path to first revenue inside 90 days.** A clear pricing model (subscription, per-seat, per-action, % of value delivered) *and* a concrete first-customer path. Vapor like "we'll figure out monetization later" is disqualifying.
5. **Defensible-enough.** Either a data moat, a distribution moat, a workflow moat (deep integration into a specific niche), or a quality moat (the agent does something competitors can't easily match). "It's a wrapper" with no moat is disqualifying — there are too many of those.
6. **Has a concrete, no-human-in-the-loop go-to-market path.** The acquisition motion must work *without* the founder personally cold-DMing prospects, hopping on demo calls, attending conferences, doing recorded feedback interviews, or any other 1:1 human-to-human channel. Allowed channels: programmatic SEO + content (LLM-generated or agent-maintained), a free tier or free tool that doubles as the funnel, agent-callable / API-first distribution (MCP servers, OpenAPI directories, agent marketplaces), product-led growth with viral mechanics built into the product, SEO-via-public-artifacts (the agent's output is itself indexable), integration into an existing distribution surface (Slack/Linear/GitHub/Shopify app marketplaces, Vercel/Stripe partner directories), or paid acquisition with a known CAC ceiling. Disallowed: cold email blasts the founder writes, manual outbound, demo calls, "30-minute discovery sessions", attending meetups. If you can't name the no-human channel and the motion, the candidate isn't ready. "Go viral on Twitter" is also not a GTM.

## Phase 0 — Survey existing ideas

1. **Check the directory exists.** If `~/knowledge/moonshots/ideas/` does not exist, create it (`mkdir -p`) and proceed with an empty existing-set.
2. **List every `idea-xxxx` subdirectory.** Sort by numeric suffix. Record the highest number — the new idea will be `idea-<max+1>`, zero-padded to 4 digits. If the directory is empty, start at `idea-0001`.
3. **Read every existing `IDEA.md`** (including empty / missing files — note those so the user knows). For each, extract:
   - **Problem** — what pain it addresses.
   - **Audience** — who pays.
   - **Mechanism** — what the product *does* (the verb).
   - **Tagline** — one-line sharpened pitch.
   Hold this list in working memory; it is the orthogonality baseline for Phase 1.
4. **Announce the survey in one line:** *"Surveyed N existing ideas: idea-0001 (<tagline>), idea-0003 (<tagline>), ... — next slot is idea-XXXX. Brainstorming."* No more chat output until the pitch in Phase 2.

If `IDEA.md` is empty for any existing idea, treat that idea as a "claimed slot, unknown shape" — still count it against orthogonality by folder name only, and call it out in the announcement so the user knows that idea isn't being meaningfully diffed against.

## Phase 1 — Brainstorm with research

Per global CLAUDE.md: research first, verify against current docs. Training data goes stale, and "is this idea novel" is exactly the kind of question that needs current web evidence.

### Method

1. **Plan 8–15 search angles.** Bias toward signals of *underbuilt* niches, recent LLM-capability shifts, and one-person-business case studies — not generic "AI startup ideas" listicles. Mix angles like:
   - Recent shifts in agent capability (long-context reasoning, computer-use agents, voice agents, multi-agent orchestration) — what becomes newly possible in the last 6–12 months?
   - Painful, repetitive professional workflows in a specific vertical (legal ops, accounting close, claims, compliance, B2B procurement, niche research).
   - Markets where a small founder with strong taste beats a big company with a generic tool (community-driven, design-led, niche-vertical).
   - Recent "I quit my job and now run a $X solo AI business" essays — what mechanisms actually worked, what didn't.
   - Forum threads where professionals complain about a specific repetitive task by name.
   - Existing competitors who are deliberately *too generic* — leaving a wedge for a sharper, niche-vertical alternative.
   - Distribution channels that recently opened (e.g. agentic marketplaces, MCP server directories, specific SaaS marketplaces, vertical communities).
   - Concrete *no-human-in-the-loop* GTM patterns that worked for recent solo-AI founders — programmatic SEO, free-tool funnels, marketplace listings, agent-callable distribution, viral product mechanics. Skip case studies whose acquisition was founder-led sales or cold outbound; those don't satisfy the constraint.
2. **Search in parallel.** Issue all `WebSearch` calls in a single batch. Then `WebFetch` the highest-signal pages (founder retrospectives, forum threads with concrete complaints, primary-source product launches). Skip SEO-bait listicles and "Top 50 AI business ideas" posts.
3. **Generate 5–8 candidate ideas internally** from the research. For each, write a one-line tagline plus a one-sentence note on which existing moonshot it's closest to and why it's still orthogonal.
4. **Filter against the hard constraints above.** Discard anything that fails any of the five. Discard anything where the closest existing moonshot shares ≥2 of {problem, audience, mechanism}.
5. **Pick the single strongest candidate** for the pitch. Strongest = best combination of orthogonality + agent-leverage + plausible path to revenue. Keep the runners-up in working memory in case the user rejects the first pitch and asks for an alternative.

### Style rules for brainstorming

- **Specificity beats breadth.** "AI legal research assistant" is too vague to pitch. "An agent that monitors newly-filed cases in a specific federal circuit and emails a 90-second summary to plaintiff-side attorneys who subscribe to that practice area" is pitchable.
- **Concrete audience.** Name the buyer's role and the size of the addressable population in one sentence ("solo plaintiff-side employment lawyers in the US — ~15k of them per [source]"). If you can't, the candidate isn't ready.
- **One real workflow.** The pitch must name the exact task the agent automates today, not a fuzzy capability ("drafts deposition outlines from a hearing transcript and uploaded exhibits", not "helps with litigation").
- **No vaporware mechanisms.** If the agent technology needed doesn't exist yet (or isn't reliable enough today), say so and pick a different candidate.

Do **not** write any files during Phase 1. Hold the chosen candidate (and a short backup list) in working memory only.

## Phase 2 — Pitch and get approval

One pitch, in chat, designed to be approved or redirected in a single round. **Do not use `AskUserQuestion`** — keep it conversational so the user can free-text a redirect.

Format the pitch exactly like this:

```
# Pitch — <Idea Name>

**One-line:** <one sentence — the elevator pitch>

**Problem:** <the specific pain, named in the user's words if possible — who feels it, how often, what they do today>

**Agent's job:** <the exact workflow the agent automates, end-to-end, in 2–3 sentences. Be concrete about inputs, outputs, and the human's role>

**Audience:** <buyer role + rough population size with source>

**Revenue model:** <pricing shape + a back-of-envelope first-year revenue scenario at modest scale>

**Go-to-market (no humans in the loop):**
- **First 10 customers:** <a mechanical channel — no cold DMs, no demo calls, no founder-led sales. e.g. "Free open-source CLI that solves the adjacent free version of the problem, with a paid hosted tier surfaced when the user hits a usage wall." Or "Programmatic SEO pages auto-generated for the top 500 long-tail queries in this niche, each linking to a free agent tool." Concrete enough that the founder could ship the funnel tomorrow without talking to anyone.>
- **Channel to 100 customers:** <the scalable, agent-or-mechanism-driven channel. e.g. "Listing in the official MCP directory + a viral side-effect where the agent's output is publicly indexable and links back to the product." Name the channel; don't say "content marketing.">
- **Why this channel and not others:** <one sentence — what about the audience or the product makes this no-human channel work and human-led channels unnecessary>

**Why now:** <2 bullets — what shifted recently that makes this newly buildable or newly valuable. Cite sources>

**Why it's defensible:** <one sentence — the moat>

**Why it's orthogonal to existing moonshots:** <one sentence per existing idea this is closest to, naming the idea and the dimension on which they differ>

**Riskiest assumption:** <one sentence — the single thing that, if wrong, kills it>

**Sources:** <numbered list of URLs you actually fetched during Phase 1>
```

After the pitch, ask exactly one question:

> Want me to save this as `idea-XXXX`? Or steer me — different audience, different mechanism, different problem, or pitch one of the runners-up?

Then **wait**. Possible user responses and what to do:

- **Clear yes** ("yes", "save it", "go", "do it", "looks good") → proceed to Phase 3.
- **Yes with edits** ("yes but change the audience to X", "save it but call it Y") → apply the edits to the pitch in memory, briefly restate the final version in one paragraph, and proceed to Phase 3 with the edited version. Don't re-pitch the whole template.
- **Soft no / redirect** ("not quite, try a different mechanism", "more focused on developers", "show me the runners-up") → pitch a runner-up using the same template, or generate a fresh candidate if no runner-up matches the redirect. Loop Phase 2 until the user approves or explicitly stops.
- **Hard no / stop** ("nevermind", "let's not", "stop") → acknowledge in one line and stop the skill. Do not write any files. Do not commit anything.

Auto mode caveat: even in auto mode, **do not skip the approval step**. Creating a new entry in the user's standing idea list is exactly the kind of "modifies a curated personal artifact" decision the user should consciously bless. One pitch, one explicit approval, then write.

## Phase 3 — Write IDEA.md

On explicit approval:

1. **Compute the slot.** `idea-XXXX` where `XXXX = max(existing numeric suffixes) + 1`, zero-padded to 4 digits. Recompute at write time in case the user added an idea folder out-of-band since Phase 0.
2. **Create the directory** at `~/knowledge/moonshots/ideas/idea-XXXX/`.
3. **Write `IDEA.md`** to that directory using the template below. Faithfully encode the (possibly edited) approved pitch — do not embellish, do not add sections beyond the template.

### `IDEA.md` template

```markdown
# <Idea Name>

_idea-XXXX · Created <YYYY-MM-DD>_

## One-line
<one-sentence elevator pitch>

## Problem
<2–4 sentences. Who feels the pain, how often, what they do today. Concrete, not abstract.>

## Agent's job
<2–4 sentences. The exact workflow the agent automates end-to-end. Inputs, outputs, and the human's role. Specific enough that an engineer could sketch the architecture from it.>

## Target user
<Buyer role, decision-maker, rough population size with source citation.>

## Revenue model
<Pricing shape (subscription / per-seat / per-action / % of value). Back-of-envelope first-year revenue scenario at modest scale — explain the assumptions.>

## Go-to-market

**Constraint:** No humans in the loop. The founder does not cold-DM, demo, sell, or take feedback calls. Acquisition runs through programmatic content, free tools that double as funnels, agent-callable distribution surfaces, marketplace listings, integrations, viral product mechanics, or paid acquisition with a known CAC ceiling — and nothing else.

**First 10 customers:** <Mechanical channel + concrete motion. e.g. "Free open-source CLI that solves the adjacent free version of the problem; the paid hosted tier is surfaced when the user hits the free-tier wall." Or "Programmatic SEO pages auto-generated for the top 500 long-tail queries in this niche, each ending in a free agent tool." Specific enough to ship the funnel tomorrow without talking to anyone.>

**Channel to 100 customers:** <The scalable, mechanism-driven channel. Name it; explain the motion in one sentence. Examples: MCP directory listing + agent-indexable public output; Shopify/Slack/Linear app marketplace listing; partner-integration with a tool already in the audience's stack.>

**Channel to 1,000 customers:** <The compounding flywheel — programmatic-content SEO that grows with each new customer's data, a marketplace listing that earns its own ranking, a viral product mechanic, agent-distribution where downstream agents discover and call this one, or paid acquisition at a known CAC. One sentence.>

**Why this channel:** <One sentence — what about the audience or product makes a no-human channel work, and why human-led GTM is genuinely unnecessary (not just inconvenient).>

**Estimated CAC vs. LTV:** <Rough numbers with assumptions, or `(unknown — to validate against the first mechanical funnel)` if genuinely not pinnable yet.>

## Why now
- <Recent capability or market shift #1, with source>
- <Recent capability or market shift #2, with source>

## Differentiator / moat
<One paragraph. The specific reason a generic AI wrapper doesn't beat this — data, distribution, workflow depth, or quality.>

## Orthogonality vs. existing moonshots
<One line per existing idea this is closest to, naming the idea slug and the dimension on which they differ (problem / audience / mechanism). Skip if no existing ideas.>

## Riskiest assumption
<One sentence. The single thing that, if wrong, kills the idea.>

## Sources
1. [Title](url) — one-line annotation
2. ...
```

Every field is mandatory. If a field would be `_None._`, the candidate wasn't ready for Phase 3 — go back to Phase 2 and tighten.

Date format: `YYYY-MM-DD` using the user's current local date.

## Phase 4 — Commit

`~/knowledge` is a git repo (per the `iterate-moonshot` skill's Phase 3). After writing `IDEA.md`:

1. Stage **only** the new directory: `git -C ~/knowledge add moonshots/ideas/idea-XXXX/`. Never `git add -A` or `git add .` — other unrelated work may be in flight.
2. Commit: `git -C ~/knowledge commit -m "moonshots(idea-XXXX): seed — <one-line tagline>"`.
3. Push: `git -C ~/knowledge push`. If push fails (no upstream, network, conflict), report the failure and stop — do not force-push, do not rewrite history, do not bypass hooks. The local commit is still on disk for the user to resolve.

Never run destructive git operations (`reset --hard`, `push --force`, branch deletion) as part of this skill.

## Phase 5 — Hand-off

One-line confirmation to the user:

> Saved as `~/knowledge/moonshots/ideas/idea-XXXX/IDEA.md` and committed. Run `/iterate-moonshot idea-XXXX` next to research it and produce a plan.

No further commentary. Stop.

## Style rules

- **One pitch at a time.** Don't dump a list of 5 ideas for the user to pick from — that's their job to delegate, not yours to offload back onto them. Do the filtering in Phase 1, then commit to one candidate.
- **Cite or don't claim.** Every market-size number, every "competitor X does Y" claim, every "this just became possible because Z" claim needs a real source you actually fetched. Phantom citations are worse than missing citations.
- **No marketing language.** Translate any tagline into what the product actually does.
- **Stay in the lane.** This skill seeds a new idea. It does not plan, research deeply, or scaffold code — those are `iterate-moonshot` and `idea-to-prototype` respectively.
- **Date everything.** `YYYY-MM-DD` on the file, using the user's local date.

## What to skip

- Don't write `PLAN.md` or any `research/` notes — that's `iterate-moonshot`'s territory.
- Don't pre-iterate the new idea ("here's what I'd research next…"). The user can run `/iterate-moonshot` themselves.
- Don't seed multiple idea folders in one run. One run = one idea = one commit.
- Don't rewrite or "tidy up" any existing `IDEA.md` while surveying — those are user-owned inputs.
- Don't create the directory or write `IDEA.md` until after explicit user approval. A pitch without approval produces zero files.

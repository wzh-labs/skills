---
name: idea-to-prototype
description: Turn a rough product idea into a concrete, Vercel-flavored implementation plan via structured Q&A. Grills the user one question at a time, logs every answer, then writes an implementation plan grounded in their actual constraints. Use when the user says "I have an idea for…", "let's prototype…", "build me a quick prototype of…", "/idea-to-prototype <pitch>", or otherwise wants to flesh out a concept before any code is written. Default stack is Vercel (Next.js + Vercel CLI assumed installed) — diverge only when the user explicitly asks.
---

# Idea to prototype

Goal: take a rough idea and turn it into a *runnable* implementation plan. The path is always:

1. Capture the idea verbatim.
2. **Research first**: do a structured web + platform-skill sweep and write `RESEARCH.md`. Findings shape every Q&A proposal that follows.
3. **Interrogate the user, one question at a time**, logging each answer as it comes in. Proposals are grounded in the research, not generic.
4. Write a concrete `PLAN.md` grounded in the research and the answers.
5. Stop. Wait for explicit go-ahead before writing any product code.

The skill produces three artifacts (`RESEARCH.md`, `QNA.md`, and `PLAN.md`). It does **not** scaffold the prototype itself — that's a separate step that only happens after the user approves the plan.

Default stack assumption: **Vercel** (Next.js App Router on Vercel, Vercel CLI already on the machine). Apply Vercel-native choices unless the user explicitly steers elsewhere.

## Core design principle: AI-Agent-First

Every prototype produced through this skill must be **usable by an AI agent**, not just a human in a browser. Humans are the day-1 users, but agents are the day-2 users — and that future-proofing is non-negotiable. Bake this in from the first question, not as a bolt-on at the end.

What "agent-usable" means concretely:

- **Every meaningful action is callable as a typed API**, not only as a button click. Server Actions, route handlers, or MCP tools — pick one — but never bury logic so deep in client UI that an agent can't reach it.
- **Inputs and outputs are JSON with explicit schemas** (Zod / TypeScript types). Avoid HTML-scraping-only surfaces. If the human UI streams Markdown, the agent surface returns structured data.
- **Auth supports machine credentials** when auth exists at all. Default split: **Okta OIDC for humans** (authorization-code flow) and **Vercel OIDC for M2M** (Vercel-minted, short-lived JWTs that workloads receive automatically and present to receivers; receivers verify against Vercel's published JWKS). Both flows reduce to a bearer token validated by the same JWT-verifying middleware on every protected route — branching only on the `iss` claim to pick the correct JWKS. Static API keys are the fallback for non-Vercel-hosted callers and "just me" prototypes only.
- **Server is the source of truth.** No critical state lives only in client components. An agent that hits the API directly should see exactly what the human sees.
- **Operations are idempotent where possible**, with explicit IDs the agent can supply, so retries are safe.
- **Discoverable surface**: list/index endpoints exist (e.g. `GET /api/items`), not just deep links. An agent should be able to enumerate before it acts.
- **Observable**: side effects produce structured events (webhook, log, or polling endpoint) so an agent can confirm what happened.

When the human-facing answer to a question conflicts with these properties, the agent surface still has to satisfy them — even if it means duplicating an action behind both a button and an API route. Call this out in `PLAN.md` explicitly.

## Phase 0 — Setup (silent, fast)

1. **Slug the idea**: kebab-case, ≤ 5 words. Derive from the user's pitch. If the pitch is one word, append a date (`weather-2026-05`).
2. **Pick a workspace**:
   - Default: `~/prototypes/<slug>/`.
   - If the user already mentioned an existing repo, use that path instead.
   - Confirm the path with the user in a single AskUserQuestion call before creating anything. This is the *only* place you may bundle the path question with another question.
3. **Create the workspace**, write `IDEA.md` containing the user's original pitch verbatim (no editorialization), and initialize `QNA.md` with a header:

   ```
   # Q&A — <Idea Name>
   _Started <YYYY-MM-DD>_
   ```

## Phase 1 — Research

Before any question is asked, do a structured research pass on the idea and write `RESEARCH.md` in the workspace. The Q&A in Phase 2 then uses these findings to propose informed, specific options — not generic ones. This satisfies the global "research first" rule (training data goes stale; verify against current docs).

### Inputs

`IDEA.md` (the user's verbatim pitch) and the slug. Nothing else.

### Method

1. **Plan the queries.** From the pitch, identify the domain, the likely tech surface, and the integrations the idea hints at. Write down 8–15 distinct search angles.
2. **Search in parallel.** Issue all `WebSearch` calls in a single batch. Then `WebFetch` the highest-signal pages (official docs, primary sources, well-known engineering blogs). Avoid SEO listicles.
3. **Invoke relevant `vercel:*` skills** for current platform behavior — at minimum `vercel:knowledge-update`, plus any of `vercel:nextjs`, `vercel:ai-sdk`, `vercel:vercel-storage`, `vercel:auth`, `vercel:workflow`, `vercel:vercel-functions`, `vercel:shadcn`, `vercel:vercel-sandbox` that match the idea. Their guidance overrides anything in this file when they conflict.
4. **Synthesize, don't dump.** Aim for 400–800 words of structured findings + a sources list. Cite every non-trivial claim with `[n]` markers tied to `## Sources`.
5. **Surface the open questions.** The output of research is a set of *unresolved decisions* the Q&A needs to nail down. Those become the seed list for Phase 2.

### Coverage (apply selectively — only what the idea actually touches)

- **Prior art.** Existing products, OSS libraries, or common patterns that already solve this. 3–5 closest analogs, one line each. Saves the user from rebuilding what exists.
- **Reference architectures.** 2–3 well-trodden ways to build this, with tradeoffs.
- **Vercel platform fit.** Which Vercel-native primitives match (Storage type, Workflow vs Functions, AI Gateway, Sandbox, Edge Config, Routing Middleware). Which to *avoid* and why.
- **SDK / library state.** Current versions, breaking changes since training cutoff, and idiomatic usage of the libs the idea will likely need (Next.js 16, AI SDK v6, Tailwind v4, shadcn, Zod, Drizzle / Neon, etc.).
- **Auth landscape (if auth is plausibly relevant).** Current OIDC support across Clerk, Auth0, Descope. Marketplace status. Token validation patterns in Next.js Route Handlers and Middleware.
- **Agent surface conventions.** How comparable products expose themselves to agents today (MCP servers, OpenAPI specs, tool schemas). Anything published worth mimicking.
- **Known pitfalls.** Common gotchas, well-known footguns, and "don't do this" items in the space.

### `RESEARCH.md` structure

```
# Research — <Idea Name>
_Generated <YYYY-MM-DD> from IDEA.md_

## TL;DR
3–5 bullets: what the research changed about the default plan vs. a naive Vercel default.

## Prior art
- **<Product / lib>** — what it is, why it's relevant, what we'd borrow vs. avoid. [n]
- ...

## Reference architectures
- **Approach A:** description, tradeoffs, when it fits.
- **Approach B:** description, tradeoffs, when it fits.

## Vercel platform fit
- **Recommended primitives:** ... why, citing current platform behavior.
- **Avoid / unsuitable:** ... why.

## SDK / library state
- `<package>` — current major, key features relevant here, gotchas.
- ...

## Auth landscape
(only if relevant)

## Agent-surface conventions
What comparable tools do for AI-agent access; what we should mirror.

## Known pitfalls
- ...

## Open questions for Q&A
The decisions Phase 2 must resolve, derived from the gaps above. These directly seed the Phase 2 question list.

## Sources
1. [title](url) — one-line annotation
2. ...
```

### Style rules for research

- **Cite or don't claim.** Every non-trivial fact gets a `[n]`. No fabrication, no "common knowledge" hand-waves on version-sensitive topics.
- **Date-stamp version claims.** "AI SDK v6 streaming pattern (as of <YYYY-MM>)" — not "the modern pattern."
- **Surface disagreement.** If two reputable sources contradict each other, say so rather than picking one silently.
- **Note what you couldn't verify.** Missing data is itself useful signal for the Q&A.
- **Stay scoped.** Don't research the entire web. The pitch defines the surface; stop when the open-questions list is solid.

### Hand-off to Phase 2

Before moving on, output a **one-line summary to the user**: *"Research saved to `<workspace>/RESEARCH.md` — N analogs found, key decisions surfaced: <comma-separated>. Starting Q&A."* Then proceed directly. Do **not** dump the full research note into the chat.

## Phase 2 — Interrogation

**Hard rule: exactly one question per `AskUserQuestion` call.** Never bundle questions. Never sneak a follow-up into the same turn. Wait for the answer, log it, then form the next question.

**Style rule: propose, don't open-end.** Each question should feel like a quick "yes / pick one" rather than an essay prompt. The agent has done the thinking — it offers 2–4 *concrete, opinionated, mutually exclusive* options and labels the most likely one **(Recommended)** as the first option. Every option must be specific enough to act on (good: `Vercel Postgres with table tasks(id uuid, title text, status enum, createdAt timestamptz)` — bad: `use a database`). The user's job is to confirm or redirect, not to design from scratch. Free-text via "Other" stays available as the escape hatch when the proposals genuinely don't fit.

**Style rule: ground every proposal in `RESEARCH.md`.** When the proposed options come from a research finding (a prior-art pattern, a current SDK behavior, a known pitfall to avoid), reference it briefly in the option's `description` — e.g. "Mirrors how <product> handles this, see RESEARCH.md §Prior art." Recommendations should *flow from* the research, not from generic intuition. If a proposal contradicts a research finding, say so explicitly and explain why.

**Agent-first lens: every proposal is filtered through the AI-Agent-First principle above.** When you propose options for a flow, a data shape, an auth model, or an integration, prefer the option that yields a typed API surface, structured I/O, and machine-friendly credentials — and say so explicitly in the option's description (e.g. "Server Action `createTask(input)` returning `Task` — also exposed at `POST /api/tasks` for agents"). If a human-only option is genuinely better for the human flow, propose it *but* attach a parallel agent-surface plan in the same option's description.

After every answer, append to `QNA.md`:

```
## Q<n>: <full question text>
_<header chip>_

**Answer:** <the option label the user picked, plus any free-text "Other" content verbatim>

**Why this matters:** <one sentence on what this answer changes about the plan>
```

Update `QNA.md` *immediately after each answer*, not at the end. If the user revises an earlier answer mid-conversation, edit that entry in place rather than appending a contradicting one.

### Question dimensions (bias toward user flow + technical specifics)

The goal is **zero ambiguity at implementation time**. Cheap, high-level questions (audience, timebox, "is this for fun") get *one* question total — usually rolled into the pitch. Spend the budget on the user flow and the technical contracts, because those are what the implementation hangs on.

**Hard rule: never accept an abstract answer for a flow or data question.** If the user says "it shows a list of items," push: *which fields per item, in what order?* If they say "it calls the API," push: *which endpoint, with what inputs, returning what shape?* If they say "it errors gracefully," push: *what does the screen say when it errors?* Concrete > abstract, every time.

Rough order: pitch & audience (≤1 question) → user flow drill-down (the bulk) → data & contracts → tech specifics.

#### Tier 1 — Pitch & audience (1 question max)

1. **Pitch + audience combined** — "In one sentence, what is this and who's it for?" Free-text via Other. Skip entirely if the user's invocation already answered this.

#### Tier 2 — User flow (the core of the Q&A — most questions live here)

Walk the user through the prototype as if narrating a screen recording. Each question pins down one beat of the flow.

2. **Entry point** — What's the very first thing the user sees when they open the URL? (landing page with CTA / straight into the app / sign-in wall / something else — describe the layout in one sentence)
3. **Core action — concrete walkthrough** — Walk me through the single most important user action, click by click. What do they click first? What appears? What do they type or select? What do they click next?
4. **Success output** — When the core action succeeds, what does the user see on screen? Be specific — what text, what UI elements, what layout?
5. **Empty state** — What does the screen look like *before* any data exists for this user? (empty list with prompt / pre-seeded examples / hidden until first action / something else)
6. **Failure / error states** — For each thing that can fail (network, validation, external API, auth), what does the user see? Pick the 2–3 most likely failures and pin down the exact UX.
7. **Loading / latency** — For any action that takes >500ms (LLM call, external API), what does the user see while waiting? (spinner / skeleton / streaming output / optimistic update)
8. **Return visit** — When the same user comes back tomorrow, what's different from their first visit? (resumes where they left off / fresh slate / shows history)

#### Tier 3 — Data & contracts (pin down every shape)

9. **Data model — concrete fields** — For each entity that gets stored or passed around, what are the actual fields and types? Push for a real example record, not a description. (e.g. *not* "user has tasks" but `Task { id: uuid, title: string, status: 'todo'|'done', createdAt: timestamp }`)
10. **Persistence boundary** — What survives a refresh? Across users? (nothing / per-session / per-user / shared globally) — and *which fields* fall into which bucket if it's mixed.
11. **External API contract** — For each external service: which exact endpoint(s), what inputs, what response shape, what rate limits or auth model? If they don't know, that's an open question to flag in the plan, not something to hand-wave.
12. **Validation rules** — What inputs get rejected, and what's the message? (max length, required fields, format constraints) — pick the 2–3 that actually matter.
13. **AI shape** (only if AI is involved) — Chat, single-shot completion, tool-using agent, or structured output? Which provider/model? Streaming or buffered? What's the system prompt's job in one sentence? What's the input schema and what's the expected output schema?

#### Tier 4 — Tech specifics

14. **Auth boundary (humans + machines)** — Which routes/actions are protected vs public? *And* how do humans and machines each authenticate? Propose, in order of preference: (a) **Okta OIDC for humans (auth-code flow) + Vercel OIDC for M2M (Vercel-minted JWT, verified against Vercel's JWKS) — same JWT middleware on every protected route, branching on the `iss` claim (Recommended for anything multi-user, shared, or agent-callable)**, (b) no auth (only for "just me, localhost / private preview"), (c) Okta OIDC for humans + static API key for non-Vercel-hosted machine callers (only when the caller can't run on Vercel), (d) public read + Okta-gated write. The implementing agent must verify current Okta and Vercel OIDC behavior via `vercel:auth` and `vercel:env-vars` before scaffolding — JWKS URLs, audience defaults, and token claims evolve.
15. **Agent surface shape** — How will an agent interact with the prototype? Propose: (a) typed Server Actions also exposed as `/api/*` route handlers with Zod-validated JSON I/O **(Recommended)**, (b) an MCP server fronting the same operations, (c) a published OpenAPI spec, (d) all of the above. Pick the minimum that lets a Claude/agent client read state and trigger the core action without scraping HTML.
16. **Tech non-negotiables** — Anything you must use or must NOT use? (framework, language, DB, AI model, existing component library, existing repo to extend)
17. **Deployment target** — localhost only / Vercel preview URL shared with N people / public production deploy. Custom domain?

### Adapting

- **Push back on abstraction every time.** If an answer is "it just works" or "the usual," restate it as a concrete question with concrete options.
- If an earlier answer settles a whole branch, skip its downstream questions. ("just me, no persistence" → skip auth, return-visit, persistence-boundary.)
- If the user gives a Vercel-native answer up front, don't re-ask hosting/db.
- If they punt with "you decide", record that verbatim in QNA.md and pick a Vercel-native default in the plan, marked `(defaulted)`.
- If two answers contradict, pause and ask a single tie-breaker rather than guessing.

### When to stop

You have enough when you can write *every* section of `PLAN.md` — especially **User flow**, **Data model**, and **Architecture → Server Actions / API routes** — without writing a single `???` or "TBD". If you can't yet describe the success screen, the empty state, the data fields, and the API contract concretely, you don't have enough — keep asking.

Conversely, if you find yourself asking purely confirmatory questions ("so just to confirm…"), stop and go to Phase 3.

## Phase 3 — Plan

Write `PLAN.md` in the workspace. Structure:

```
# <Idea Name> — Implementation Plan

_Generated <YYYY-MM-DD> from QNA.md_

## Pitch
<one-line pitch from Q&A>

## MVP scope
- **In:** <1–3 bullets — only what's needed to demonstrate the core action>
- **Out (deferred):** <bullets — with one-line "why deferred" each>

## User flow
Numbered steps. What the user sees and does, start to finish, on the prototype.

## Tech stack
- **Framework:** Next.js 16 (App Router) — verify current major before scaffolding
- **Hosting:** Vercel (preview deploy first via `vercel` CLI)
- **Package manager:** pnpm
- **Styling:** Tailwind v4
- **Components:** shadcn/ui (only if there's real UI surface)
- **Data:** <Vercel Postgres / Vercel KV / Vercel Blob / none — pick from Q&A answers>
- **Auth:** <none / Clerk via Vercel Marketplace / NextAuth — pick from Q&A>
- **AI:** <if applicable: AI SDK v6 + AI Gateway, list provider/model>
- **Other:** <only services explicitly required by Q&A — no speculative additions>

For every line, mark `(explicit)` if the user said so or `(defaulted)` if you chose it.

## Architecture
- **Routes / pages:** list each route and what it renders
- **Server Actions / API routes:** list each, with input schema → output schema (Zod / TS types)
- **Data model:** tables/schemas with columns and types (only if persistence is needed)
- **External integrations:** each service, what it does, what env var it needs

## Agent surface (AI-Agent-First)
Even if humans are the day-1 users, an AI agent must be able to drive the prototype. List:
- **Operations exposed to agents:** for each core action, the typed entry point (Server Action *and* `POST /api/...` route, or MCP tool) — including input/output schema.
- **Authentication (humans + machines):**
  - **Humans — Okta OIDC, auth-code flow.** Issuer URL, audience, and env var names: `OKTA_ISSUER`, `OKTA_AUDIENCE`, `OKTA_CLIENT_ID`, `OKTA_CLIENT_SECRET`.
  - **M2M — Vercel OIDC.** Caller (Vercel-hosted) presents its Vercel-minted JWT (env var name as confirmed via `vercel:env-vars`, typically `VERCEL_OIDC_TOKEN`); receiver verifies against Vercel's JWKS with pinned `iss` and `aud`.
  - **Shared verifier middleware** keyed on the `iss` claim — one route, two acceptable issuers.
  - **Non-Vercel-hosted machine callers** (if any): state explicitly how they authenticate (static API key header, named env var) and why Vercel OIDC isn't usable for them.
  - If OIDC is *not* used (e.g. "just me"), state that explicitly and justify.
- **Discovery:** the index/list endpoints an agent can call to enumerate state before acting (e.g. `GET /api/tasks`).
- **Observability:** how an agent confirms a side effect succeeded (response body / event log endpoint / webhook).
- **Idempotency:** which mutating operations accept a client-supplied ID for safe retry, and which don't (with rationale).
- **Schema artifact:** where the typed schema lives so agents (or tooling) can consume it — exported Zod schemas, generated OpenAPI doc, or MCP tool list.

## Build steps
Ordered list. Each step is 15–60 minutes of concrete work, e.g.:
1. `pnpm dlx create-next-app@latest <slug> --ts --tailwind --app --use-pnpm`
2. Install shadcn: …
3. Wire up `<route>` rendering …
4. Add Server Action `createX` …
5. Provision Vercel Postgres via `vercel` CLI, run schema migration …
6. Deploy preview: `vercel`

The list should be detailed enough that a fresh agent could execute it without re-asking the user.

## Verification plan
- **Golden path (human):** the one flow that must work, scripted as user actions in the browser.
- **Golden path (agent):** the same outcome, achieved by an external HTTP client (or `curl`) hitting the agent surface — to prove the prototype is genuinely agent-usable, not just agent-claimed.
- **Edge cases:** 1–2 obvious things to check (empty input, slow API, etc.).
- **How "done" is measured:** the success signal from Q&A.

## Riskiest assumption
The single thing most likely to invalidate the plan if it turns out to be wrong. One sentence.

## Open questions
Anything still unresolved after Q&A. If empty, write `None.`

## Research informing this plan
One-line pointer: `See RESEARCH.md for prior art, reference architectures, and platform-fit analysis that shaped these choices.`
```

After writing `PLAN.md`:

1. Print a condensed summary to the user: pitch + MVP scope + tech stack lines + the riskiest assumption.
2. Tell them the full plan is at `<workspace>/PLAN.md`, the Q&A log is at `<workspace>/QNA.md`, and the research note is at `<workspace>/RESEARCH.md`.
3. Ask whether to proceed to scaffolding. **Do not start scaffolding without an explicit yes.**

## Phase 4 — Hand-off (only on explicit approval)

If the user says go, execute the **Build steps** from `PLAN.md` in order. Before invoking any Vercel-specific CLI flow, also invoke the relevant `vercel:*` skills (e.g. `vercel:bootstrap` for resource provisioning, `vercel:deploy` for the first preview push) — they have current platform knowledge that this skill does not.

If the user wants changes to the plan first, edit `PLAN.md` directly (don't re-do Q&A unless they ask).

## Defaults when the user says "you decide"

Apply this stack and label each choice `(defaulted)` in `PLAN.md`. Every default below is chosen to satisfy the AI-Agent-First principle, not just human ergonomics:

- Next.js 16 App Router
- pnpm
- Tailwind v4 + shadcn/ui (only if UI is non-trivial)
- Vercel Postgres for relational, Vercel KV for ephemeral key-value, Vercel Blob for files
- **Every Server Action is also exposed as a `route.ts` POST handler** with a Zod-validated JSON contract — so agents can call it without a browser session
- No auth if "just me, localhost-only"; otherwise:
  - **Humans: Okta OIDC (authorization-code flow).** Pin issuer / audience / client to env vars (`OKTA_ISSUER`, `OKTA_AUDIENCE`, `OKTA_CLIENT_ID`, `OKTA_CLIENT_SECRET`).
  - **M2M: Vercel OIDC.** Vercel-hosted callers present their auto-injected token (typically `VERCEL_OIDC_TOKEN` — verify the current env var name via `vercel:env-vars` before wiring); the receiver verifies the JWT against Vercel's published JWKS, with pinned `iss` and `aud`.
  - Shared JWT-verifying middleware on every protected route, branching on the `iss` claim to pick the correct JWKS (Okta vs Vercel).
  - Static API keys are not the default — fall back to them only for non-Vercel-hosted machine callers and only with explicit user agreement.
- AI SDK v6 + AI Gateway for any LLM calls; default to a current Claude model unless the user specified otherwise
- Zod schemas for every input/output, exported from a shared `schemas/` module — single source of truth for both the human form validation and the agent contract
- `vercel` CLI for preview deploy first, promote to prod only on request

Before scaffolding, **verify current versions** of any of these via web search — don't trust this list as authoritative. (Per global CLAUDE.md: research first when versions matter.)

## Style rules

- **One question per `AskUserQuestion` call.** This is non-negotiable.
- **Questions are specific and answerable.** Bad: "What's the architecture?" Good: "Does the data need to survive a page refresh?"
- **Prefer multi-choice options** in `AskUserQuestion` so answers are unambiguous. Free-text via "Other" is the escape hatch, not the default.
- **Never assume an unanswered question.** If you must default, label it `(defaulted)` in the plan.
- **Keep QNA.md accurate.** Edit prior entries on revision rather than appending contradictions.
- **The plan is a hypothesis.** Call out the riskiest assumption explicitly so the user can challenge it before code is written.

## What to skip

- Don't write product code in this skill. The deliverable is the plan.
- Don't lecture about prototyping methodology or "lean MVP" theory.
- Don't pad the plan with generic boilerplate (no "Conclusion", no "Considerations", no aspirational roadmap).
- Don't ask 15 questions when 7 will do. Stop the moment the plan is unambiguous.
- Don't claim the prototype "works" later just because the plan compiles in your head — verification per global CLAUDE.md applies once code exists.

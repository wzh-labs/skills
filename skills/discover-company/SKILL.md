---
name: discover-company
description: Discover one noteworthy company (public or private) not yet in the knowledge base, then research it. Use when the user asks to "discover a company", "find me an interesting company", "surprise me with a company", "what company should I know about", or similar open-ended discovery requests. Picks a company based on recency, relevance to the user's domain (developer tools, AI infrastructure, web/cloud), and signal strength, then hands off to research-private-company or research-public-company.
---

# Discover a company

Goal: surface **one** company that is genuinely worth the user's attention right now — not already in the knowledge base — and produce a full research brief on it by invoking the appropriate downstream research skill.

## Step 1 — Read the existing knowledge base

Check what's already tracked so you don't repeat it:

```bash
ls ~/knowledge/companies/ 2>/dev/null        # private company slugs
ls ~/knowledge/public-companies/ 2>/dev/null  # public company tickers
```

Build two sets: `known_private` (slugs) and `known_public` (tickers). A company is "already known" if its slug or ticker appears in either set.

## Step 2 — Identify a candidate

Search broadly for companies that are making news right now. Run these in parallel:

- `AI developer tools startup 2026 funding`
- `infrastructure startup series a b 2026`
- `developer platform new launch 2026`
- `frontend web tooling company 2026`
- `AI agent framework company 2026`
- `database startup series funding 2026`
- `GitHub trending companies backed`
- `new startup product hunt launch 2026`

Use the results to generate a **candidate shortlist** of 5–8 companies. For each candidate, mentally score it on:

1. **Novelty** — not in `known_private` or `known_public`
2. **Relevance** — overlaps with: developer tools, AI/ML infrastructure, cloud/edge/CDN, frontend frameworks, databases, observability, security for web apps, or companies that compete with or complement Vercel
3. **Signal strength** — recent funding, product launch, public traction, or notable team. Avoid companies that are just blog posts with no product.
4. **Recency** — founded or made news in the last 18 months scores higher

Pick the **single highest-scoring candidate** that is not already known.

## Step 3 — Determine public vs private

A company is **public** if it trades on a major exchange (NYSE, NASDAQ, LSE, TSX, etc.) under a ticker symbol. Check by searching `<company> stock ticker` if not obvious.

- Public → proceed to Step 4a
- Private → proceed to Step 4b

## Step 4a — Research (public company)

Invoke the **research-public-company** skill with the resolved ticker. That skill handles all storage, git, and output.

Before invoking, announce to the user:

> Discovered: **<Company Name>** (<TICKER>) — <one-line reason why this is interesting>. Researching now…

## Step 4b — Research (private company)

Invoke the **research-private-company** skill with the company name. That skill handles all storage, git, and output.

Before invoking, announce to the user:

> Discovered: **<Company Name>** — <one-line reason why this is interesting>. Researching now…

## Selection principles

- **One company per run.** Don't list multiple candidates to the user — pick the best one and go.
- **Prefer private companies** when the signal is equal — private companies are harder to track and benefit more from the KB investment.
- **Avoid hype without substance.** A company with a viral tweet but no product, customers, or funding is not worth a brief.
- **Avoid obvious giants.** Don't pick Stripe, GitHub, Cloudflare, or other household names unless something genuinely material just happened that warrants a first-time brief.
- **Relevance to the user's world** — the user works at Vercel. Weight companies in the developer platform, AI tooling, edge compute, CDN, frontend, or infrastructure-as-code space higher.
- **If all candidates are already known**, do a second broader search sweep before giving up. Only report "no new candidates found" if two sweep attempts both produce all-known results.

## Output

The output is entirely produced by the downstream research skill (full brief in initial mode, changelog entry in delta mode). This skill adds only the one-line "Discovered" announcement before handing off.

Do not produce a separate summary or conclusion — the brief IS the output.

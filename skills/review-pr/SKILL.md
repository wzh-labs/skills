---
name: review-pr
description: Review a GitHub pull request from a URL and produce a structured, actionable review in chat. Covers correctness, security, style/conventions, and performance, grounded in the actual diff and PR context. Output stays in chat — never posts comments to the PR. Use when the user pastes a GitHub PR URL and asks to "review this PR", "look at this PR", "code review github.com/...", or similar. Distinct from the built-in `/review` skill, which reviews local uncommitted changes.
---

# Review PR

Goal: read a GitHub PR end-to-end and produce a review the user can act on — what's wrong, where, and how to fix it. Grounded in the diff and the PR's stated intent. Chat-only output; never post to the PR.

## Inputs

Required:
- `url` — a GitHub PR URL (`https://github.com/<owner>/<repo>/pull/<number>`). Also accept the short form `<owner>/<repo>#<number>` or a bare PR number when the user is already inside a checked-out repo.

If the URL is missing or malformed, ask once and stop.

## Prerequisites

- `gh` CLI installed and authenticated (`gh auth status`). If not authenticated, stop and tell the user to run `gh auth login` — do not try to work around it.
- Network access to github.com.

## Method

### 1. Parse the URL

Extract `owner`, `repo`, `number`. Reject anything that isn't a PR URL (issues, commits, compare views).

### 2. Fetch PR context — in parallel

Run these in a single batch; they're independent:

```bash
# Metadata: title, body, author, state, base/head, mergeable, reviewers, labels, linked issues
gh pr view <number> --repo <owner>/<repo> --json number,title,body,author,state,isDraft,baseRefName,headRefName,mergeable,reviewDecision,labels,additions,deletions,changedFiles,closingIssuesReferences,url

# Files + per-file additions/deletions/status
gh pr view <number> --repo <owner>/<repo> --json files

# CI / checks status
gh pr checks <number> --repo <owner>/<repo>

# Full diff
gh pr diff <number> --repo <owner>/<repo>
```

For very large diffs (>2000 lines or >50 files), also fetch the file list first and review file-by-file rather than holding the entire diff in context. Note the size in the output so the user knows coverage may be partial.

### 3. Read intent before judging code

Before scanning the diff for issues, read:

- The PR **title and body** — what is this trying to do? What did the author flag as known issues or out of scope?
- **Linked issues** (`closingIssuesReferences`) — fetch their bodies if they add context (`gh issue view`).
- The **base branch** — usually `main`, but not always. Note if the target is a feature branch.

A "bug" that matches the PR's stated intent is not a bug. Many review comments come from reviewers who skipped this step.

### 4. Verify unfamiliar APIs against current docs

If the diff uses third-party APIs, library calls, framework patterns, or config you can't recognize confidently from training, **look them up before flagging anything as wrong**. Training data goes stale. Use `WebFetch` or `WebSearch` against the library's current docs. Only flag an API misuse after confirming the current shape of the API.

(Skip this for plainly internal code, typos, renames, and obvious one-line bugs.)

### 5. Scan the diff across four focus areas

For each, walk the diff and note issues with `file:line` precision. Be specific — quote the offending line or describe the exact location.

**Correctness & bugs**
- Logic errors, off-by-one, wrong operator, swapped args
- Missing or wrong edge-case handling (null/empty/zero/negative, unicode, large inputs)
- Race conditions, missing awaits, unhandled promise rejections, dangling resources
- State mutations that break invariants
- Tests: did the author add tests proportional to the change? Are the assertions actually checking the new behavior, or just smoke-testing?

**Security**
- Injection vectors (SQL, shell, template, XSS, SSRF) — especially anywhere user input flows into a sink
- Authn/authz: missing checks, privilege escalation, IDOR, insecure direct references
- Secrets in code, logs, error messages; tokens with too-broad scope
- Unsafe deserialization, unsafe file paths, path traversal
- Crypto misuse: weak primitives, predictable IVs, hardcoded keys
- Dependency additions — flag if the new package is unmaintained, misnamed (typosquat), or has known CVEs

**Style & conventions**
- Inconsistent with the surrounding repo's patterns (naming, module layout, error handling style)
- Comments that explain *what* instead of *why*; dead comments referring to removed code
- Premature abstractions, unused exports, half-finished implementations
- Skip anything a linter/formatter already enforces — don't duplicate CI

**Performance**
- N+1 queries, unnecessary loops over remote calls, sync I/O on hot paths
- Allocations in tight loops, accidental quadratic behavior
- Unbounded memory: reading entire files when streaming would do, unbounded caches
- Bundle-size regressions on the client (large new deps imported at the top level)
- Missing indexes hinted at by new query shapes

### 6. Check CI signal

From `gh pr checks`, note: failing checks, pending checks, missing required checks. Don't rephrase what CI already says — but do flag if the author marked the PR ready while checks are red, or if a required check is missing entirely.

### 7. Produce the review

Print one structured block. No preamble.

```
## PR review — <repo>#<number>: <title>

**Author:** <login> · **State:** <state><draft?> · **Base:** <baseRefName> ← <headRefName>
**Size:** +<additions> / −<deletions> across <changedFiles> files · **CI:** <pass/fail/pending counts>
**Mergeable:** <mergeable> · **Linked issues:** <list or —>

### Intent
<1–3 sentences summarizing what the PR is trying to do, drawn from title + body + linked issues. If the body is empty, say so — that itself is a review note.>

### Blockers
<Issues that should block merge. Each: **[area] file:line** — what's wrong + suggested fix. Empty section if none.>

### Should-fix
<Real issues that aren't blockers but the author should address. Same format.>

### Nits & questions
<Style nits, questions for the author, things you'd want clarified. Same format. Mark questions with `?`.>

### Tests
<Brief: what's covered, what's missing, whether assertions match the change.>

### Out of scope (noted, not flagged)
<Things you noticed but won't pursue — pre-existing issues, intentional per the PR body, etc. Keep this short.>
```

Each issue line should be one sentence (two if a fix suggestion is non-obvious). Cite `file:line` always — no vague "in the auth code". Quote the offending snippet only when the line number alone is ambiguous.

If you couldn't fetch part of the data (e.g. CI not yet run, body empty), say so explicitly in the relevant section rather than omitting it silently.

### 8. Coverage caveat

If the diff was too large to review in full, end the output with a one-line note: `Reviewed N of M files; skipped: <list>`. Don't pretend you read what you didn't.

## Style

- **Be specific.** Vague feedback ("consider refactoring this") is noise. Either say what to do or don't say it.
- **Severity discipline.** Most comments are nits; very few are blockers. If everything is a blocker, nothing is.
- **No praise theater.** Skip "nice work on X" sections. The user wants problems, not affirmation. A short positive note is fine if a non-obvious decision was clearly the right call.
- **Diff-scoped.** Do not flag issues in code the PR didn't touch unless the change makes that pre-existing issue newly load-bearing.
- **Don't speculate.** If you're unsure whether something is a bug, frame it as a question in the Nits & questions section, not a Blocker.

## Output destination

**Chat only.** Never run `gh pr review`, `gh pr comment`, `gh pr review --approve`, or any other write command against the PR. The user reads the review, decides what (if anything) to post, and posts it themselves. If the user explicitly asks you to post afterward, that's a separate request — confirm exactly what to post and to which thread before running any write command.

## Failure modes

- **`gh` not authenticated:** stop, tell the user to run `gh auth login`. Don't try unauthenticated API calls.
- **PR not found / private repo without access:** stop with the exact `gh` error message; don't guess.
- **URL is for an issue or commit, not a PR:** reject and ask for a PR URL.
- **PR is closed or merged:** review anyway, but note the state at the top — the user may be doing a post-merge audit.
- **Draft PR:** review anyway. Many drafts are sent specifically to get early feedback. Note the draft state but don't withhold the review.

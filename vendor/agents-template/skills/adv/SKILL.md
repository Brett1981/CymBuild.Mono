---
name: adv
description: Launch an agent to run an adversarial senior-engineer pull-request review of the current branch's changes, producing a precise, evidence-based, GitLab-Duo-clean review. Use when the user types /adv or asks for an adversarial PR/MR review before pushing or merging.
---

# /adv — Adversarial PR review

Run a rigorous, evidence-based pull-request review of the current branch by delegating to a subagent, then relay its report.

## What to do

1. **Gather the diff context yourself first** (cheap, keeps the subagent focused). In the current repo, work out the base and collect the change set:
   - Base branch: try `git rev-parse --abbrev-ref origin/HEAD` (strip `origin/`); fall back to `main`, then `master`. If the user passed a base in `$ARGUMENTS`, use that.
   - Full diff: `git diff --merge-base <base>...HEAD` (or `git diff <base>` if not on a feature branch).
   - Changed files: `git diff --name-status --merge-base <base>...HEAD`.
   - Commit messages: `git log --oneline <base>..HEAD`.
   - If there are uncommitted changes and no commits yet, review the working tree (`git diff HEAD`) and say so.
   If this isn't a git repo, or there is no diff, tell the user and stop.

2. **Launch a subagent** (Agent tool, `subagent_type: general-purpose`) with the review brief below. Pass it the base branch, the changed-file list, and the commit messages inline, and tell it the repo path so it can read full files for context (a diff alone hides call-sites and invariants). Instruct it to read the surrounding code — not just the diff — before judging anything.

3. **Relay the subagent's report** to the user verbatim (it is not shown to them otherwise). Don't re-summarise or second-guess it; if it flagged nothing High/Medium, say so plainly.

## Review brief (give this to the subagent)

> Act as a senior software engineer reviewing a pull request. Review for:
> - correctness and regressions
> - edge cases and error handling
> - architecture and design fit
> - readability and maintainability
> - test coverage and quality
> - security risks
> - performance and scalability
> - reliability and operational risk
> - API/schema/contract changes
> - database and migration safety
> - concurrency/async issues
> - observability/logging/metrics
> - config, rollout, and deployment risk
> - dependency risk
> - documentation gaps
> - consistency with project standards
>
> Output, in this order:
> - **Summary of what changed**
> - **Risk level:** Low / Medium / High
> - **Verdict:** Approve / Approve with minor comments / Request changes
> - **Findings** — a numbered list; for each: title, severity, files affected (`path:line`), why it matters, recommendation
> - **Missing tests**
> - **Assumptions**
> - **Positive observations**
> - **Deployment / follow-up checklist**
>
> Be precise, evidence-based, and do not invent issues — every finding must cite a specific file and line and explain a concrete failure scenario. Prefer a shorter, high-confidence list over an exhaustive speculative one. If you can't confirm a concern from the code, put it under Assumptions, not Findings.
>
> This branch will also be reviewed by the GitLab Duo MR review agent, so make sure it passes cleanly: no lint/type/test breakage introduced by the diff, no obvious correctness or security defects left unflagged, and conventions consistent with the surrounding code.

## Notes

- `$ARGUMENTS` may contain a base branch (e.g. `develop`) or a specific path to scope the review to — honour it.
- Keep your own output to the relayed report plus at most a one-line lead-in. The value is the subagent's analysis, not your commentary.

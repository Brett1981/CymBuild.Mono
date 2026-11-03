# AGENTS.md — SOCOTEC UK

House rules for AI coding agents (Claude Code, Cursor, Copilot, etc.) working in
SOCOTEC UK repositories. Copy this file to the root of your repo, or to
`~/.claude/CLAUDE.md` to apply it to everything you work on. Then fill in the
placeholders below and delete anything that doesn't apply to you.

> **Filename:** `AGENTS.md` is the tool-agnostic convention. Claude Code reads
> `CLAUDE.md`; symlink it (`ln -s AGENTS.md CLAUDE.md`) so both work from one source.

---

## 1. Fill these in first

Search the whole template for `<...>` and replace:

| Placeholder | Meaning | Example |
|---|---|---|
| `<branch-prefix>` | Your personal branch namespace | `tom`, `jbloggs` |
| `<JIRA-PROJECT>` | Default Jira project key | `AMS2` |
| `<gitlab-group>` | GitLab group your projects live under | `socotec-group/uk` |
| `<signing-key>` | Path to your commit-signing key | `~/.ssh/gitlab_signing` |

Delete this section once you've done it.

---

## 2. Working agreements

**Repo conventions**
- If the folder contains an `llm.md` (or a nested `AGENTS.md`), read it — those instructions win over this file.
- If a format command exists, run it before committing (e.g. `bun format`, `npm run format`, `gofmt`).
- If tests run in CI, add test cases covering any code you change. Don't ship an untested change to a pipelined repo.

**.NET repositories** — see [docs/dotnet.md](docs/dotnet.md)
- If the repository contains .NET project markers, read the linked guidance before planning or changing code.

**Branches, commits and MRs** — see [docs/branching-and-commits.md](docs/branching-and-commits.md)
- Branch from the latest `origin/main` unless a release branch is explicitly named as the base.
- Name branches `<branch-prefix>/<JIRA-KEY>` when there's a ticket, otherwise `<branch-prefix>/<short-kebab-summary>`. If Jira ticket isn't provided check once if there is one.
- Start MR/PR titles with the Jira key when one exists: `<JIRA-PROJECT>-123: <summary>`.
- The group requires signed commits — configure signing once, before your first push.

**Merge request review** — see [docs/merge-requests.md](docs/merge-requests.md)
- After opening an MR, spawn a tech lead agent to run a review pass over it.
- The `/adv` skill runs exactly this pass over the current branch: [skills/adv/SKILL.md](skills/adv/SKILL.md).
- Rate every finding Critical / High / Medium / Low, and **verify each one against the real code before reporting it** — a throwaway probe script beats speculation.
- Post inline threads for Critical and High only. Medium and Low go in the summary back to the author.
- No Critical/High findings means nothing gets posted. That is a good outcome, not a reason to manufacture one.
- Close the loop: reply and resolve threads you actually fixed; leave real-but-deferred findings **open** with a reason. Never resolve a thread just to tidy the count.

**GitLab API mechanics** (the 415 trap, diff anchors, resolving threads) — see [docs/gitlab-review-api.md](docs/gitlab-review-api.md)

**CI and deployment** — see [docs/gitlab-ci-deploy.md](docs/gitlab-ci-deploy.md)
- Pin `tags: [internal]`; shared runners are disabled on these projects.
- Deploy via the GitLab Kubernetes Agent contexts, not stored kubeconfigs.

**Writing style** — see [docs/writing-style.md](docs/writing-style.md)
- Agents write our commit messages, MR descriptions, review comments and tickets. Unedited, that prose is padded and announces its own structure.
- The test: would a competent colleague have written this sentence? If not, cut it.
- Preserve meaning over style. Never change a fact, magnitude, negation or scope while editing for tone.
- Technical register is not slop — check the protected list before "fixing" anything.

**Jira** — see [docs/jira-adf.md](docs/jira-adf.md)
- Jira is Cloud: descriptions and comments are **ADF JSON**, not wiki markup. Passing `h2.` or `||header||` to `acli` stores them as literal text.
- Build ADF with [scripts/adf.py](scripts/adf.py) and pass `--description-file`, then verify it rendered as structure.
- If given a Jira project rather than a ticket, offer to create the ticket with `acli` and use its key.

**Isolated worktrees + temp DBs (Hub apps)** — see [docs/worktrees.md](docs/worktrees.md)
- For Next.js + Prisma repos on the shared local Postgres, run `skills/worktree/setup.sh <slug>` to get a worktree with its own branch and its own temp DB.
- Work parallel tickets that touch the same schema without clobbering each other's data.

**Attribution**
 - Do not add `Co-Authored-By` lines to commit messages.

---

## 3. Extending this file

Keep this file short enough to stay read. When a section grows past a screen,
move it into `docs/` and leave a one-line pointer here — that's why the sections
above are mostly links. Agents follow links; they skim walls of text.

# SOCOTEC UK — agent instructions template

A getting-started `AGENTS.md` for anyone using an AI coding agent (Claude Code,
Cursor, Copilot, …) against SOCOTEC UK repositories. It captures the conventions
that aren't discoverable from the code — branch naming, the MR review loop, the
GitLab API quirks, CI/deploy shape, and how Jira Cloud actually stores text.

## Layout

```
AGENTS.md                      ← the entry point; short, mostly links
docs/
  dotnet.md                    ← general .NET repository guidance
  branching-and-commits.md     ← branch naming, signed commits, MR titles
  merge-requests.md            ← the tech-lead review pass and closing threads
  gitlab-review-api.md         ← glab API mechanics (415 trap, anchors, resolving)
  gitlab-ci-deploy.md          ← runners, k8s agent contexts, k8.yaml, pull secrets
  writing-style.md             ← cutting AI tells from agent-written prose
  jira-adf.md                  ← Jira Cloud is ADF, not wiki markup
  worktrees.md                 ← isolated worktree + temp DB per ticket (Hub apps)
scripts/
  adf.py                       ← ADF document builder used by jira-adf.md
skills/
  adv/                         ← /adv skill: adversarial PR review pass
  worktree/                    ← /worktree skill: SKILL.md + setup.sh
ci/
  check-docs.py                ← format checks; run locally with python3 ci/check-docs.py
```

Only `AGENTS.md`, `docs/`, `scripts/` and `skills/` are copied into adopting repos.
`ci/` checks this repo's own docs and stays here.

`AGENTS.md` is deliberately short. Agents reliably follow links out of a small
file; they skim a long one. Keep new detail in `docs/` with a one-line pointer.

## Adopting it

**Per repo** (recommended — the instructions travel with the code and everyone on
the repo gets them):

```bash
cp -r agents-template/{AGENTS.md,docs,scripts,skills} /path/to/your/repo/
```

The `skills/` dir is Claude Code specific. Drop it if your team uses a different agent, or
symlink `skills/worktree` under `~/.claude/skills/` to invoke it as `/worktree`.

**Personally, across everything you work on:**

```bash
cp agents-template/AGENTS.md ~/.claude/CLAUDE.md
```

**Claude Code users, per repo** — Claude Code looks for `CLAUDE.md`, so symlink it
rather than maintaining two copies:

```bash
ln -s AGENTS.md CLAUDE.md
```

## Then customise

1. Open `AGENTS.md` and work through section 1 — replace every `<placeholder>`
   (`<branch-prefix>`, `<JIRA-PROJECT>`, `<gitlab-group>`, `<signing-key>`), then
   delete that section.
2. Grep the `docs/` files for the same placeholders.
3. Delete what doesn't apply. A team with no Kubernetes deployments should drop
   `gitlab-ci-deploy.md` and its pointer — stale instructions are worse than none.
4. Confirm the commit attribution rule matches your team's convention.

## Keeping it useful

Add to it when an agent gets something wrong in a way that a written rule would
have prevented — a failure mode that cost you an hour is exactly what belongs
here. Don't document what the repo already records: code structure, past fixes,
git history. This file is for the conventions and traps that live only in people's
heads.

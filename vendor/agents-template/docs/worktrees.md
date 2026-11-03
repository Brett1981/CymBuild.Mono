# Isolated worktrees + temp DBs

`skills/worktree/setup.sh <slug>` spins up a git worktree with its own branch, its own temp
Postgres database, and a generated Prisma client. Two tickets that touch the same files or
schema can then be worked at once without clobbering each other's data.

Scope: the Hub apps only, meaning Next.js plus Prisma 7 on the shared local Postgres, with
SSO pinned to a fixed port. For anything else, a plain `git worktree add` is the right tool.

## Run

```bash
bash skills/worktree/setup.sh <slug>     # e.g. ph-63, sh539, form-128
cd <repo>/.claude/worktrees/<slug>
source worktree.env                      # points the app AND prisma at the temp DB
bun run dev                              # or: bunx prisma db push / migrate / seed / test
```

## Two traps it handles

Prisma 7 generates its client into a gitignored, repo-local folder, so a fresh worktree has
no client and the app fails to boot with a "Cannot find module" error. The script runs
`prisma generate` in the worktree for you.

SSO redirect URIs are registered for each app's canonical port, so the dev server cannot move
to a free port and still let you log in. The script keeps that port and warns when it is
already taken. Only one interactive instance can hold it, so stop the other checkout first.

## Where the parallelism actually is

Interactive work needs the canonical port and runs one instance at a time. Non-interactive
work (`prisma db push`, `migrate`, `seed`, tests) needs no port, and that is exactly what the
per-worktree temp DB is for: run it across many worktrees at once.

See [skills/worktree/SKILL.md](../skills/worktree/SKILL.md) for the full flag list and teardown.

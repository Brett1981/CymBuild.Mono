---
name: worktree
description: Spin up an isolated git worktree + temp Postgres DB for a ticket in a SOCOTEC "Hub" app (Next.js + Prisma 7 on the shared local Postgres — clienthub, projecthub, form-generator, tender-intelligence, etc.), so multiple tickets touching the same files or schema can be worked on in parallel without clobbering each other's data. Use when the user types /worktree or asks to create a worktree / isolated env / temp DB for a branch or ticket in one of those repos.
---

# /worktree — isolated worktree + temp DB per ticket (Hub apps)

Creates a git worktree with its own branch, symlinked env/secrets, its **own** Postgres
database (so schema changes on one ticket never touch another's data), and a generated
Prisma client. Built for the shared local Postgres these repos use:
`postgresql://<user>:<pass>@localhost:5432/<db>?sslmode=disable`.

## Scope — this is for the Hub family only

Use it **only** for the SOCOTEC apps that are all: **Next.js + Prisma 7 + the shared local
Postgres + SSO pinned to a fixed port** — clienthub, projecthub, form-generator,
tender-intelligence, and siblings built the same way.

It is **not** a general worktree tool. Do **not** use it for:
- repos with no Prisma / no local Postgres (nothing to clone or generate),
- non-Next apps, or apps whose auth isn't port-pinned,
- anything where "a temp copy of the local DB" isn't the point.

For those, a plain `git worktree add` is the right tool.

## What it does

For the repo you're currently in, `setup.sh <slug>`:

1. **Worktree** at `<repo>/.claude/worktrees/<slug>` on branch `<branch-prefix>/<slug>` (cut from
   `origin/main`). `.claude/` is gitignored.
2. **Symlinks** `.env`, `.env.local`, and `node_modules` from the main checkout.
3. **Temp DB** `<db>_<slug>` (e.g. `client_hub_wt63`), cloned from the repo's current DB
   with schema **and** data via a Postgres `TEMPLATE` copy (falls back to `pg_dump | psql`
   if the source DB has live connections — i.e. the main dev server is running).
4. **`prisma generate`** in the worktree — **required**, see below.
5. **`worktree.env`** exporting the temp `DATABASE_URL` (no port — see below).

### Two things that are specific to these apps (and that a generic worktree gets wrong)

**Prisma 7 needs a per-worktree `generate`.** The `prisma-client` generator writes its
output to a **repo-local, gitignored** path (`output = "../src/generated/prisma"`). A fresh
worktree doesn't have it, and symlinking `node_modules` doesn't help — the client no longer
lives there. Without `prisma generate` the app dies on boot with
`Cannot find module '@/generated/prisma/client'`. The script always runs it.

**You cannot move the dev server off its canonical port.** SSO (Azure AD) redirect URIs are
registered for each app's fixed port (clienthub `3002`, projecthub `3007`,
form-generator `3003`, …) — see `AAD_REDIRECT_URI` / `BASE_URL` in `.env`. Run on any other
port and login fails. So the script does **not** assign a port; it detects the canonical one
and **warns if it's already in use**. Only one interactive instance can hold that port at a
time — stop the other checkout first.

### Where the parallelism actually is

- **Interactive / needs login** → the app runs on its canonical SSO port, **one at a time**.
  A worktree here buys you an isolated branch + DB you can switch to on that port.
- **Non-interactive** (`prisma db push`, `migrate`, `seed`, `vitest`, `playwright`) → needs
  no port and no SSO. This is what the per-worktree temp DB is for: run schema/data work on
  **many worktrees in parallel** without them clobbering each other.

### Why an exported DATABASE_URL, not editing .env.local

Prisma's `prisma.config.ts` uses `dotenv/config`, which reads **only `.env`** — while Next
reads `.env.local` over `.env`. Overriding the DB only in `.env.local` would leave
`bunx prisma db push` pointed at the **main** DB. Instead we keep `.env` symlinked and export
`DATABASE_URL` in `worktree.env`: dotenv and `@next/env` never overwrite an already-set
variable, so the export wins for **both** the app and every prisma command.

## How to run it

From inside the target repo (the script ships at `skills/worktree/setup.sh`; Claude Code users
usually symlink it under `~/.claude/skills/worktree/`):

```bash
bash skills/worktree/setup.sh <slug>
```

Pass the ticket as `<slug>` (e.g. `ph-63`, `sh539`, `form-128`). Then:

```bash
cd <repo>/.claude/worktrees/<slug>
source worktree.env
bun run dev            # binds the canonical SSO port; stop other instances first
# or, no port needed:  bunx prisma studio / bunx prisma db push / bun run test
```

**Always `source worktree.env`** in any shell before running the dev server or prisma in that
worktree — that's the line that puts it on its own DB.

### Options

| flag | effect |
|------|--------|
| `--branch <name>` | branch name (default `<branch-prefix>/<slug>`) |
| `--base <ref>` | base to cut from (default `origin/HEAD`, else `main`) |
| `--db <name>` | temp DB name (default `<db>_<slug>`) |
| `--from-db <name>` | source DB to clone (default: the repo's current DB) |
| `--empty` | empty DB + `prisma db push` instead of copying data |
| `--no-db` | worktree + env only, no database |
| `--no-modules` | don't symlink node_modules (`bun install` yourself) |

## Tear down

The script prints the exact teardown commands for the worktree it made:

```bash
git -C <repo> worktree remove <repo>/.claude/worktrees/<slug>
dropdb -h localhost -p 5432 -U <user> <db>_<slug>
```

## When invoked

Run the script for the user with the slug they give, from their current repo. First check the
repo looks like a Hub app (has `prisma.config.ts` / a Prisma schema and a local-Postgres
`DATABASE_URL`); if it doesn't, say so and suggest a plain `git worktree add` instead. If
they're not in a repo, or didn't give a slug, ask which repo/ticket. Relay the script's
summary; if the DB clone fell back to `pg_dump`, `prisma generate` failed, or the canonical
port was already in use, say so.

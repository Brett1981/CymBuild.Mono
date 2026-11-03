# Branching, commits and MR titles

## Branching

- **Always branch from the latest `origin/main`.** Fetch first — don't branch from a stale local `main`:

  ```bash
  git fetch origin && git switch -c <branch-prefix>/<name> origin/main
  ```

  The only exception is when a release branch is explicitly named as the starting point.

- **Naming:**
  - With a Jira work item: `<branch-prefix>/<JIRA-KEY>` — e.g. `tom/AMS2-264`
  - Without one: `<branch-prefix>/<short-kebab-summary>` — e.g. `tom/fix-sidebar-scroll`

- **Only prompt once for a ticket key.** If no work item was given, ask once then pick a descriptive
  name and carry on. If the user names a *project* rather than a ticket, offer to
  create the ticket with `acli` (see [jira-adf.md](jira-adf.md)) and use the key it returns.

## Signed commits

The `<gitlab-group>` group has a push rule requiring GPG- or SSH-signed commits.
Unsigned pushes are rejected at the server, so configure this before your first push:

```bash
git config gpg.format ssh
git config user.signingkey <signing-key>.pub
git config commit.gpgsign true
```

> `git log --show-signature` errors locally unless you've also set an
> `allowedSignersFile`. That is a local verification gap only — the commit **is**
> signed and GitLab verifies it server-side. Don't chase this as a bug.

## Before committing

1. Run the repo's format command if one exists (`bun format`, `npm run format`, `gofmt -w`, …).
2. If the repo runs tests in CI, add or update tests covering the change.
3. Commit and push only when asked. If you're on the default branch, branch first.

## MR / PR titles

| Situation | Title |
|---|---|
| Jira work item exists | `<JIRA-PROJECT>-123: Short summary of the change` |
| No work item | A clear descriptive summary — no key, no placeholder |

Keep the body focused on *what changed and why*, and link the ticket.

# Merge requests and review

## Opening the MR

```bash
glab mr create --fill --target-branch main
```

Title per [branching-and-commits.md](branching-and-commits.md). Then run a review pass.

## The tech-lead review pass

After an MR is opened, review it as a tech lead would — either yourself or, if
your tool supports subagents, by delegating to one. When delegating, give the
reviewer everything it needs to work independently:

- the MR IID and the project path
- the local branch checkout to read the real code from
- **the intent of the change** — reviews without intent produce noise

### Rules the reviewer follows

1. **Rate every finding** Critical / High / Medium / Low.
2. **Verify before reporting.** Check each finding against the actual code — write
   a throwaway probe script rather than reasoning about what the code probably does.
   An unverified finding wastes more of the author's time than it saves.
3. **Post inline threads for Critical and High only.** Medium and Low come back in
   the written report instead — they're worth knowing, not worth blocking on.
4. **Nothing to post is a valid result.** No Critical/High findings means no threads.
   Never manufacture a finding to justify the review.
5. **Relay the report.** A subagent's own report usually isn't shown to the user —
   summarise it back to them explicitly.
6. **Don't take findings on trust.** Verify each one against the code yourself before
   acting on it or repeating it, and say plainly when one doesn't hold up.

Then fix what's real.

## Closing the loop on threads

This is the half that usually gets skipped, and it's the half reviewers notice.

- **Fixed and pushed** → reply on the thread saying what changed and in which commit, then resolve it.
- **Real but not being fixed in this MR** → reply with the reason and the follow-up (ticket, next MR), and **leave it open**.
- **Never resolve a thread to tidy the count.** An unresolved thread is a deliberate
  signal that something is outstanding; clearing it destroys that signal.
- Report which threads were resolved and which were deliberately left open.

The API calls for posting and resolving are in [gitlab-review-api.md](gitlab-review-api.md).

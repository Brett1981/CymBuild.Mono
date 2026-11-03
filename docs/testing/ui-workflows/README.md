# UI workflow cache

Learned step sequences for `/cymbuild-uitest`, one file per workflow key
(e.g. `create-job.md`, `create-asset.md`). These are a **cache**, not a
source of truth — the app's metadata and pages are the source of truth.
A file here just lets a future run skip re-discovering a flow it has
already walked successfully, and lets a human sanity-check what Claude
thinks the flow is.

## When a file goes stale

If a run following a cached file hits a page/field/button that doesn't
match, the flow has drifted from what's recorded. Re-discover it live,
overwrite the file, and don't silently patch around the mismatch.

## File format

```markdown
---
workflow: create-job
last_verified: 2026-09-04
verified_against: local DEV (https://localhost:44368)
---

# Create Job (via Enquiry -> Quote -> Job)

## Entry point
- Page: Pages/Enquiries/EnquiryList.razor (`/enquiries`)

## Steps
1. Click "New Enquiry" -> opens EnquiryEdit form.
2. Fill required fields: ... (list the actual metadata-driven fields seen,
   not assumptions).
3. Save -> creates Enquiry, status transitions to "Open" via
   SCore.DataObjectTransitionUpsert (observed in network tab / UI status
   badge, not asserted).
4. Click "Convert to Quote" action -> opens QuoteEdit prefilled from Enquiry.
5. ...
6. Click "Convert to Job" -> creates Job record.

## Test-data markers used
- Enquiry reference / notes field prefixed `UITEST_<run-id>_`.

## Gotchas
- Anything that wasn't obvious: fields that look required but aren't,
  actions hidden behind a menu, async validation that blocks Save, etc.
```

Keep entries factual and evidence-based (what the UI actually did), per
`AGENTS.md`'s "do not guess" rule — this file is read back and trusted by
future runs.

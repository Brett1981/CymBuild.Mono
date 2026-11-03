---
workflow: update-account-name
last_verified: 2026-10-08
verification_status: verified
verified_against: local DEV (https://localhost:44368, API on https://localhost:7202, DB ShoreDB -> 10.100.34.114\general / CymBuild_DEV264, release/26.4 @ c58053e9)
target_environment: local DEV only
depends_on: create-account
---

# Update Account Name

## Purpose

Verify that an existing UI-test Account can be edited and saved without
creating another Account or changing its identity.

## Local run prerequisites

Start CymBuild using `.\tools\UI\Start-CymBuildLocal.ps1` and sign in through
the local PWA.

## Test-data contract

- `OriginalName` = `UITEST_Account_<run-id>`.
- `UpdatedName` = `UITEST_Account_<run-id>_Updated`.
- The target must have been created by the current automated run.
- Capture the Account's non-zero `DataObjectGuid` before editing.

## Retry rule

Search for both `OriginalName` and `UpdatedName` before editing:

- If exactly one `UpdatedName` exists and no `OriginalName` exists, treat the
  workflow as already completed and verify the GUID.
- If exactly one `OriginalName` exists and no `UpdatedName` exists, edit it.
- For any other combination, fail without changing data.
- Never append `_Updated` more than once.

## Steps

1. Open **CRM** (there is no separate "Accounts" nav item) and apply the retry
   rule above via the grid's **Search** box.
2. **Double-click** the exact `OriginalName` row (a single click does not open
   it — see `find-and-open-account.md`).
3. Confirm the current **Name** equals `OriginalName` and the page has the
   expected non-zero `DataObjectGuid`.
4. Triple-click the **Name** field to select its full contents, then type
   `UpdatedName` to replace it.
5. Leave Code (Sage), Account Status, Parent Account, Account Type flags,
   Relationship Manager, addresses, contacts and all other fields unchanged.
   Editing an existing, already-validated record did **not** re-trigger the
   "You must validate before you can save" gate or the "Possible Account
   Duplicates" modal — **Save** was directly clickable without re-running
   **Validate**.
6. Click the form-level **Save** once.
7. Confirm:
   - a green **"Success: Record Saved Successfully"** banner is shown (no
     SharePoint-provisioning banner this time — that only fires on the
     initial create, not a plain field edit);
   - **Name** now equals `UpdatedName`;
   - the `DataObjectGuid` and **Account ID** are unchanged;
   - the page did not return to a zero/new-record route.
8. **Do not click "Save and Exit" a second time in quick succession.** See
   Gotchas: an extra/immediate click on it navigated to a **blank new-record**
   `AccountDetail` form (Account ID `0`, `DataObjectGuid` all-zero) instead of
   back to the CRM grid. Click it once, then wait for and confirm the
   navigation actually happened (URL changes to `/crm/00000000-...`) before
   clicking anything else. If you do land on a blank new form unexpectedly,
   do **not** type into it or click Save — navigate away via the **CRM**
   left-nav link, which safely discards the untouched blank form with no
   confirmation prompt and creates no record.
9. On the Accounts grid, exact-match search for `UpdatedName` and confirm
   exactly one active row, and that no stray/blank row was created by the
   Gotcha above.
10. Exact-match search for `OriginalName` and confirm no active row remains
    under the old exact name.

## Expected result

- The original Account is renamed once.
- Its `DataObjectGuid` remains stable.
- No second Account is created.
- No unrelated field or status is changed.

## Verified result (this run)

- Before: Account ID `76815`, Name `UITEST_Account_20260904_114956`,
  `DataObjectGuid` `7b5a151d-dae6-4aab-b287-166a5467f0fd`.
- After: same Account ID and `DataObjectGuid`, Name
  `UITEST_Account_20260904_114956_Updated`. Success banner: "Record Saved
  Successfully". Grid search for the base `UITEST_Account_20260904_114956`
  token (matches both old and new names) returned exactly one row — the
  updated one — confirming no duplicate or stray record survived the
  double-"Save and Exit" gotcha below.

## Gotchas

- `SCrm.AccountsUpsert` also refreshes the Office filing target name. The UI
  workflow should observe and report visible side effects but must not call
  the Office or SharePoint integration directly.
- Do not use a pre-existing business Account to test editing.
- Do not use browser Back immediately after typing; an unsaved-change prompt
  can make the test ambiguous.
- **Clicking "Save and Exit" a second time (e.g. because the first click's
  navigation hadn't visibly completed yet) opened a blank new-record Account
  form instead of returning to the grid.** Root cause not confirmed (possibly
  the return-URL/navigation-stack handling re-entering the "New" route), but
  the failure mode is safe as long as you don't act on the blank form: it has
  no unsaved changes to lose, and navigating away (e.g. via the **CRM**
  left-nav link) discards it silently with no prompt and creates nothing.
  Confirm navigation completed (URL actually changed) before clicking Save
  and Exit again, rather than clicking it repeatedly.

## Verified result (2026-10-08, release/26.4 against CymBuild_DEV264)

- **Defect observed: renaming in the same page session straight after the
  initial create does not save.** After the first Save of a new Account, the
  **Validate** button disappears, but editing **Name** re-arms "You must
  validate before you can save". **Save** then silently does nothing (no
  error, name not persisted after reload) and there is no Validate button to
  clear the gate.
- **Workaround / supported path:** reload the record (or reopen it from the
  grid), then edit Name and Save — this saved directly without a validate
  gate ("Record Saved Successfully"), matching the 2026-09-04 behaviour.
- Account `77430` renamed to `UITEST_Account_20261008_105123_Updated`; ID and
  `DataObjectGuid` unchanged; grid search returned exactly one row.

## Retest (2026-10-08, release/26.4 @ 8a4a6580)

- Fixed by #841: the duplicate-check gate only re-arms on unsaved new
  records. Account `77431` was renamed in the same page session straight
  after its first Save, and the new name persisted after reload.

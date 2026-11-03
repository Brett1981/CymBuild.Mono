---
workflow: find-and-open-account
last_verified: 2026-09-04
verification_status: verified
verified_against: local DEV (https://localhost:44368, API on https://localhost:7202, DB ShoreDB -> 10.100.34.114\general / CymBuild_DEV)
target_environment: local DEV only
depends_on: create-account
---

# Find And Open Account

## Purpose

Verify that a newly created Account can be found through the metadata-driven
Accounts grid and opened without changing it.

## Local run prerequisites

Start CymBuild using `.\tools\UI\Start-CymBuildLocal.ps1` and sign in through
the local PWA. Use only an Account created by `create-account.md`.

## Test-data contract

- `AccountName` is `UITEST_Account_<run-id>` or, after the update workflow,
  `UITEST_Account_<run-id>_Updated`.
- This is a read-only workflow. Do not click **Save**, change a field, delete,
  archive or transition the Account.

## Entry point

- Left nav: **CRM** → "Accounts (All)" grid at
  `/crm/00000000-0000-0000-0000-000000000000`. There is no separate
  "Accounts" nav item — see `create-account.md`.

## Steps

1. Click **CRM** in the left navigation.
2. Wait for the Accounts grid to complete its initial load.
3. Type the exact `AccountName` into the grid's **Search** box and click
   **Search**. The grid's Search box is a free-text search over the visible
   columns (confirmed: an exact `UITEST_...` string returns only the one
   matching row); there is no separate per-column exact filter.
4. Confirm exactly one active row is returned.
   1. If zero rows are returned, click **Clear**, reload once and repeat the
      exact search.
   2. If more than one row is returned, fail and report the visible
      identifiers rather than choosing a row arbitrarily.
5. Record the row's visible Account ID, Name, Status, Code (Sage), Main
   Contact and Main Address columns (these are the grid's actual columns).
6. **Double-click** the row to open it. A single click on the row or on the
   Name cell text does **not** navigate — this grid requires a double-click,
   unlike a hyperlinked Name cell.
7. Wait for the Account detail form to settle, then confirm:
   - the page is an `AccountDetail` page (header reads `Account :-
     <AccountName>`);
   - the **Name** field equals `AccountName`;
   - the **Account ID** field equals the value recorded when the Account was
     created (when available to the runner);
   - the URL's `DataObjectGuid` matches the value captured when the Account
     was created.
8. Leave the page by clicking **CRM** in the left nav (there is no separate
   Back/Close button on this form — only **Save**, **Save and Exit** and
   **Tasks**, all of which either save or are irrelevant here). Do not click
   **Save** or **Save and Exit**.

## Expected result

- The exact Account can be found from the grid.
- Only one active match exists.
- Opening the row retains the expected Name, Account ID and record GUID.
- No update or workflow transition is issued.

## Verified result (this run)

- Searched `UITEST_Account_20260904_114956` → exactly one row (Account ID
  `76815`, Status `Prospect`, Code (Sage)/Main Contact/Main Address blank).
- Double-clicked the row → opened `AccountDetail` at
  `DataObjectGuid` `7b5a151d-dae6-4aab-b287-166a5467f0fd` — matches the GUID
  from `create-account.md`'s run exactly. Name, Account ID and all other
  field values matched what was saved. Left via the **CRM** nav link without
  saving.

## Gotchas

- Grid rows open on **double-click**, not single click — a single click just
  focuses/selects, giving the appearance of nothing happening. Don't conclude
  the grid is broken from one click with no visible change.
- Grid filters may be server-side and can retain state between navigations.
  Clear any unrelated filters before judging the result.
- A stale toast from an earlier action is not evidence that this workflow made
  a change; this workflow must remain read-only.
- Do not depend on a fixed column position. Grid columns are metadata-driven
  and can be reordered or omitted.

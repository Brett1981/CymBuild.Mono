---
workflow: create-account
last_verified: 2026-10-08
verification_status: verified
verified_against: local DEV (https://localhost:44368, API on https://localhost:7202, DB ShoreDB -> 10.100.34.114\general / CymBuild_DEV264, release/26.4 @ c58053e9)
target_environment: local DEV only
---

# Create Account

## Local run prerequisites (not part of the workflow itself, but required to reach it)

Run `.\tools\UI\Start-CymBuildLocal.ps1` (the `cymbuild-run-local` skill). It
starts the API and PWA on the configured local ports and handles the fixed Azure
AD redirect URI used by local development. It also now builds the API before
starting the PWA build — building both at once races on the shared
`Concursus.Common.Shared` project's `obj\` output and can fail one of them with
`CSC : error CS2012 ... file may be locked by 'VBCSCompiler'`. If you hit that
error anyway (e.g. running the two `dotnet run` commands manually in parallel),
stop both, kill any leftover `dotnet`/`VBCSCompiler` MSBuild-node processes, and
restart API-then-PWA sequentially.

In the environment recorded by `create-asset.md`, the PWA is
`https://localhost:44368`, the API is `https://localhost:7202`, and the API
connects to the shared DEV database (`10.100.34.114\general` / `CymBuild_DEV`).
Confirm the startup script's output rather than assuming those values have not
changed.

## Test-data contract

- Generate a UTC run ID in `yyyyMMdd_HHmmss` form.
- Set `AccountName` to `UITEST_Account_<run-id>`.
- Before clicking **New**, exact-match search the Accounts grid for
  `AccountName`. If it already exists, open it and treat the workflow as a
  resumed run. Do not create a duplicate for the same run ID.
- Never modify an existing account that does not begin with `UITEST_`.

## Entry point

- There is **no top-level "Accounts" left-nav item.** The correct left-nav
  entry is **CRM**, which lands on the "Accounts (All)" grid.
- Route: `/crm/00000000-0000-0000-0000-000000000000` (the grid), landing tab
  is the account-book icon (first icon in the CRM sub-nav column).
- The grid has a free-text **Search** box (with **Search**/**Clear**/
  **Filters** controls) over columns Account ID, Name, Status, Code (Sage),
  Main Contact, Main Address — not a per-column exact filter. Search box
  content is matched against Name (confirmed: exact `UITEST_...` string
  returned exactly the one matching row and nothing else).
- Grid-level **New** button is top right of the grid panel.
- New-record route:
  `/AccountDetail/00000000-0000-0000-0000-000000000000/{"DataObjectGuid":"00000000-...","EntityTypeGuid":"40476ecc-d19a-4de9-90df-e1f45cd72fb2"}/{returnUrl}`
  — `40476ecc-d19a-4de9-90df-e1f45cd72fb2` is the Account `EntityTypeGuid`,
  confirmed directly in the observed route (matches the value derived from
  `SCrm.AccountsUpsert` schema evidence exactly).

## Steps

1. Click **CRM** in the left navigation and wait for the "Accounts (All)" grid
   to finish loading.
2. Type the exact `AccountName` into the grid's **Search** box and click
   **Search**.
   1. If exactly one row exists, open it (click the Account ID or Name cell)
      and continue at step 7.
   2. If more than one active row exists, fail with the matching names and
      visible identifiers. Do not create another.
   3. If no row exists, click **Clear** and continue.
3. Click the grid-level **New** button (top right). Opens
   `AccountDetail` on a blank form (Account ID `0`, all fields empty). Tabs on
   the detail page: **Account**, **Finance**, **Contracts**, **Related
   Records**. **Account Addresses** and **Account Contacts** sub-panels render
   directly on the **Account** tab, below the main field grid — not under
   Related Records.
4. Fill **Name** with `AccountName`. It is the only field with compulsory
   validation observed (`The value is compulsory` under the field until
   filled).
5. Preserve safe defaults on every other field:
   - Leave **Accounts Code (Sage)** blank. It is unique for active rows and
     may carry external accounting meaning.
   - **Account Status** defaults to `Prospect`. Leave it.
   - **Is Sales Ledger** under **Account Type** is **checked by default** on a
     new Account (the only one of the five Account Type checkboxes — Fire
     Authority, Local Authority, Water Authority, Purchase Ledger, Sales
     Ledger — that defaults on). Leave the legitimate default; do not uncheck
     it and do not check any of the others.
   - Do not select a Parent Account, Relationship Manager, Main Address or
     Main Contact.
   - If metadata makes another field required and it has no safe default, stop
     and record its label, options and validation message. Do not guess.
6. Click **Validate** (top of the **Account** panel, next to the header — not
   a page-level action). This is a required step: the page shows "You must
   validate before you can save" next to Save/Save and Exit until Validate has
   been run once, successfully.
   - Validate can surface a **"Possible Account Duplicates"** modal ("Please
     check whether this account already exists before saving"), with a
     dropdown of loosely-matched existing Account names (observed: it matched
     on a bare token like `UT`, returning unrelated `UTStarcom (n)` accounts
     for a `UITEST_Account_...` name — not a real duplicate). The modal's own
     instructional text says to click **"Not Present"** if nothing matches,
     but **the actual button is labelled "Cancel"**, not "Not Present" — this
     is a genuine UI label mismatch, not a hint to abort the whole save.
     Clicking **Cancel** here dismisses only the duplicate-check modal and
     proceeds (confirmed: the Account panel then shows a green **Validated**
     badge and Save/Save and Exit become enabled). Only pick a row and click
     **Use Selected** if it is genuinely the account you meant to reuse.
7. Click the form-level **Save** once.
8. Confirm all of the following:
   - the info banner **"Setting up SharePoint document structure and files.
     Please wait."** appears (an Account save also triggers SharePoint folder
     provisioning as a side effect, exactly like `create-asset.md`'s Asset
     save — not optional, don't be surprised by it);
   - the URL's `DataObjectGuid` changes from all-zeros to a real GUID;
   - the page header changes from `Account :-` to `Account :- <AccountName>`;
   - **Account ID** changes from `0` to an assigned integer.
9. Click **Save and Exit**. Returns to
   `/crm/00000000-0000-0000-0000-000000000000` (the Accounts grid).
10. On the Accounts grid, type the exact `AccountName` into **Search** and
    click **Search**. Confirm exactly one active row and record its visible
    columns.

## Expected result

- Exactly one Account row is visible for `AccountName`.
- The saved detail page has a non-zero `DataObjectGuid`.
- No sensitive ledger, authority, hold or external-account code was introduced
  by the workflow (beyond the legitimate `Is Sales Ledger` default).
- A retry with the same run ID opens the existing Account and does not add a
  second row.

## Fields intentionally left unchanged

The supplied Account persistence contract includes Code, Account Status,
Parent Account, ledger/authority flags, Relationship Manager, Company
Registration Number, Main Address, Main Contact and Billing Instruction. Of
these, only **Account Status** (`Prospect`) and **Is Sales Ledger** (checked)
carry a live default; every other field renders empty on a new record.

## Verified result (this run)

- Account ID `76815`, Name `UITEST_Account_20260904_114956`,
  `DataObjectGuid` `7b5a151d-dae6-4aab-b287-166a5467f0fd`,
  `EntityTypeGuid` `40476ecc-d19a-4de9-90df-e1f45cd72fb2`, Status `Prospect`.
- Confirmed only via the UI (grid row, header, Account ID, SharePoint-setup
  banner) — did not independently query `SCore.DataObjects` to verify the
  row/EntityTypeId directly.

## Gotchas

- CymBuild is metadata-rendered. A field area can exist semantically before it
  appears stable in a screenshot; wait and read the page structure.
- The left nav has no "Accounts" item — it's under **CRM**. Don't assume a
  nav label matches the entity name.
- **Validate** is a required, separate step before Save is enabled — it is not
  automatic on Save, and it can pop the "Possible Account Duplicates" modal
  even for a clearly-unique `UITEST_` name (loose token matching produced
  false positives here). The modal's "Not Present" instruction maps to the
  **Cancel** button, not a literally-labelled one.
- Do not confuse an Account's business Account Status with permission to alter
  workflow state. This test accepts a legitimate form default and does not
  perform a separate status transition.
- The DEV database is shared even though the PWA/API are local. The `UITEST_`
  marker and idempotent resume rule are mandatory.

## Verified result (2026-10-08, release/26.4 against CymBuild_DEV264)

- Account ID `77430`, Name `UITEST_Account_20261008_105123`,
  `DataObjectGuid` `61db0cb8-3100-461c-80a9-e73cad1e1041`, Status `Prospect`.
- **Duplicate modal changed:** for a unique name, **Validate** now shows
  "No potential duplicates found" with a single green **Continue** button
  (no dropdown, no Cancel). Click **Continue** to proceed.
- SharePoint banner on save, then "SharePoint document structure and files
  created successfully" once provisioning finished.
- Pressing **Tab** out of **Name** moves focus into the **Account Status**
  combobox and opens its dropdown (the field shows the placeholder while
  open). Press Escape / click elsewhere; status stays `Prospect`. Prefer
  clicking a blank area to blur Name rather than Tab.
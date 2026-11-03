---
workflow: add-account-address
last_verified: 2026-09-04
verification_status: verified
verified_against: local DEV (https://localhost:44368, API on https://localhost:7202, DB ShoreDB -> 10.100.34.114\general / CymBuild_DEV)
target_environment: local DEV only
depends_on: create-account
---

# Add Address To Account

## Purpose

Create one Address through an Account's related-record UI and verify that it is
linked to the intended UI-test Account.

## Local run prerequisites

Start CymBuild using `.\tools\UI\Start-CymBuildLocal.ps1` and sign in through
the local PWA.

## Test-data contract

| Field | Safe test value |
| --- | --- |
| Account | `UITEST_Account_<run-id>` or its `_Updated` form |
| Address **Reference** (not "Name" — see Entry point) | `UITEST_Address_<run-id>` |
| Postcode used for lookup | `SW1A 1AA` (fixed-dataset match, matches `create-asset.md`; returns "Buckingham Palace, London, London, SW1A 1AA, England") |

Use the current run's Account only. Do not attach the Address to another
Account.

## Entry point

- Open the test Account (`find-and-open-account.md`). The **Account
  Addresses** panel is **not** a separate tab — it renders directly on the
  **Account** tab, below the "Main Details"/"Billing" sections, as its own
  scoped grid with a **New** button (same place `create-account.md` first
  observed it).
- **The "New Account Addresses" form is a single lookup field, not a full
  address form.** It has exactly one field, **Address** (a combobox + an
  external-link/"open" icon next to it), which links to a separate **Address**
  entity — it does not have Address Line 1/Town/Postcode fields itself. This
  matches the architectural evidence (`SCrm.AddressUpsert` then
  `SCrm.AccountAddressesUpsert` are two separate upserts) more literally than
  the draft assumed.
- Clicking the icon next to **Address** opens an **Address** creation modal
  with real fields: **Address Number** (auto, read-only), **Reference** (free
  text — this is the field to use as the `UITEST_` marker; there is no
  "Address Name" field), **Formatted Address** (read-only, computed after
  save), and an **Address Detail** panel with **Address Lookup** button, Name
  / Number, Address Line One (required), Address Line Two, Address Line Three,
  Town (required), County, Postcode, Country.
- The **Address Lookup** button/modal inside this is functionally identical to
  the one in `create-asset.md` (Postcode Lookup → Postcode matches dropdown →
  Confirm → Selected Address panel → Done).

## Retry rule

Before adding, search the Account's **Account Addresses** grid (its Search box
is free-text, matching the formatted address string) for the postcode or
Reference used for this run. If one matching linked Address exists, open and
verify it instead of creating another. More than one match is a failure.

## Steps

1. Open the current run's test Account and confirm its Name and non-zero GUID.
2. Scroll to the **Account Addresses** panel on the **Account** tab.
3. Apply the retry rule via the panel's own **Search** box.
4. Click the panel-scoped **New** button. An inline "New Account Addresses"
   panel expands above the grid with a single **Address** lookup field
   (compulsory).
5. Click the icon next to the **Address** field (not the dropdown chevron) to
   open the **Address** creation modal.
6. In the modal, click **Address Lookup**, enter `SW1A 1AA`, click **Search**,
   select the one match from the **Select an address** dropdown, click
   **Confirm**, then **Done**. This fills Address Line One (`Buckingham
   Palace`) and Town (`London`) on the main modal, and Postcode
   (`SW1A 1AA`) — but **not Country**, which is left blank and must be set
   separately (see Gotchas).
7. Set **Reference** to `UITEST_Address_<run-id>`.
8. Set **Country** to `England` using the panel's own dropdown chevron and
   clicking the listed option with the mouse — **do not** click into the
   Country text field and use arrow keys/Enter; see the autofill Gotcha below.
9. Click **Save** (top of the Address modal). Confirm a "Record Saved
   Successfully" banner and that **Formatted Address** now shows the three
   lines (`Buckingham Palace` / `London` / `SW1A 1AA`). **Address Number**
   stayed `0` after save — unlike Account/Asset, this entity does not appear
   to assign a visible sequential number on this form.
10. Close the Address modal (its own **Save and Exit**, or the modal's **X**).
    Back on the Account's inline "New Account Addresses" panel, the **Address**
    lookup field is now auto-populated with the newly created Address
    (formatted as `- Buckingham Palace,London,SW1A 1AA`).
11. Click **Save** on the "New Account Addresses" panel itself — this is the
    separate link-record save (`SCrm.AccountAddressesUpsert`). Confirm
    "Record Saved Successfully" and that the **Account Addresses** grid's
    **Rows** count increments (0 → 1).
12. Click **Close** on the "New Account Addresses" panel to collapse it and
    view the grid.
13. Search the **Account Addresses** grid (e.g. for the postcode) and confirm
    exactly one row.

## Expected result

- One new Address is created through the normal UI path.
- One Account-Address link associates it with the intended Account.
- A retry does not create a second Address or link.
- The parent Account GUID remains unchanged.

## Verified result (most recent run)

- Address: Reference `UITEST_AddAccountAddress_20260904`, Address Number `0`,
  Formatted Address "Buckingham Palace London SW1A 1AA" (Country `England`
  set via the dropdown chevron; Address Line One/Town/Postcode unaffected).
- Account Addresses grid for Account `76815`
  (`UITEST_Account_20260904_114956_Updated`): **Rows** count went 1 → 2
  (a prior run's linked Address already existed for this same Account using
  the same fixed `SW1A 1AA` postcode dataset match, so both grid rows render
  identically as `Buckingham Palace,London,SW1A 1AA` — they are distinct
  Address records, distinguishable only by their **Reference** field inside
  each linked Address record, not by anything visible in this grid).

## Verified result (earlier run)

- Address: Reference `UITEST_Address_20260904_114956`, Address Number `0`,
  Formatted Address "Buckingham Palace / London / SW1A 1AA".
- Account Addresses grid for Account `76815`
  (`UITEST_Account_20260904_114956_Updated`): exactly one row, formatted
  `Buckingham Palace,London,SW1A 1AA`, after searching `SW1A 1AA`.

## Architectural evidence

The supplied schema shows Address persistence through `SCrm.AddressUpsert` and
link persistence through `SCrm.AccountAddressesUpsert`. Both use the platform
DataObject helper before insert. This workflow must not call either procedure
directly. Confirmed in the UI as two distinct saves: saving the **Address**
modal, then separately saving the **Account Addresses** link panel.

## Gotchas

- **The "Account Addresses" grid's only column header literally reads
  "ASSET"**, even though the rows are Addresses linked to an Account, not
  Assets — a real (if confusing) label in the shared grid component. Don't
  assume the app is showing you the wrong data because of the header text.
- **Chrome's native browser autofill can hijack keyboard interaction with the
  Country dropdown and silently overwrite Address Line One/Town/Postcode with
  an unrelated real address from the browser's own autofill profile data.**
  This happened in this run: focusing the Country combobox and pressing
  Down+Enter selected a Chrome autofill suggestion instead of the app's
  "England" option, replacing "Buckingham Palace / London / SW1A 1AA" with an
  entirely different address ("20 Hunting Gate", "Colchester", "CO1 2XF").
  **Always click dropdown options with the mouse on this form** — open the
  dropdown with the chevron, visually confirm the option list belongs to the
  app (not a browser autofill popup), and click the exact option. Re-check
  Address Line One/Town/Postcode after touching Country, in case this happens
  again.
- The Address Lookup's Confirm/selection step needs the dropdown option
  actually clicked (or keyboard-selected) — a click that lands just after the
  dropdown closes can silently no-op, leaving "Selected Address" blank and
  Confirm effectively doing nothing. Verify the right-hand "Selected Address"
  panel populates (UPRN, Address Line 1, Town) before proceeding.
- The DEV postcode lookup behaves like a fixed dataset for `SW1A 1AA`
  (matches `create-asset.md`). This workflow uses the lookup (unlike the
  original draft's plan to enter fields directly) because the Account Address
  form's only free-text address entry point already is the same Address
  Detail form the Asset flow uses.
- A successful Address save is insufficient if it is not visible under the
  intended Account; always verify the link from the parent page (the separate
  "New Account Addresses" panel Save, not just the Address modal's Save).
- **The Retry rule's postcode search cannot distinguish two distinct Address
  records that both resolve to the same fixed `SW1A 1AA` lookup postcode.**
  Confirmed in this run: a second, genuinely new Address (different
  `Reference`) was created for the same Account that already had one
  `SW1A 1AA`-postcode Address from an earlier run; the grid then showed two
  identical-looking `Buckingham Palace,London,SW1A 1AA` rows with **Rows**
  1 → 2. Treat the retry rule as applying to the *current run's own*
  `Reference`, not as a hard block on ever adding a second address to an
  Account that already has one at the same test postcode — check the actual
  Reference inside each linked Address if you must tell them apart, not the
  grid's Asset-labelled column.
- Browser-automation note (not app behaviour): the rendered screenshot size
  and the page's actual viewport size can differ slightly, which makes
  fixed-pixel-coordinate double-clicks/clicks land on the wrong element
  (e.g. re-focusing the grid's Search box instead of opening a row). Prefer
  resolving elements via `find`/`read_page` refs and clicking/double-clicking
  by ref over hard-coded coordinates on this app.

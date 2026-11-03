---
workflow: create-asset
last_verified: 2026-09-04
verified_against: local DEV (https://localhost:44368, API on https://localhost:7202, DB ShoreDB -> 10.100.34.114\general / CymBuild_DEV)
---

# Create Asset

## Local run prerequisites (not part of the workflow itself, but required to reach it)

Run `.\tools\UI\Start-CymBuildLocal.ps1` (the `cymbuild-run-local` skill) —
it starts the API and PWA on the exact ports the app needs and is
idempotent. See that skill for why (Azure AD redirect-URI port requirement)
and for sign-in notes (corporate SSO).

Note: even "local DEV" points the API at the real shared DEV SQL Server
(`10.100.34.114\general`, catalog `CymBuild_DEV`) — the PWA/API processes are
local, the database is not.

## Entry point

- Left nav: **Assets** (`href="structures/00000000-0000-0000-0000-000000000000"`)
  → grid at `/structures/{guid}`, "Assets" grid, entity type Structure.
- **New** button on the grid → `/StructureDetail/00000000-.../{"DataObjectGuid":"00000000-...","EntityTypeGuid":"2cfbff39-93cd-436b-b8ca-b2fcf7609707"}/...`
  — `2cfbff39-93cd-436b-b8ca-b2fcf7609707` is the Asset/Structure `EntityTypeGuid`,
  observed directly in the route, not assumed.

## Steps

1. Click **Assets** in the left nav.
2. Click **New** (top right of the Assets grid). Opens a blank `StructureDetail`
   form (Asset / Related Records / Child Assets tabs). The rendered field
   region can be visually blank immediately after navigation even though the
   fields exist in the DOM (confirmed via `read_page`) — don't conclude the
   form is broken from a screenshot alone; read the page or wait/rescroll.
3. Fill **Reference** (free text) — this is the field the earlier manual run
   used for its `Claude Demo - safe to delete` marker. Use the `UITEST_`
   prefix here for automated runs (e.g. `UITEST_CreateAsset_20260904`).
4. Click **Address Lookup** (next to the "Address Detail" section header) —
   opens an "Address Lookup" modal, separate from the main form.
   1. Enter a postcode in the modal's own **Enter Postcode** field (the
      background form's Postcode field is NOT shared with this modal) and
      click **Search**.
   2. Pick a result from the **Select an address** dropdown that appears
      (dev environment's lookup service only returned one match for
      `SW1A 1AA`: "Buckingham Palace, London, London, SW1A 1AA, England").
   3. Click **Confirm** — populates the modal's read-only "Selected Address"
      panel (UPRN, Local Authority, Address Line 1, Town, Postcode, Country).
   4. Click **Done** — copies the resolved address onto the main form
      (Address Line 1, Address Line 3 [= the lookup's "Local Authority"
      value, e.g. "St James's" — NOT the Authorities-section Local Authority
      field, which is a separate lookup/combobox left blank in this run],
      Town, Postcode, Country) and repositions the map pin.
5. Click **Save** (top right). On success: a green banner reads *"Success:
   SharePoint document structure and files created successfully"* (creating
   an Asset triggers SharePoint folder provisioning as a side effect — not
   optional, don't be surprised by it), the URL's `DataObjectGuid` changes
   from all-zeros to a real GUID, and the page header shows the assigned
   **Asset Number**.
6. Click **Save and Exit** to return to the Assets grid. The new row appears
   at the top (grid default-sorts by Asset # descending) with the Reference
   and address text just entered.

## Fields that were NOT required to save

Left blank and saved without error: Government UPRN, Parent Asset, Owner
Account, Name/Number, Address Line 2, County, Local/Fire/Water Authority
(Authorities section), Building Height In Metres (defaults to `0`), Is High
Risk/Complex Building checkboxes. Don't assume this means they're never
required — only that they weren't for this run's data; a metadata/validation
change could add requirements later.

## Test-data markers used

- `Reference` = `UITEST_CreateAsset_<run-id>` (this run: `UITEST_CreateAsset_20260904`).

## Verified result (this run)

- Asset # 36195, Reference `UITEST_CreateAsset_20260904`,
  `DataObjectGuid` `7591ce92-9908-4298-adf0-d8647917a800`,
  `EntityTypeGuid` `2cfbff39-93cd-436b-b8ca-b2fcf7609707`.
- Confirmed only via the UI (grid row, success banner, header Asset Number) —
  did not independently query `SCore.DataObjects` to verify the row/EntityTypeId
  directly.

## Gotchas

- Don't confuse the two "Local Authority" values: the Address Lookup modal's
  result and the Authorities-section combobox are different fields that
  happen to share a label.
- The postcode/address lookup service used in this DEV environment appears to
  be a fixed/stub dataset (only ever returned the one "Buckingham Palace"
  match for `SW1A 1AA`) rather than a live GB postcode database — don't
  assume arbitrary postcodes will resolve.
- If sign-in redirects to Microsoft with `AADSTS50011`, the PWA is bound to
  the wrong port — see "Local run prerequisites" above.

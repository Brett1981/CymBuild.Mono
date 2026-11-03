---
workflow_pack: account-basics
verification_status: verified
source_checked: 2026-09-04
last_verified: 2026-09-04
verified_against: local DEV (https://localhost:44368, API on https://localhost:7202, DB ShoreDB -> 10.100.34.114\general / CymBuild_DEV)
source_basis: create-asset.md and supplied CymBuild SQL schema snapshot, then a full live browser run of all 5 workflows in order
target_environment: local DEV only
---

# CymBuild Account UI Workflows

This pack adds small, composable browser workflows for the Account area. They
follow the style of `create-asset.md`. All five workflows below have now been
run end-to-end through the local PWA in dependency order and are marked
**verified** in their own front matter — each file's "Verified result" section
records what was actually observed (routes, labels, GUIDs, success messages),
superseding the schema-only assumptions this pack started from. Several of
those assumptions turned out wrong; see each file's "Gotchas" section, and the
summary below.

If a future run hits a page/field/button that doesn't match a file, the flow
has drifted — re-verify live, update the file, and don't silently patch around
the mismatch (per `README.md`'s cache-staleness rule).

## What the live run corrected vs. the original schema-only draft

- There is no top-level "Accounts" nav item — it's under **CRM**
  (`create-account.md`).
- Grid rows open on **double-click**, not a single click on a "Name" link
  (`find-and-open-account.md`).
- **Validate** is a separate required step before Save, and can pop a
  "Possible Account Duplicates" modal whose instructional text says click
  "Not Present" but whose actual button is labelled **Cancel**
  (`create-account.md`).
- **Account Addresses** and **Account Contacts** are not full inline forms —
  each is a two-field link panel (a lookup to a separate Address/Contact
  entity, created via an "open" icon that pops a real create-modal) rendered
  directly on the **Account** tab, not under a "Related Records" tab, and not
  with the field sets originally assumed (`add-account-address.md`,
  `add-account-contact.md`).
- Chrome's native autofill can hijack keyboard interaction with a dropdown
  and silently overwrite address fields with unrelated real data — always
  click dropdown options with the mouse and re-check nearby fields
  (`add-account-address.md`).
- The Contact's actually-compulsory field is **Display Name**, not First
  Name/Surname, and its **Primary Account** lookup could not find the
  just-created test Account by name in this run — left blank; the real
  Account↔Contact link is made by the outer panel's own Save
  (`add-account-contact.md`).

## Recommended execution order

1. [create-account.md](create-account.md)
2. [find-and-open-account.md](find-and-open-account.md)
3. [update-account-name.md](update-account-name.md)
4. [add-account-address.md](add-account-address.md)
5. [add-account-contact.md](add-account-contact.md)

The first workflow creates the parent record. Every later workflow operates
only on a record whose name begins with `UITEST_`.

## Shared run data

Generate one run ID at the start of the run, preferably UTC in
`yyyyMMdd_HHmmss` form. Reuse it across the pack.

| Item | Value |
| --- | --- |
| Account | `UITEST_Account_<run-id>` |
| Updated account | `UITEST_Account_<run-id>_Updated` |
| Address name | `UITEST_Address_<run-id>` |
| Contact marker | `UITEST_Contact_<run-id>` |

Use a fresh run ID for parallel or repeated test runs. If the exact marker
already exists, resume that record rather than creating another one.

## Safety rules

- Run these workflows only against local DEV. In the current local setup the
  PWA and API are local, but the database is shared `CymBuild_DEV`.
- Operate through the PWA only. The browser workflow must not call gRPC, SQL,
  stored procedures or repository endpoints directly.
- Never edit, archive or delete a record unless its identifying value begins
  with `UITEST_` and belongs to the current run.
- Do not assign a Sage/account code, ledger flags, authority flags, credit-hold
  state or another business-sensitive value merely to make a test pass.
- Do not automate cleanup through SQL. Retain the test marker for controlled
  UI cleanup or a separately approved cleanup workflow.
- After a save, reuse the non-zero record GUID already returned by CymBuild.
  A retry must not return to the grid and click **New** again.

## CymBuild boundary covered

The browser action must remain on the normal production path:

`Blazor PWA -> FormHelper -> gRPC API -> EF/repository -> SQL Server`

The supplied schema shows these persistence contracts behind the UI:

| Workflow | Persistence contract evidenced by supplied schema |
| --- | --- |
| Create/update Account | `SCrm.AccountsUpsert` |
| Add Address | `SCrm.AddressUpsert` then `SCrm.AccountAddressesUpsert` |
| Add Contact | `SCrm.ContactUpsert` then `SCrm.AccountContactsUpsert` |

Each upsert invokes the platform DataObject helper before inserting the entity
or link. That is architectural evidence, not permission for the UI workflow to
call those procedures. DataObject integrity should be covered by a separate
API/SQL integration test; this UI pack verifies only user-observable behaviour.

The Account entity type GUID is `40476ecc-d19a-4de9-90df-e1f45cd72fb2` in the
supplied `SCrm.AccountsUpsert` source. This has now been confirmed directly in
the observed `AccountDetail` route during live verification — it matches the
schema evidence exactly (see `create-account.md`'s "Verified result").

## Dynamic UI guidance

- Prefer accessible roles and visible labels over generated element IDs or CSS
  positions.
- After navigation, wait for the page to settle and use `read_page` (or the
  equivalent semantic page read) before concluding that a metadata-rendered
  field is missing.
- Scope **New**, **Add**, **Save** and **Save and Exit** to the current grid,
  tab, section or form. CymBuild pages can expose several buttons with the same
  text.
- Treat a non-zero `DataObjectGuid`, a stable detail page and the expected grid
  row as stronger success evidence than a transient toast alone.
- If a required field has no safe existing default, stop and record the field,
  available options and validation message. Do not guess a business value.

## First-verification checklist (completed 2026-09-04)

Each workflow file now records, from the live run:

- `last_verified` and `verified_against` in the front matter;
- the exact left-navigation text and route;
- the exact new/edit detail route and observed `EntityTypeGuid`;
- required fields and their safe test values;
- the exact success banner or toast;
- the returned `DataObjectGuid`/IDs and visible result from that run;
- metadata-rendering, lookup, autofill and retry gotchas actually hit.

A future re-run that hits a mismatch should update the specific file rather
than reintroducing draft/assumed content across the pack.

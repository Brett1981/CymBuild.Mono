---
workflow: add-account-contact
last_verified: 2026-10-08
verification_status: verified
verified_against: local DEV (https://localhost:44368, API on https://localhost:7202, DB ShoreDB -> 10.100.34.114\general / CymBuild_DEV264, release/26.4 @ c58053e9)
target_environment: local DEV only
depends_on: create-account
optional_dependency: add-account-address
---

# Add Contact To Account

## Purpose

Create one Contact through an Account's related-record UI and verify that it is
linked to the intended UI-test Account.

## Local run prerequisites

Start CymBuild using `.\tools\UI\Start-CymBuildLocal.ps1` and sign in through
the local PWA.

## Test-data contract

| Field | Safe test value |
| --- | --- |
| Account | `UITEST_Account_<run-id>` or its `_Updated` form |
| **Display Name** (the actual compulsory field — see Entry point) | `UITEST_Contact_<run-id>` |
| First Name | `UITEST` |
| Surname | `Contact_<run-id>` |
| Primary Account | Left blank — see Gotchas (the lookup could not find the test Account by name, and its "create" icon opens a **new** blank Account, not a search) |

Do not add an email address, telephone number, title, position or post-nominals
in this basic workflow. Those are separate behaviours and should have their own
workflow once the base Contact flow is verified.

## Entry point

- Open the test Account (`find-and-open-account.md`). The **Account Contacts**
  panel is **not** a separate tab — it renders directly on the **Account**
  tab, below **Account Addresses** (same place noted in
  `add-account-address.md`), as its own scoped grid (columns: Name, Position,
  Email, Mobile, Office) with a **New** button.
- **The "New Account Contacts" form is a link record with exactly two fields:
  Contact** (a compulsory lookup + external-link/"open" icon) **and Primary
  Address** (optional lookup) — there are no inline First
  Name/Surname/Display Name fields on this panel itself. Contact is its own
  entity, linked the same way Address is in `add-account-address.md`.
- Clicking the icon next to **Contact** opens a **Contact** creation modal
  with tabs **Contact** / **History**, and three panels: **Contact**
  (**Display Name** — compulsory — and an **Is Person** checkbox, unchecked
  by default), **Personal Details** (Title, First Name, Surname, Initials,
  Post Nominals — all optional), and **Relationships** (Position, **Primary
  Account**, **Primary Address** — all optional lookups). **Primary Account
  is not prefilled with the current Account**, unlike what the draft assumed.

## Retry rule

Before adding, exact-match search the Account's **Account Contacts** region
(its Search box, free-text over the grid) for `UITEST_Contact_<run-id>`. If
one linked Contact exists, open and verify it instead of creating another.
More than one match is a failure.

## Steps

1. Open the current run's test Account and confirm its Name and non-zero GUID.
2. Scroll to the **Account Contacts** panel on the **Account** tab.
3. Apply the retry rule via the panel's own **Search** box.
4. Click the panel-scoped **New** button. An inline "New Account Contacts"
   panel expands with **Contact** (compulsory) and **Primary Address**
   (optional) lookup fields.
5. Click the icon next to **Contact** (not the dropdown chevron) to open the
   **Contact** creation modal.
6. Set **Display Name** to `UITEST_Contact_<run-id>` — this is the field
   CymBuild actually requires (`The value is compulsory` appears under it
   until filled), not First Name/Surname.
7. Set **First Name** to `UITEST` and **Surname** to `Contact_<run-id>`
   (optional but kept for readability/consistency with other test data).
8. Leave **Primary Account** blank. Typing the Account's name (both the full
   name and a shorter `UITEST` prefix) into it returned **"No matching
   records"** in this run — the lookup did not find the just-created Account.
   The icon next to it does **not** open a search/picker; it opens a blank
   **new**-record Account form (Account ID `0`), i.e. it is a "create a new
   linked record" affordance, not "select an existing one". **Do not use it**
   — close it (its own **X**) without touching or saving anything, or you
   will create a stray Account. The actual Account↔Contact link is
   established later by the outer "Account Contact" panel's own Save (step
   11), not by this field.
9. Preserve safe defaults on Title, Position, Initials, Post Nominals,
   **Is Person** (left unchecked) and Primary Address. If another field
   becomes required with no safe default, stop and record its label, options
   and validation message.
10. Click the Contact modal's **Save** once. Confirm a "Record Saved
    Successfully" banner and the header changes to `Contact :-
    <DisplayName>`. No "similar contact" duplicate-check modal appeared in
    this run (unlike the Account flow's "Possible Account Duplicates" modal) —
    if one does appear on a future run, treat it the same way: read the
    actual button labels rather than assuming they match the modal's
    instructional text (see `create-account.md`'s "Cancel" vs "Not Present"
    gotcha).
11. Close the Contact modal (**Save and Exit**, or its **X**). Back on the
    Account's inline "New Account Contacts" panel, the **Contact** lookup
    field is now auto-populated with the newly created Contact's Display
    Name.
12. Click **Save** on the "New Account Contacts" panel itself — this is the
    separate link-record save (`SCrm.AccountContactsUpsert`). Confirm "Record
    Saved Successfully" and that the **Account Contacts** grid below updates
    (Rows 0 → 1, one row showing the Contact's Display Name under **NAME**).
13. Click **Close** on the "New Account Contacts" panel and confirm the grid
    shows exactly one row for the Display Name.

## Expected result

- One Contact is created through the normal UI path.
- One Account-Contact link associates it with the intended Account.
- A retry does not create a second Contact or link.
- No contact-detail child record is created by this basic workflow.
- No stray Account is created via the Primary Account field's "create" icon.

## Architectural evidence

The supplied schema shows Contact persistence through `SCrm.ContactUpsert` and
link persistence through `SCrm.AccountContactsUpsert`. Both use the platform
DataObject helper before insert. This workflow must not call either procedure
directly. Confirmed in the UI as two distinct saves: saving the **Contact**
modal, then separately saving the **Account Contacts** link panel — the same
two-save pattern as `add-account-address.md`.

## Verified result (this run)

- Contact: Display Name `UITEST_Contact_20260904_114956`, First Name
  `UITEST`, Surname `Contact_20260904_114956`, Primary Account left blank.
- Account Contacts grid for Account `76815`
  (`UITEST_Account_20260904_114956_Updated`): exactly one row, Name
  `UITEST_Contact_20260904_114956`, Position/Email/Mobile/Office blank.

## Verified result (re-run, same day)

- Reused the same Account `76815` (`UITEST_Account_20260904_114956_Updated`)
  as the parent instead of creating a fresh one — the retry rule's exact
  search still applies per new Contact Display Name, and a different
  `UITEST_...` name is not a duplicate of an existing different-named
  Contact.
- Retry-rule search for `UITEST_AddAccountContact_20260904` in the Account
  Contacts panel returned "No records found" before creating, confirming no
  prior duplicate.
- Contact: Display Name `UITEST_AddAccountContact_20260904`, First Name
  `UITEST`, Surname `AddAccountContact_20260904`, Primary Account left blank,
  Is Person left unchecked. Saved successfully ("Record Saved Successfully"),
  header changed to `Contact :- UITEST_AddAccountContact_20260904`. No
  duplicate-contact modal appeared.
- Account Contacts grid for Account `76815`: went from 0 to 1 matching row
  after the link-record Save, showing `UITEST_AddAccountContact_20260904`
  under NAME with Position/Email/Mobile/Office blank.

## Gotchas (additional, this re-run)

- Coordinate-based clicks (`computer` tool with raw `[x,y]`) repeatedly
  missed the intended element on this page — clicks landed on the wrong
  grid/panel (e.g. hit the CRM icon-strip's "Addresses" tab instead of an
  Accounts grid row, or appeared to do nothing when the target was actually
  a Save/New/Close button). This reproduced consistently across the
  Accounts grid, the Account Contacts panel's New button, and the Contact
  modal's Save/Close buttons. **Workaround that worked reliably: use `find`
  to get the element's `ref`, then click by `ref`** (via the `computer`
  tool's `ref` parameter, or `form_input` for field values) instead of
  computing pixel coordinates from a screenshot. Likely cause is a
  scale/DPI mismatch between the screenshot image and the actual viewport
  (screenshot 1568px wide vs a reported 1493px viewport).
- On first load, the app showed a release-notes dialog and a stray
  "An unhandled error has occurred" toast with Reload/Close links
  overlaying the page. Closing the error toast was necessary before normal
  clicks on the Accounts grid started landing correctly — check for and
  dismiss these before driving the grid.
- The Contact-creation modal, once opened via the Contact field's icon, can
  render scrolled to a lower tab/section (e.g. "Contact Details") rather
  than the top "Contact" tab with Display Name — scroll the modal itself
  up, or better, use `find`/`read_page` to get a direct ref to the Display
  Name field rather than assuming scroll position.

## Gotchas

- A Contact and an AccountContact link are distinct entities (two separate
  Save actions). Confirm the Contact appears under the intended parent
  Account's grid, not merely that the Contact modal itself saved.
- **The Contact modal's "Primary Account" lookup did not find the just-saved
  test Account by typed name (full name or a shorter prefix both returned "No
  matching records"), and the field's adjacent icon creates a new blank
  Account rather than searching existing ones.** Leave Primary Account blank
  in this basic workflow and rely on the Account's own "Account Contacts"
  panel to make the link — do not fight this field or click its create icon.
- Display Name is the actually-compulsory field on Contact, not First
  Name/Surname as the original draft assumed; First Name/Surname/Initials/
  Post Nominals/Title are all optional free text with no calculation observed
  (Display Name did not auto-derive from First Name/Surname in this run).
- Similar-contact/duplicate warnings did not appear for this Display Name in
  this run. If one appears in a later run, verify the actual button label
  before acting on it (see the Account "Cancel" vs "Not Present" gotcha) —
  never select an existing non-`UITEST_` Contact to bypass it.

## Verified result (2026-10-08, release/26.4 against CymBuild_DEV264)

- **Contact modal now has a Validate step** (new since 2026-09-04): a
  **Validate** button in the Contact panel and "You must validate before you
  can save" under Save. Validate pops "Possible Contact Duplicates"; for a
  unique name it shows "No potential duplicates found" with **Continue**.
- Changing a duplicate-check field (Display Name, First Name, Surname,
  Initials) after validating re-arms the gate; the Validate button stays
  available on this modal, so just validate again. Since #841 this only
  applies before the Contact's first Save; editing a saved Contact does not
  re-arm it (not retested on the Contact modal).
- Automation note: one typed value (First Name) was dropped when typing
  immediately after clicking the field; wait ~1s after focusing before
  typing, and re-check field values before Validate.
- Contact `UITEST_Contact_20261008_105123` (First Name `UITEST`, Surname
  `Contact_20261008_105123`) linked to Account `77430`; Account Contacts grid
  went 0 → 1 row.
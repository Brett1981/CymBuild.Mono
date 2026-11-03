---
workflow: create-enquiry-quote-revision
last_verified: 2026-10-08
verification_status: verified
verified_against: local DEV (https://localhost:44368, API on https://localhost:7202, DB ShoreDB -> 10.100.34.114\general / CymBuild_DEV264, release/26.4 @ c58053e9)
target_environment: local DEV only
depends_on: create-account, add-account-contact
---

# Create Enquiry -> Quote -> Quote Revision

## Purpose

Exercise the Enquiry -> Quote path and quote revisions end to end on UITEST
data. Covers CYB-569 (enquiry "New" status/next statuses), CYB-554 (quote
number shows on the enquiry without refresh), CYB-320 (copy quote items on
revision prompt), CYB-321 (editable fields on a revision) and CYB-279
(drawdown frequency).

## Test-data contract

- Client: the run's `UITEST_Account_<run-id>` Account. **It must be Account
  Status `Active`** — the Enquiry/Quote Client lookup (DropDownListDefinition
  17, `CrmAccounts`) excludes `Prospect` accounts by design. Change the status
  on the test Account first (Account form -> Account Status -> Active -> Save).
- Description of Works: `UITEST_Enquiry_<run-id> ...`.
- Quote item Details: `UITEST_QuoteItem_<run-id>`; schedule Name:
  `UITEST_Drawdown_<run-id>`.

## Steps

1. **Enquiries** -> grid **New**. The form takes ~10s to load. Fields are on
   the **Enquiry Details** tab (scroll down); **Project Details** is
   save-first.
2. Fill **Description of Works**; in **Client Details** type the account name
   into **Client** and pick it. Lead Organisational Unit defaults to
   `Building and Real Estate` (default/parent workflow — the CYB-569 case).
3. Click form **Save**. SharePoint provisioning banner appears; Record Status
   shows `N/A -> New` with comment `System Imported.` and a blank Created By
   User (observed for both Enquiry and Quote creation).
4. **Enquiry Services** -> **New** -> pick **Job Type** (e.g.
   `BRAC - Feasibility Study`) -> panel **Save** -> **Close**. Row shows
   Quote `0`, Status `No Quote`.
5. **Record Status** -> **New** -> **New Status** dropdown should list
   `Declined To Quote`, `Ready for Quote`, `Withdrawn` (CYB-569 pass
   condition) -> choose `Ready for Quote`, enter a `UITEST` comment -> Save.
6. **Value Of Work must be > 0** before quote creation. With 0 at
   `Ready for Quote`, Tasks -> **Create Quote(s)** is disabled; its tooltip
   reads "Save the record before running this task." (misleading - the
   blocker is Value Of Work). At status `New` the action runs and returns the
   raw server error "Value of work must be set!". Before #842 it silently did
   nothing. Set it (e.g. 1000) and **Save**.
7. Tasks -> **Create Quote(s) from enquiry**. Toast "Quote has been
   Successfully Created"; the Enquiry Services row immediately shows the new
   quote number and `Quoting` without a refresh (CYB-554 pass condition).
8. Open the quote from the **Quoting** grid (search the description).
   Double-clicking the quote number in Enquiry Services opens the service edit
   panel instead.
9. **Quote Items** -> **New** (form takes ~5s to render fields) -> Details,
   Product, Provide At Stage, Net -> **Save**.
10. Tasks -> **Revise Quote**. "Preparing to revise the quote. Please wait."
    then, after **~15-25 seconds**, an in-app modal "Copy quote items from
    previous version?" with the job-type note and **Cancel / No / Yes**. Wait
    for it — do not re-click the menu item.
    - **Yes**: app navigates to the new revision (full "Preparing updates"
      reload, ~20s); items are copied.
    - **No**: new revision has no quote items.
11. On the revision, Job Type, QuoteJobType, Client Account/Address/Contact,
    Asset and Description of Works are editable; Enquiry and Client Project
    are locked. Changing Client Contact on rev N does not change rev N-1
    (CYB-321 AC2).
12. **Invoicing** tab -> **New** -> Name, Invoicing Structure
    `Monthly Drawdowns` -> **Save** (the first Save click after picking the
    dropdown can miss — confirm the success banner). Then **Invoice
    Scheduling (Month)** -> **New** opens "Generate Monthly Schedule" with
    Frequency (Monthly / Bi-monthly / Quarterly / Bi-annual), Start Date,
    End Date, Total Value, Overwrite -> Save. Heading changes to
    `<Frequency> Drawdowns`.

## Verified result (2026-10-08)

- Account `77430` set to Active; Enquiry `4233`
  (`99d05d4a-3626-469a-8031-30244b99ed30`), status New -> Ready for Quote.
- Quote `3978` rev 0 (`11a5b3cd-...`) with item BCCS-NONHRB-033 / 500.00;
  rev 1 (`682da988-...`, Yes, item copied); rev 2 (`06b5fb45-...`, No, no
  items, Client Contact set to `UITEST_Contact_20261008_105123`).
- Rev 2 schedule `UITEST_Drawdown_20261008`, Quarterly, 01/11/2026-01/10/2027,
  £1,200 -> 4 x £300 on 01 Nov 2026, 01 Feb 2027, 01 May 2027, 01 Oct 2027.

## Gotchas

- The quote was created with Asset `37122 -` and Client Project
  `18967 - Auto Generated Project...` although no asset was set on the
  Enquiry.
- Before #848, quarterly generation pinned the final row to the End Date
  (May -> Oct gap). Since #848 multi-month frequencies keep their cadence and
  stop at the last cadence date on or before the End Date (01/11/2026 to
  01/10/2027 quarterly -> Nov, Feb, May, Aug), and the toast names the
  frequency. The modal title stays "Generate Monthly Schedule" by design.
- Pressing Escape with the Enquiry Tasks menu open navigated back to the
  Enquiries grid. Close menus by clicking a blank header area instead.
- The Blazor "An unhandled error has occurred." element and the "Exit Page"
  dialog are always in the DOM (hidden); `find` reports them even when not
  shown — confirm with a screenshot.
- Screenshot JPEG rendering makes `0` look like `3` in small time selects;
  read values via `find` rather than the image.

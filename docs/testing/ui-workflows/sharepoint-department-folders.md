---
workflow: sharepoint-department-folders
last_verified: 2026-10-08
verification_status: partial (BSC Enquiry + Quote verified; Job, SIL and control pending)
verified_against: local DEV (https://localhost:44368, API on https://localhost:7202, DB ShoreDB -> 10.100.34.114\general / CymBuild_DEV264, branch feature/SB_CYB-405-507-26.4-sharepoint-dept-folders @ dfda4500)
target_environment: local DEV only
depends_on: create-enquiry-quote-revision (client account), create-account
---

# SharePoint department folders (CYB-405 / CYB-507)

## Purpose

Prove in the UI that new Enquiries, Quotes and Jobs get department-specific
SharePoint folders, and only for the right department:

| Department (Dev264 OU) | Job type | Expected folders (Enquiry / Quote / Job) |
|---|---|---|
| Building Safety Consultancy (25) | 88 Building Safety Consultancy | Drawings, Fees Proposals, Incoming Emails, Outgoing Emails, Photographs, Reports, Technical Documents — same set for all three |
| Fire Engineering - SIL (27) | 93 Fire Engineering- SIL | Same as Fire Engineering UK: Enquiry = Correspondence, Emails (Incoming), Emails (Outgoing), Drawings, Technical Documents; Quote = Fees>Quotations>POs + the two email folders; Job = Fees>Quotations>POs, Correspondence>Contracts, both email folders, Drawings, Photographs, Reports, Technical Documents |
| Control: Sustainability Compliance (22) | 75 Sustainability | Enquiry/Quote: no department folders; Job: default Admin, Certs, Design Information, Design Risk Management, Emails, Finance, Photos, Reports |

## Prerequisites

- The test user must be in the department's quote **Bid Team** group, or the
  quote cannot be accepted and Create Jobs fails with
  "The quote must be accepted first". Dev264 groups: `BID_BSC`
  (Building Safety Consultancy Bid Team), `BID_FIRE_SIL` (Fire Engineering
  SIL Bid Team). Assign via **Settings -> Users -> <user> -> groups**.
  Authorisation only lists items for groups the user belongs to.
- Client: `UITEST_Account_20261008_105123_Updated` (Active).

## Steps (observed)

1. **Enquiries** -> grid **New** (~10s). Fill Description of Works
   (`UITEST_SPFolders_<Dept>_<date> ...`), **Lead Organisational Unit** (type to
   filter, pick the department), **Client** (type the UITEST account, pick),
   **Value Of Work** 1000. **Save**.
2. Banner "Setting up SharePoint document structure..." then
   "SharePoint document structure and files created successfully".
3. **Documents** tab: first load may sit on "Loading folders..."; press
   **Refresh** (right of the toolbar; **Open** next to it opens the SharePoint
   folder in a new browser tab). Assert the folder list.
4. **Enquiry Services** -> **New** -> Job Type (department job type) -> panel
   **Save** -> **Close**.
5. BSC enquiry workflow offers `Bid Team Review` / `Dead` from New (no
   `Ready for Quote`). Not needed: **Tasks -> Create Quote(s) from Enquiry**
   works at status New when Value Of Work > 0. Toast
   "Quote has been Successfully Created"; service row shows the quote number.
6. Open the quote from **Quoting** grid (search the description, double-click).
   Organisational Unit field shows the department. **Documents** tab -> assert
   folders; also expect marker file `__<quote no>` and `Enquiry Link - <enquiry no>.url`.
7. **Quote Items** -> **New** -> Details `UITEST_QuoteItem_...`, Product,
   Provide At Stage, Net -> **Save**. The panel re-lays out after Product is
   picked; re-locate Stage/Net before typing.
8. **Record Status** -> **New** -> comment -> New Status `For Review`
   (BSC options from Quoting: `For Review`, `Ready to Send`) -> Save.
   Quote gets a "User Action Required" badge.
9. **Authorisation** (left nav) -> find the quote -> Review/Approve
   (requires Bid Team membership — see Prerequisites). *Not yet observed.*
10. Quote **Tasks -> Create Jobs** once accepted -> open the Job -> Documents
    tab -> assert folders. *Not yet observed.*

## Verified result (2026-10-08, branch code)

- BSC Enquiry `4235` (`3a5a3de0-5a36-4dcd-a722-41130edf7616`): 7 BSC folders,
  exact match. SharePoint location `ConcursusSystem/TestSite/17735`.
- BSC Quote `3979` (`8ff061e1-f7a5-4d35-81ae-2520c49f0905`), OU Building Safety
  Consultancy: same 7 folders + `__3979` + `Enquiry Link - 4235.url`.
  Quote item BSC product, RIBA Stage 0, £500; status Quoting -> For Review.
- Create Jobs on 3979 before acceptance: "The quote must be accepted first".

## Pending

- Assign test user to `BID_BSC` (and `BID_FIRE_SIL`), approve 3979 in
  Authorisation, Create Jobs, check BSC Job folders.
- SIL: Enquiry -> Quote -> Job.
- Control (Sustainability Compliance): Enquiry -> Quote -> Job.

## Gotchas

- Dev264 records provision into SharePoint `ConcursusSystem/TestSite`, not a
  business site (confirmed via the Documents **Open** button).
- `find` / the browser extension can drop mid-run; re-acquire the tab with
  `tabs_context_mcp`.

"""Build the CymBuild 26.2 -> 26.4 UAT sign-off / regression test workbook."""
import sys
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.worksheet.datavalidation import DataValidation
from openpyxl.formatting.rule import CellIsRule, FormulaRule
from openpyxl.utils import get_column_letter

OUT = sys.argv[1]
JIRA = "https://socotecuk.atlassian.net/browse/"

# (Area, Jira keys, Title, Type, What changed, How to test, Expected result, Suggested testers, Priority, Note)
H, M, L = "High", "Medium", "Low"
NEW, FIX, IMP = "New feature", "Bug fix", "Improvement"
LIVE = "Already hotfixed to LIVE 26.2 - regression check only."

T = [
# ---------------- 1. General UI & navigation ----------------
("General UI & Navigation", "CYB-537, CYB-512", "Telerik components fully removed (all screens rebuilt)", IMP,
 "The old Telerik UI library has been removed. Grids, dropdowns, date pickers and CSV export were rebuilt.",
 "1. Open a selection of the screens you use every day (Enquiry, Quote, Job, Finance grids).\n2. Use dropdowns, date pickers, grid sort/filter and paging.\n3. Export a grid to CSV and open it in Excel.",
 "Every screen loads and works as before. The CSV opens with the right columns and data and no corrupted characters.", "All teams", H, ""),
("General UI & Navigation", "CYB-315", "Universal Search", NEW,
 "A single search box finds Jobs, Enquiries, Quotes, Accounts, Contacts and Assets across CymBuild.",
 "1. Use the universal search to look for a job number, a client name and an asset address.\n2. Click a result.",
 "Matching records from each area are returned and clicking a result opens the correct record.", "All teams", H, ""),
("General UI & Navigation", "CYB-524", "Grid scrolling - frozen headers and horizontal scroll", IMP,
 "Column headers stay fixed when you scroll down, and you can scroll sideways without going to the bottom of the grid.",
 "1. Open a wide grid (e.g. All Jobs).\n2. Scroll down, then scroll left/right.",
 "Column titles stay visible. You can scroll sideways from anywhere in the grid.", "All teams", M, ""),
("General UI & Navigation", "CYB-558, CYB-560", "Collapsible boxes and collapsible grid search", IMP,
 "Collapsed boxes are now smaller and show no content. The search/filter panel on small grids (e.g. statuses, purpose groups) can be collapsed.",
 "1. Collapse a section on a record.\n2. Collapse and expand the search panel on a small grid.",
 "Collapsed boxes take up minimal space. The search panel hides and shows correctly.", "All teams", L, ""),
("General UI & Navigation", "CYB-559, CYB-561", "SOCOTEC colour scheme and grid row shading", IMP,
 "Colours on records now match the SOCOTEC scheme, and grids have alternate row shading.",
 "Open a Job record and a few grids.", "Colours match the SOCOTEC scheme and grid rows are shaded alternately, so they are easier to read.", "All teams", L, ""),
("General UI & Navigation", "CYB-509, CYB-510, CYB-542, CYB-575", "Dropdowns, field widths and validation layout", FIX,
 "Dropdowns could be cut off at the edge of a section. Some fields were too narrow. Validation messages overlapped fields or made them shrink.",
 "1. Open dropdowns near the bottom of a section (e.g. Account Address, Quote Item Invoice Schedule, Record Status, Invoice Request Item Fee Stage).\n2. Check Contact Position, Invoicing Schedule Name and Activity Title are wide enough.\n3. Trigger a validation error on an Activity and on a Fee Amendment date.",
 "Dropdowns show in full. Fields are readable. Validation messages show without overlapping or shrinking the field.", "All teams", M, ""),
("General UI & Navigation", "CYB-460, CYB-484", "Task/Save menu position and status dropdown", FIX,
 "The Task and Save buttons no longer shift to the left. The status dropdown no longer offers the record's current status.",
 "1. Open an Enquiry, Quote and Job and check the button positions.\n2. Open the status dropdown on a Quote that is 'Ready to Send'.",
 "Buttons stay in place. The current status is not listed as a next-status option.", "All teams", L, ""),
("General UI & Navigation", "CYB-551", "Record no longer disappears when an error occurs", FIX,
 "Previously an error banner could wipe the record content below it, forcing a page refresh.",
 "1. On an Enquiry/Quote/Job, trigger an error (e.g. a validation failure on Save).",
 "The error shows at the top and the record stays visible and usable.", "All teams", H, ""),
("General UI & Navigation", "CYB-170", "System Security modal closes", FIX,
 "Settings > System Security: the record pop-up would not close.",
 "Settings > System Security > double-click a row > close the pop-up.", "The pop-up closes without a page refresh.", "System admins", L, ""),
("General UI & Navigation", "CYB-487", "Expired login handled gracefully (PWA)", FIX,
 "When a session token expires (e.g. laptop left on overnight), the app now sends you back to sign-in instead of showing a raw error.",
 "Leave CymBuild open overnight (or past token expiry), then click something.", "You are redirected to sign in and can carry on. No raw error and no app restart needed.", "All teams", M, ""),
("General UI & Navigation", "CYB-168, CYB-466", "Grid filters - typing once and filters persisting", FIX,
 "Grid column filters needed the value typing twice. The Transactions grid filter was lost after opening and saving a record.",
 "1. Type a filter value once in a grid column.\n2. In Finance > Transactions filter (e.g. 'CDM'), open a record, save and exit.",
 "The filter applies first time. The filtered view is kept when you return to the grid.", "Finance, All teams", M, ""),
("General UI & Navigation", "CYB-411", "Notification 'View Record' link", FIX,
 "The 'View Record' link in review notifications went to the home page.",
 "Open a review notification and click 'View Record'.", "The correct record opens.", "Reviewers / Approvers", M, LIVE),
("General UI & Navigation", "CYB-515", "Workflow notifications are sent", FIX,
 "Fixes notifications for Bid Team Review, Bid Approval, Quote Review, Quote Approval, Conversion to Job, Closure Request and Closure Approval.",
 "Take a test Enquiry through bid review and approval, and a Job through a closure request. Check that each notification is received.",
 "Each notification arrives (in-app/email) with a working link.", "Enquiry/Quote approvers, Job closure approvers", H, ""),
("General UI & Navigation", "(no ticket)", "AI Assistant", NEW,
 "An AI Assistant panel has been added to CymBuild.",
 "If it is enabled for your role, open the Assistant and ask a simple question about a record.",
 "The Assistant opens and responds. If it is not intended for go-live, mark this test N/A and add a comment.", "Pilot users", L,
 "Confirm with the CymBuild team whether this is enabled for go-live."),

# ---------------- 2. Business Unit / Department filters ----------------
("BU & Department Filters", "CYB-251, CYB-253, CYB-254", "BU/Department column and filter - Client Projects, CRM, Assets", IMP,
 "Business Unit and Department columns and filters were added to Client Projects and to the related-records grids on CRM and Assets.",
 "Filter each grid by a BU, then by a Department.", "Only matching records are shown. The columns show the correct BU and Department.", "All teams", M, ""),
("BU & Department Filters", "CYB-255", "BU/Department filter - Enquiries tab", IMP,
 "Added to All, Approved, Open and Closed Enquiries and to Enquiries for Quote Review.",
 "Filter each Enquiries grid by BU and Department.", "Results are filtered correctly in every grid.", "Enquiry teams", M, ""),
("BU & Department Filters", "CYB-256, CYB-257, CYB-258", "BU/Department filter - Quotes tab, Filtered Quoting, Quote Dashboard", IMP,
 "Added to the Quoting grids (All, Current, Ready to Send, Not Issued, Templates, Products), Filtered Quoting and the Quote Dashboard.",
 "Filter each Quotes grid and the dashboard by BU and Department.", "Results and dashboard figures match the selected filter.", "Quoting teams", M,
 "Quote Dashboard filter (CYB-258) was hotfixed to LIVE."),
("BU & Department Filters", "CYB-259", "BU/Department filter - Authorisation tab", IMP,
 "Added to the Authorisation and Quote Self Assign tabs.", "Filter both grids by BU and Department.", "Results are filtered correctly.", "Authorisers", M, ""),
("BU & Department Filters", "CYB-260", "BU/Department filter - Finance tab", IMP,
 "Added to Transactions (batched and posted), Invoice Requests, Sage Posting Status, My/Team Invoicing and Sage Export.",
 "Filter each Finance grid by BU and Department.", "Results are filtered correctly.", "Finance", M, ""),
("BU & Department Filters", "CYB-261", "BU/Department filter - Jobs tab", IMP,
 "Added to all Jobs grids (All, Current, Dormant, Overdue Milestones, F10s, PCI, Not Invoiced lists, and so on).",
 "Filter a sample of the Jobs grids by BU and Department.", "Results are filtered correctly.", "All Job teams", M, ""),
("BU & Department Filters", "CYB-252, CYB-538", "Schedule - Team Schedule and Team Availability filters", IMP,
 "BU/Department filters were added. Team Availability now allows several departments to be selected at once.",
 "Schedule tab > Team Availability: select two or more departments.", "Staff from all selected departments are shown.", "Team leaders", M, ""),
("BU & Department Filters", "CYB-508, CYB-545", "Product BU/Department columns and missing filters", FIX,
 "The Product grid had the BU and Department columns swapped, and some BU/Department filters were missing.",
 "Open Quotes > Products and check the BU and Department columns.", "BU data is in the BU column and Department data is in the Department column.", "Quoting teams", L, ""),

# ---------------- 3. Enquiries ----------------
("Enquiries", "CYB-454", "Enquiry - fewer mandatory fields", IMP,
 "An Enquiry can now be saved with sparse information. Fields only become mandatory when you move it on to quote.",
 "1. Create an Enquiry with only the minimum details and save.\n2. Try to progress it to quote.",
 "Step 1 saves. At the quote stage you are asked to fill in the required fields.", "Enquiry teams", H, ""),
("Enquiries", "CYB-311, CYB-513, CYB-493", "Automatic Quote creation on Bid Review approval", NEW,
 "When the Bid Review Team approves an Enquiry, the Quote is created automatically and the Enquiry moves Ready for Quote > Quoting. A Quote can no longer be created without a Value of Work.",
 "1. Take an Enquiry through Bid Review approval.\n2. Repeat with Value of Work left blank.",
 "1: A Quote is created automatically and the Enquiry status is 'Quoting'.\n2: You are stopped with a clear message asking for the Value of Work.", "Enquiry teams, Bid Review Team", H, ""),
("Enquiries", "CYB-554", "Quote reference shows on Enquiry after quote creation", FIX,
 "The new Quote number did not appear at the bottom of the Enquiry until the page was refreshed.",
 "Create a Quote from an Enquiry and look at the bottom of the Enquiry.", "The Quote reference appears without a refresh.", "Enquiry teams", M,
 "Jira status: In Testing."),
("Enquiries", "CYB-569", "Correct 'New' status on Enquiries", FIX,
 "Enquiries on the default workflow (CDM, Building, Real Estate) were given the wrong 'New' status.",
 "Create a new CDM / Building / Real Estate Enquiry.", "The Enquiry gets the correct 'New' status and the expected next statuses are offered.", "CDM, Building, Real Estate", M,
 "Jira status: In Testing."),
("Enquiries", "(no ticket)", "Enquiry inline Town and Agent/Finance County saved", FIX,
 "Town typed inline on an Enquiry address was not saved, and the Agent and Finance County fields were swapped.",
 "On an Enquiry, enter inline addresses with Town and County for Property, Agent and Finance. Save and reopen.",
 "Town and County are saved in the correct fields for each address.", "Enquiry teams", M, "Merged 14 Oct 2026 (PR #889)."),
("Enquiries", "CYB-312", "Duplicate warning - Accounts, Contacts, Assets", NEW,
 "Creating an Account, Contact or Asset now warns if a similar record already exists.",
 "Create an Account/Contact/Asset with a name or address that already exists. Then save a genuinely new one.",
 "A duplicate warning lists the similar records. A genuinely new record saves normally, and the check runs again on later edits.", "All teams", H, ""),
("Enquiries", "CYB-299", "Project Key Notes field (Enquiry > Quote > Job)", NEW,
 "A new 'Project Key Notes' field carries critical notes from Enquiry to Quote to Job.",
 "Add notes on an Enquiry, convert to Quote then Job.", "Notes appear on the Quote and Job, showing who entered them.", "All teams", M, ""),

# ---------------- 4. Quotes ----------------
("Quotes", "CYB-319", "Revised quote status", NEW,
 "Creating a revision now sets the previous versions to 'Revised', so they drop off chase lists.",
 "Create a revision of a Sent quote.", "The old version shows 'Revised' and is no longer in active/chase grids.", "Quoting teams", H, ""),
("Quotes", "CYB-320", "Copy quote items on revision", NEW,
 "When you create a revision, you are asked 'Copy quote items from previous version?'.",
 "Create a revision, answer Yes. Create another, answer No.", "Yes copies the items, including RIBA stages. No starts with an empty items list.", "Quoting teams", H, ""),
("Quotes", "CYB-321", "Editable fields during revision", IMP,
 "During a revision you can now edit client/agent contacts, job type, description of work and items/fees.",
 "On a revision, change the client contact, description and an item fee, then save.", "The changes save on the revision. The original version is unchanged.", "Quoting teams", H, "Jira status: In Testing."),
("Quotes", "CYB-462", "Quote expiry date editability", FIX,
 "The Expiry Date is now editable up to 'Ready to Send' and locks once the quote is 'Sent'.",
 "Edit the Expiry Date on a quote in Quoting, then Ready to Send, then Sent.", "Editable in Quoting and Ready to Send. Locked once Sent (for general users).", "Quoting teams", M, "Jira status: In Testing."),
("Quotes", "CYB-461", "Automatic expiry of old Enquiries and Quotes", FIX,
 "Unconverted Enquiries and Quotes past the expiry period are set to 'Expired' automatically (background job, hourly).",
 "Find a test quote/enquiry whose expiry date has passed (by more than a day). Check its status after the next hourly run.",
 "The status becomes 'Expired'. Records expiring today are not expired yet.", "Quoting teams", H,
 "Expiry runs on a schedule. Allow at least an hour after deployment."),
("Quotes", "CYB-467", "Quote Dashboard / Filtered Quoting - Sent Date range", IMP,
 "You can now filter by Sent Date range as well as Creation Date.",
 "Filter the Quote Dashboard by a Sent Date range.", "Only quotes sent in that range are counted, matching your own report.", "FE, BRAC, CDM", M, ""),
("Quotes", "CYB-340", "Data and Security Classification", NEW,
 "Quotes have 'Data Classification' (Official / Official Sensitive) and 'Security Classification' fields, which copy to the Job and Client Project.",
 "Set both on a quote, convert to a Job.", "The values show on the Quote, Job and Client Project. Access is restricted as specified.", "Quoting teams, Security lead", M, ""),
("Quotes", "CYB-323", "Fire Engineering fee proposal auto-population", NEW,
 "The FE fee proposal now fills in the consultant signature, client details, quote items and fee tables automatically.",
 "Generate an FE fee proposal from a quote with several items and invoice schedules.",
 "The signature, client block, items and Table 2 rows are filled in correctly. Every invoice schedule row is shown.", "Fire Engineering", H,
 "Regenerate documents created before deployment."),
("Quotes", "CYB-477", "BRAC fee proposal header/front cover", FIX,
 "BRAC fee proposals were generated with a blank header/front cover.",
 "Generate a BRAC fee proposal.", "The front cover and header are present.", "BRAC", M, LIVE),

# ---------------- 5. Jobs & Activities ----------------
("Jobs & Activities", "CYB-489, CYB-553, CYB-573", "Quote to Job conversion - fees carried over", FIX,
 "Fixes for: Agreed Fee and fee stages (including 'Other Fees' and items with no RIBA stage) not reaching the Job, and items on different invoice schedules losing value.",
 "1. Create a quote with several items: one with no RIBA stage, one on 'Other Fees', and two on different invoice schedules (e.g. On Activity Complete + Monthly).\n2. Accept it and create the Job.",
 "The Job Fees table shows the full quoted value for every item and stage, and the total matches the quote.", "All quoting / job teams", H,
 "CYB-553/CYB-573 are 'In Progress' in Jira. Splitting into separate Jobs per schedule is held pending a BA decision, so test the fee values only. Partly hotfixed to LIVE."),
("Jobs & Activities", "CYB-215", "Change consultant re-assigns tentative activities", NEW,
 "Changing the Job consultant now reassigns its tentative activities automatically.",
 "Change the consultant on a Job with tentative activities.", "Tentative activities move to the new consultant. Completed ones are unchanged.", "BRAC, Team leaders", H, ""),
("Jobs & Activities", "CYB-522", "Cannot complete an activity with a future end date", NEW,
 "Completing an Activity whose End Date is in the future is now blocked.",
 "Set an activity's End Date to tomorrow and mark it Complete.", "Blocked with the message 'Cannot complete an activity because the end date...'.", "All Job teams", M, LIVE),
("Jobs & Activities", "CYB-562, CYB-563", "Time 'Now' button and free time entry", IMP,
 "The 'Now' time button is back on Milestones and Activities, and you can type any time rather than pick from the list.",
 "On an Activity, click 'Now', then type a time such as 10:37.", "Both work and save.", "All Job teams", M, ""),
("Jobs & Activities", "CYB-544", "New Activity save - no false red border", FIX,
 "A new activity showed a red error border with no explanation.",
 "Create an activity with all mandatory fields filled in, then Save and Save & Exit.", "It saves with no error border.", "All Job teams", M, ""),
("Jobs & Activities", "CYB-579", "Bulk update 'Select All' covers every page", FIX,
 "In the Activities bulk update, 'Select All' only applied to the current page. A confirmation step was added.",
 "Filter activities so there are several pages, tick Select All, then apply a bulk change.",
 "A confirmation shows the total count. The change applies to every record on every page.", "Team leaders", H, ""),
("Jobs & Activities", "CYB-526", "Finance Group data moved to the Fees tab", IMP,
 "Finance Group data moved from the Job main tab to the Fees tab.",
 "Open a Job, look at the main tab and then the Fees tab.", "Finance Group data appears only on the Fees tab.", "Finance, Job teams", L, ""),
("Jobs & Activities", "CYB-306", "Subcontractor picked from Accounts", IMP,
 "Subcontractor name is now chosen from Purchase Ledger Accounts instead of typed as free text.",
 "Add a subcontractor to a Job.", "You choose from Purchase Ledger accounts only. Existing values still display.", "Engineering, FE", M, ""),
("Jobs & Activities", "CYB-539", "My CDM Work grid error", FIX,
 "The My CDM Work grid raised an unhandled error (yellow bar).", "Open My CDM Work.", "It loads with no error.", "CDM", M, ""),

# ---------------- 6. Fees & Fee Amendments ----------------
("Fees & Fee Amendments", "CYB-237, CYB-346", "Fee Amendment - new fields and custom page", NEW,
 "Fee Amendments now record the full lifecycle: Date Received, Requested By, Sent To, Date Chased, Status, Agreed By, Rejection reason and more.",
 "Job > Fees > Fee Amendments: add an amendment, chase it, then mark it Agreed. Add another and Reject it.",
 "All fields save. The Total Agreed Fee changes only when the status is 'Agreed'. A rejection needs a reason. Agreed By is set by the system.", "All Job teams, Finance", H, "Jira status: In Testing."),
("Fees & Fee Amendments", "CYB-333", "Activity-based fee amendments", NEW,
 "Billable activities that were not in the original proposal can be added as extra fees, so they don't draw down the agreed fee.",
 "Add a new billable activity marked as additional to the agreed fee, then invoice it.", "The extra fee shows in the Fee table and the original agreed fee is not reduced.", "Fire Engineering", H, "Jira status: In Testing."),
("Fees & Fee Amendments", "CYB-334, CYB-335", "Fee table - Subcontractor Costs and Variation columns", NEW,
 "The Fee table gains a Subcontractor Costs column (from subcontractor invoices) and a Variation column (new agreed fee minus original agreed fee).",
 "Add a subcontractor invoice and an agreed fee amendment on a Job.", "Both columns and their totals update correctly.", "Engineering, FE, Finance", H, "Jira status: In Testing."),
("Fees & Fee Amendments", "CYB-336", "Collated Fee Amendment grid", NEW,
 "A new grid lists all fee amendments across jobs for management reporting.",
 "Open the Fee Amendments grid and filter by Job/Status/Date.", "All amendments appear with the correct fields, and the filters work.", "Managers, Finance", M, "Jira status: In Testing."),
("Fees & Fee Amendments", "CYB-235, CYB-279", "Drawdown dates and drawdown templates", IMP,
 "Drawdown dates can be changed one at a time or as a series, with a reason. Templates now go beyond Monthly (e.g. Quarterly).",
 "Change one drawdown date, then a series, entering a reason. Create a quarterly drawdown.", "Dates update, the reason and audit are kept, and the quarterly schedule generates correctly.", "Finance, Job teams", M, ""),
("Fees & Fee Amendments", "CYB-327, CYB-329", "Financial Overview - Invoice Requests total and 'Not yet invoiced'", IMP,
 "A new box shows the total of non-actioned invoice requests, and 'Awaiting invoice creation' is renamed 'Not yet invoiced'.",
 "Open a Job's Financial Overview with pending invoice requests.", "The total matches the pending requests and the new label is shown.", "Job teams, Finance", M, ""),
("Fees & Fee Amendments", "CYB-297, CYB-525", "Job Financial Overview grid", NEW,
 "A consolidated grid of all Jobs with Agreed, Invoiced and Outstanding values (renamed 'Job Financial Overview').",
 "Open Job Financial Overview and filter by BU/Department/Consultant.", "The figures for a sample job match that job's own Financial Overview.", "Managers, Finance", H, ""),

# ---------------- 7. Invoicing & Finance ----------------
("Invoicing & Finance", "CYB-19, CYB-523", "Multiple Purchase Orders per Job", NEW,
 "A Job can hold several POs, and a PO can be saved before any Invoice Request exists.",
 "Add two POs to a Job. Raise an invoice request against each one.", "Both POs save straight away and each invoice shows the right PO.", "Engineering, Finance", H, ""),
("Invoicing & Finance", "CYB-548", "No duplicate invoice requests from an Activity", FIX,
 "Clicking 'Request Invoice' twice created duplicate invoice requests.",
 "On a completed activity, click Task > Request Invoice twice quickly.", "Only one invoice request is created.", "All Job teams", H, ""),
("Invoicing & Finance", "CYB-483", "Delete invoice request items", FIX,
 "Deleting an invoice request item said 'success' but the item stayed.",
 "Delete an item from an invoice request.", "The item is removed.", "Finance, Job teams", M, ""),
("Invoicing & Finance", "CYB-504", "Merge invoice requests - same job only", FIX,
 "Merging selected requests merged every request in the grid.",
 "Select 2-3 requests for one job and Merge.", "Only the selected requests (same job) are merged.", "Finance", H, LIVE),
("Invoicing & Finance", "CYB-389", "WIP flag and WIP report", NEW,
 "Invoice requests that can't be issued can be marked WIP with a reason, and appear in a separate WIP grid/report.",
 "Mark an invoice request as WIP with a reason. Open the Invoice Requests (WIP) grid.", "It moves to the WIP grid with the reason shown and leaves the standard grid.", "Finance", H, "Jira status: In Testing."),
("Invoicing & Finance", "CYB-572", "Activities Complete Not Invoiced list", FIX,
 "Already-invoiced activities were showing in 'Activities Complete Not Invoiced'.",
 "Open the list and check a job whose activity is already invoiced (e.g. similar to Job 9800).", "Invoiced activities are not listed.", "Finance, Team leaders", M, ""),
("Invoicing & Finance", "CYB-499", "Batched transactions - reject back to invoice requests", FIX,
 "Batched transactions are no longer counted as real transactions. 'Delete' now returns them to Invoice Requests so they can be traced.",
 "Batch an invoice request, then reject/delete the batch.", "The request returns to Invoice Requests. Job reporting ignores un-posted batches.", "Finance", H, ""),
("Invoicing & Finance", "CYB-521", "Finance can delete transaction line items", FIX,
 "Finance users could not delete transaction line items.", "As Finance, delete a line on an unposted transaction.", "The line is deleted.", "Finance", M, ""),
("Invoicing & Finance", "CYB-400", "Invoice Mode change reason is kept", FIX,
 "The reason entered when changing Invoice Mode was cleared on save. It is now stored with the user and date.",
 "Change a Job's Invoice Mode with a reason. Reopen it.", "The reason, user and date are shown in the history.", "Finance", M, ""),
("Invoicing & Finance", "CYB-287", "Invoice schedules carry RIBA stage and references", FIX,
 "Automatic invoice requests now carry the RIBA stage and extra references.",
 "Let a drawdown schedule generate an invoice request.", "The request has the correct RIBA stage and references.", "Finance", M, LIVE),
("Invoicing & Finance", "CYB-296, CYB-536", "Transactions grid - more columns and faster", IMP,
 "Adds Job No, Job Description, BU, Department, Product and subcontractor invoices to the Transactions grid, and the grid loads faster.",
 "Open Finance > Transactions, filter by the new columns.", "The grid loads quickly, the new columns are filled and filters work.", "Finance, FE", H, ""),
("Invoicing & Finance", "CYB-426", "Job overdue invoices grid", NEW,
 "A new grid lists the overdue invoices for a Job.", "Open a Job with an overdue invoice and view the overdue invoices grid.", "Overdue invoices are listed.", "Finance", L, ""),
("Invoicing & Finance", "CYB-580", "Stages with no Agreed Fee cannot be invoiced", FIX,
 "Invoice requests were allocated to a stage with no Agreed Fee (e.g. Stage 7) instead of the activity's stage (e.g. Stage 4).",
 "On a Job with fees on Stage 4 only, raise an invoice request from a Stage 4 activity and invoice it.",
 "The request and invoice are allocated to Stage 4. Stages with no agreed fee are not invoiceable, and nothing is put against RIBA Stage 0.", "Finance, Job teams", H,
 "Fix is on a branch, not merged into the UAT build yet."),
("Invoicing & Finance", "CYB-581", "All transactions visible in CymBuild", FIX,
 "LIVE bug: some October transactions (CDM662-CDM667) appear in QlikSense but not in CymBuild.",
 "Find the equivalent transactions in UAT in Finance > Transactions and on their Jobs.", "Every transaction that's in QlikSense also shows in CymBuild.", "Finance", H,
 "Jira: In Progress. No fix yet."),
("Invoicing & Finance", "CYB-540","Authorisation panel loads faster", FIX,
 "The Authorisation panel/grid was slow.", "Open the Authorisation tab.", "It loads in a few seconds.", "Authorisers", M, ""),

# ---------------- 8. Sage integration ----------------
("Sage Integration", "CYB-501", "Sage document number and status clean-up", IMP,
 "The Sage Document Number now comes back into CymBuild, and old 'Pending' transactions were corrected.",
 "Post a transaction to Sage, then reopen it in CymBuild.", "The Sage Document Number is shown and the status is correct.", "Finance", H, ""),
("Sage Integration", "CYB-530", "Non-sterling invoices not auto-posted", NEW,
 "Batched transactions can be flagged so they are not posted to Sage automatically (for non-sterling invoices).",
 "Flag a transaction as manual/non-sterling and run posting.", "It is not sent to Sage. Unflagged transactions are sent.", "Finance", H, ""),
("Sage Integration", "CYB-543, CYB-568, CYB-495", "Receipts and allocations from Sage", FIX,
 "A paid invoice in Sage now creates the Receipt and Allocation, with the correct Net/Gross value and payment date, and clears 'Overdue'.",
 "Record a payment in Sage (UAT) for a CymBuild invoice and wait for the next sync.",
 "The receipt shows the Net value excluding VAT, the Gross value including VAT and the Sage payment date. The invoice is 'Paid', not Overdue.", "Finance", H, LIVE),
("Sage Integration", "CYB-555", "Credit notes do not create receipts", FIX,
 "An invoice cancelled by a credit note no longer gets a false receipt. Sage type 1 = Receipt, and type 6 is ignored.",
 "Raise an invoice and a matching credit note, allocate in Sage, then wait for the sync.", "No receipt is created. The invoice shows as settled by the credit note.", "Finance", H,
 "Jira status: In Progress. Partly hotfixed to LIVE."),

# ---------------- 9. Documents & SharePoint ----------------
("Documents & SharePoint", "CYB-405", "Building Safety Consultancy folder structure", NEW,
 "New BSC Enquiries/Quotes/Jobs get Drawings, Incoming/Outgoing Emails, Fee Proposals, Photographs, Reports and Technical Documents folders.",
 "Create a BSC Enquiry, Quote and Job, then open SharePoint.", "Each record has exactly these folders and no duplicates.", "Building Safety Consultancy", M, "Jira status: In Testing."),
("Documents & SharePoint", "CYB-507", "Fire Engineering SIL folder structure", NEW,
 "FE SIL records get the Fire Engineering UK folder structure.",
 "Create an FE SIL Enquiry, Quote and Job.", "The folders match FE UK.", "Fire Engineering SIL", M, "Jira status: In Testing."),
("Documents & SharePoint", "CYB-481", "CDM Job folder structure", IMP,
 "New CDM Jobs use the revised folder structure.", "Create a new CDM Job.", "The folders match the agreed CDM structure. Old folder names are gone.", "CDM", M, ""),
("Documents & SharePoint", "CYB-474", "No duplicate email folders", FIX,
 "Building Envelope and Fire Engineering had duplicate Incoming/Outgoing Email folders.",
 "Create a Building Envelope Job and an FE Job.", "Only one Incoming and one Outgoing Emails folder each.", "Building Envelope, FE", L, LIVE),
("Documents & SharePoint", "CYB-496", "Merge documents Active/Inactive", NEW,
 "Merge document templates can be made inactive instead of deleted.",
 "As an admin, set a template Inactive. As a normal user, try to generate it.",
 "Inactive templates are hidden from normal users. Only SU/SYSADM can still see them. Setting it back to Active restores it.", "Template owners, Admins", M, "Jira status: In Testing."),
("Documents & SharePoint", "CYB-541", "Document generation completes", FIX,
 "Document generation could hang.", "Generate a merge document from a Quote and a Job.", "The document is produced and saved to SharePoint.", "All teams", H, ""),

# ---------------- 10. Outlook add-in ----------------
("Outlook Add-in", "CYB-244", "File attachments to specific folders", NEW,
 "When filing from Outlook, each attachment can go to a different folder and have its own description (AI description available).",
 "File an email with 2 attachments, sending each to a different folder.", "Each file lands in its chosen folder with its description.", "All Outlook users", H, "Jira status: In Testing."),
("Outlook Add-in", "CYB-247, CYB-418", "Suggested filing locations and single location", NEW,
 "The add-in suggests recent and likely locations. You can choose only one filing location.",
 "Open the add-in after filing a few emails.", "Suggestions appear, you can still pick any location, and multi-select is disabled.", "All Outlook users", M, "Jira status: In Testing."),

# ---------------- 11. Schedule ----------------
("Schedule & Availability", "CYB-488", "Job activities on Team Availability calendar", FIX,
 "Job activities did not appear on the Team Availability calendar.", "Create an activity assigned to yourself and open Team Availability.", "The activity appears as scheduled work.", "All Job teams", M, ""),

# ---------------- 12. Security ----------------
("Security & Access", "CYB-303", "Read-only user group", NEW,
 "A Read Only group gives auditors view-only access to CymBuild records and SharePoint folders.",
 "Log in as a read-only test user and open an Enquiry, Quote and Job.", "Everything is viewable but nothing can be edited, saved or deleted.", "Auditors, System admins", H, ""),

# ---------------- 13. LIVE 26.2 hotfix regression (non-Telerik) ----------------
("LIVE 26.2 Fixes - Regression", "CYB-415, CYB-468", "New Account / Account Address from an Enquiry does not hang", FIX,
 "Fixed in LIVE 26.2: creating a new Client Account from an Enquiry pop-out and then a new Account Address made the system hang or freeze.",
 "1. New Enquiry > Client pop-out > enter a name > Save.\n2. Account Addresses > New > pop-out to create an address > Save.\n3. Close the pop-ups.",
 "No hang or freeze. The new address is saved and shown, and the Enquiry stays usable.", "Enquiry teams", H, ""),
("LIVE 26.2 Fixes - Regression", "CYB-469", "Contact Details appear straight after saving", FIX,
 "Fixed in LIVE 26.2: a saved Contact Detail didn't appear until the window was closed and reopened.",
 "On a new Contact, add a Contact Detail (e.g. phone) and save.", "The detail appears in the table immediately.", "All teams", M, ""),
("LIVE 26.2 Fixes - Regression", "CYB-473, CYB-449", "Quote item dropdowns (Invoice Schedule / Product) show the right values", FIX,
 "Fixed in LIVE 26.2: Quote Items randomly showed no products, and the Invoice Schedule didn't appear in the quote item dropdown when the item was opened by double-click.",
 "1. On a Quote with an Invoice Schedule, double-click an existing Quote Item.\n2. Open the Product and Invoice Schedule dropdowns. Repeat a few times on different quotes.",
 "The right products for the job type and the quote's invoice schedules are always listed.", "Quoting teams", H, ""),
("LIVE 26.2 Fixes - Regression", "CYB-457", "Asset extra tabs (linked Quotes/Jobs, child assets, map)", FIX,
 "Fixed in LIVE 26.2: the Asset record lost its map and the tabs for linked quotes, jobs and child assets (null reference error).",
 "Open several Assets, including one with child assets and linked jobs.", "The map and the linked Quotes, Jobs and Child Assets tabs are shown, with no error.", "All teams", M, ""),
("LIVE 26.2 Fixes - Regression", "CYB-445, CYB-476", "Invoice Request processed flag and opening transactions", FIX,
 "Fixed in LIVE 26.2: an invoice request already approved to Transactions stayed in the Invoice Request grid with 'Processed = No', and some Transaction Details / Invoice Request Items would not open.",
 "1. Approve an invoice request through to a transaction.\n2. Edit the transaction detail (e.g. description) and save.\n3. Reopen the Job's Invoice Request and the Transaction Detail.",
 "The request leaves the Invoice Request grid and shows 'Processed = Yes'. Editing the transaction doesn't break the link. Both records open.", "Finance", H, ""),
("LIVE 26.2 Fixes - Regression", "CYB-506", "Job Fees tab always shows the finance information", FIX,
 "Fixed in LIVE 26.2: transactions and other finance grids on a Job's Fees tab were sometimes empty because a page number was carried over from another record.",
 "1. Open Job A > Fees, go to page 2 of a grid.\n2. Open Job B (with fewer rows) > Fees.", "Job B's grids start on page 1 and show their data.", "CDM, Finance", H, ""),
("LIVE 26.2 Fixes - Regression", "CYB-485", "Workflow Statuses and Workflow Authorisation do not hang", FIX,
 "Fixed in LIVE 26.2: opening Workflow Statuses or Workflow Authorisation hung the browser.",
 "Settings > Workflows > open a workflow > Statuses and Authorisation tabs.", "Both load quickly and only show rows for that workflow.", "System admins", M, ""),
("LIVE 26.2 Fixes - Regression", "CYB-475", "Sage PO number and VAT code", FIX,
 "Fixed in LIVE 26.2: the PO number was mapped to the wrong Sage field, and standard VAT posted at 17.5% instead of 20%.",
 "Post an invoice with a PO number at standard VAT to Sage (UAT).", "Sage shows the PO in the PO/customer order field, the CymBuild transaction number on the invoice, and 20% VAT.", "Finance", H, ""),
("LIVE 26.2 Fixes - Regression", "CYB-414, CYB-396", "Sage posting after editing a batched transaction / inbound sync", FIX,
 "Fixed in LIVE 26.2: an invoice wasn't sent to Sage if the batched transaction description was edited, and inbound sync gave 'Retry Pending' errors.",
 "1. Create and approve an invoice request, edit the batched transaction description, approve.\n2. Run Sage inbound sync from Inbound Diagnostics.",
 "The transaction posts once ('Sent') with a Sage reference. The sync completes with no Retry Pending error.", "Finance", H, ""),
("LIVE 26.2 Fixes - Regression", "CYB-412, CYB-416", "Quote to Job conversion and quote job type lock", FIX,
 "Fixed in LIVE 26.2: converting some quotes to jobs failed with a 'duplicate key @StageFees' error, and the job type could be changed with unrelated quote items present.",
 "1. Convert a quote with several items on the same stage to a Job.\n2. On another quote with items, try to change the Job Type.",
 "The Job is created with no error. The Job Type is locked once items exist, and the product list follows the job type.", "Quoting teams", H, ""),
("LIVE 26.2 Fixes - Regression", "CYB-419, CYB-570", "Automated invoice requests", FIX,
 "Fixed in LIVE 26.2: automated activity invoice requests showed SVC_Concursus as consultant, and requests were raised for dates that weren't drawdown dates (including paused schedules).",
 "Let the invoice automation run on jobs with activity-complete and paused/monthly drawdown schedules.",
 "The consultant is the activity assignee. Requests are only raised on real drawdown dates, and none for paused schedules.", "Finance", H, ""),
("LIVE 26.2 Fixes - Regression", "CYB-392, CYB-464", "Invoice schedule edit: stage field, paused/automated, monthly drawdown in automated mode", FIX,
 "Fixed in LIVE 26.2: the Stage field couldn't be edited on drawdowns, switching from Paused gave an error, and automated monthly drawdowns could not be amended.",
 "On a Job with an automated monthly drawdown: Edit Drawdowns, change a stage and amount, save. Then switch Paused > Automated.",
 "Edits save without changing mode. Stage dropdowns keep their values. The mode change works with no error.", "Finance, Job teams", H, ""),
("LIVE 26.2 Fixes - Regression", "CYB-436", "Transactions locked after approval; Finance-only edit", FIX,
 "Fixed in LIVE 26.2: transactions could be amended after batch approval, and non-Finance users could edit them.",
 "As a non-Finance user, open a transaction. As Finance, try to edit an approved transaction.", "Non-Finance users have read-only access. Approved transactions are locked.", "Finance", M, ""),
("LIVE 26.2 Fixes - Regression", "CYB-470, CYB-498", "Quote merge field and Enquiry duplication", FIX,
 "Fixed in LIVE 26.2: «QuoteOverview» took the Enquiry description instead of the Quote's. Duplicating an Enquiry with a quote produced a locked quote with no transition.",
 "1. Generate a quote document whose description of work differs from the enquiry.\n2. Duplicate an Enquiry that has a Quote.",
 "1: The quote's description is used.\n2: The new Enquiry is 'New' and the new Quote is 'Quoting' and editable.", "Quoting teams", M, ""),
("LIVE 26.2 Fixes - Regression", "CYB-384", "'Fees Stage' naming", FIX,
 "In LIVE 26.2: 'RIBA Stage' was renamed 'Fees Stage', and stage descriptions are prefixed (e.g. 'RIBA Stage 0 - ...').",
 "Open stage dropdowns on a Quote Item, Job Fees and Invoice Request Item.", "Labels and descriptions use the new naming consistently.", "All teams", L, ""),
]

# Build status for each test (keyed by the Jira keys string). Anything not listed = in the UAT build.
IN_BUILD, NOT_MERGED, PORT, NO_FIX = "In UAT build", "Not merged yet", "Port from 26.2 needed", "No fix yet"
ON_BRANCH = "Fix on branch - not merged yet"
BUILD = {
    "CYB-415, CYB-468": ON_BRANCH, "CYB-469": ON_BRANCH, "CYB-473, CYB-449": ON_BRANCH, "CYB-457": ON_BRANCH,
    "CYB-445, CYB-476": ON_BRANCH, "CYB-506": ON_BRANCH, "CYB-485": ON_BRANCH,
    "CYB-475": "QA server config needs VAT 22 -> 10 (repo fix on branch)",
    "CYB-515": "In build - notification hardening on branch",
    "CYB-489, CYB-553, CYB-573": "In build - monthly grid fix on branch",
    "CYB-580": NOT_MERGED, "CYB-581": NO_FIX,
}

# Gaps for the development team: fixes in LIVE 26.2/26.3 that are missing from release/26.4.
GAPS = [
("CYB-415 / CYB-468", "5ec9df91, dd4a1af9, bb13f397", "Enquiry > new Account / Account Address hangs or resets; SignalR blocks form load",
 "EditPage.razor.cs: non-blocking hub start, awaited initial state (no Task.Run(FormSubmitted)), no OnInitializedAsync re-init for windowed records after save, edit-state rebase after save. AccountDetail/AddressDetail parent-reference handling; AccountDetail grids use editPage.dataObject.Guid.", "High"),
("CYB-473 / CYB-457 / CYB-469", "3ff9c381, 7e6fd5cf, 43820dc7", "Wrong parent after grid double-click; Asset tabs null crash; Contact Details not refreshing",
 "EditPage.EnsureCorrectParentGuid sets stateService.OriginalRecordGuid; DynamicGridView double-click ParentDataObjectReference override; null guard round Tasks ButtonMenu in EditPage.razor; ContactDetail grids use editPage.dataObject.Guid.", "High"),
("CYB-445 / CYB-476", "dce858c4 (part)", "Editing a transaction detail unlinks its invoice request item",
 "SFin.TransactionDetailsUpsert: keep the existing InvoiceRequestItemId when no Guid is passed; throw 60076 on an unresolved Guid. (Apply in Dev264 first, then sync.)", "High"),
("CYB-506", "fa766c6c", "Job Fees child grids open on a page number carried from another record",
 "DynamicGridView.razor.cs: only save/restore _currentPageNumber for FullGrid grids.", "High"),
("(no ticket) / CYB-580", "dce858c4 (part)", "Invoice request items with no stage default to a real stage",
 "SFin.InvoiceRequestCreateInvoice + SFin.InvoiceRequestItemsUpsert: -1 / no-RIBA-stage sentinel. Overlaps the unmerged CYB-580 branch (bugfix/Oliver-CYB-580), so merge them together.", "High"),
("CYB-580", "bugfix/Oliver-CYB-580 (304c510e)", "Stage with no Agreed Fee shows invoiced values",
 "1 commit on a branch off 26.4, not merged. Review, merge and deploy to UAT.", "High"),
("CYB-581", "bugfix/Oliver-CYB-581 (empty)", "[Live] Some October transactions missing in CymBuild (CDM662-667)",
 "Jira: In Progress, no commits yet. Decide whether the fix is needed in 26.4 before sign-off.", "High"),
("CYB-515 (hardening)", "52eb8f94 (part)", "Workflow notifications can fail silently",
 "SCore.IntegrationOutbox_EnqueueWorkflowStatusNotification outcome codes, WorkflowOutboxRepository outcome handling, error-log CATCH in the transition trigger, Queue trigger diagnostic filter.", "Medium"),
("CYB-485", "79e9e001 (part)", "Workflow Status / Authorisation grids not tied to the parent workflow",
 "WorkflowDetail.razor: pass ParentGuid/ParentDataObjectReference/ParentRowStatus instead of DrawerGuid. Check grid metadata via the workbench.", "Medium"),
("CYB-475", "c7044bad regression", "QA environment posts standard VAT with code 22 (17.5%)",
 "appsettings.QA.json DefaultTaxCode 22 -> 10 (Live/Test already 10). Confirm the VatCodes SageVatNo=10 script has been run on QA2/UAT.", "Medium"),
("CYB-261", "dce858c4 (part)", "Team F10 Expiry list lacks BU/Department columns",
 "SJob.tvf_Jobs_TeamF10ExpiryList: add Department/BusinessUnit columns + joins; check grid metadata.", "Low"),
("CYB-489", "c24d3cb7", "Invoice Scheduling Monthly grid loses unsaved edits when paging past 50 rows",
 "Force a large page size for INVSCEDMONTHLY or disable the pager during drawdown inline edit.", "Low"),
("(no ticket)", "8c9eb85c (part)", "Duplicate-key errors when an exception is reported twice",
 "ButtonMenu.razor.cs: replace the remaining ex.Data.Add calls with SetExceptionData (main path already fixed by CYB-551).", "Low"),
("Enquiry Town (metadata)", "21c58946", "Enquiry inline Town metadata not in git",
 "Code is merged (#889). Migrate the entity query / @*Town parameter metadata to QA2/UAT via the metadata workbench.", "Medium"),
]

OUT_OF_SCOPE = [
("CYB-463", "Invoice Requests missing from page 2 (26.2 hotfix)", "Telerik-only fix. The 26.4 grid pages once on the client, so the bug can't occur. Paging is covered by the general UI tests."),
("CYB-459", "CSV export error on Filtered Quoting (26.2 hotfix)", "Telerik-only fix. The CSV export was rewritten in 26.4 (CYB-512) and is covered by test UI-01."),
("CYB-465", "Pop-up windows closing intermittently (26.2 hotfix)", "The 26.2 fix patched code that doesn't exist in 26.4. Re-test happens with the CYB-415 row once that port lands."),
("CYB-407 (part)", "Batch Edit pop-up reappearing (26.2 hotfix)", "Telerik window issue. 26.4 uses its own modal. The bulk update itself is tested in JOB-07."),
("CYB-358", "Merged asset 20117 repair (26.2 hotfix)", "Data repair for LIVE only. The Merge Assets procedure fix is in 26.4."),
("CYB-238", "Fee Amendments Monthly Comparison Report (QlikSense)", "Jira status: New Request. Not delivered in CymBuild 26.4."),
("CYB-573 (part)", "Separate Jobs per invoice schedule", "Held pending a BA decision. Only the fee-value part is in this release."),
("CYB-361 to CYB-377", "Database schema and metadata migration tooling", "Internal deployment tooling - no user-facing change."),
("CYB-549, CYB-550, CYB-576", "Quote creation stored-procedure fixes", "Covered by the 'Automatic Quote creation' and 'Quote revision' tests."),
("CYB-574, CYB-577, CYB-578", "Metadata transfer / internal database fixes", "Internal - no user-facing change."),
("(no ticket)", "Server deployment, automated tests, Kubernetes, performance tuning", "Internal - covered indirectly by the general UI tests."),
]

PR_NOTE = "Pushed {} - PR to release/26.4, then deploy to UAT. SQL was applied to Dev264 (now gone): re-apply to the current DEV before -SyncSource." 
PR_NOTE_UI = "Pushed {} - PR to release/26.4, then deploy to UAT and re-test."
GAP_STATE = {
    "CYB-415 / CYB-468": ("In progress", "Stephen Brett", PR_NOTE_UI.format("bugfix/SB_CYB-415-26.4-editpage-init-save (37a894d0)")),
    "CYB-473 / CYB-457 / CYB-469": ("In progress", "Stephen Brett", PR_NOTE_UI.format("bugfix/SB_CYB-473-26.4-parent-record-fixes (ac936d35)")),
    "CYB-445 / CYB-476": ("In progress", "Stephen Brett", PR_NOTE.format("bugfix/SB_CYB-445-26.4-transaction-detail-ir-link (a519f895)")),
    "CYB-506": ("In progress", "Stephen Brett", PR_NOTE_UI.format("bugfix/SB_CYB-506-26.4-child-grid-page (5bc7407d)")),
    "(no ticket) / CYB-580": ("In progress", "Stephen Brett", PR_NOTE.format("bugfix/SB_NoRibaStage-26.4-invoice-request-sentinel (efc02c86)") + " Merges with CYB-580; refresh the R4 hash for ItemsUpsert after the second merge."),
    "CYB-580": ("Open", "Oliver Eros", "Branch ready for review; merges cleanly with the no-stage fix (R4 hash line only)."),
    "CYB-515 (hardening)": ("In progress", "Stephen Brett", "Pushed bugfix/SB_CYB-515-26.4-workflow-notification-outcomes (de470213). Apply Upgrade Scripts/CYB-515_26.4_WorkflowNotificationOutcomes.sql to DEV, then -SyncSource (triggers live in the generated Tables file). Proc before API."),
    "CYB-485": ("In progress", "Stephen Brett", "Pushed bugfix/SB_CYB-485-26.4-workflow-detail-grids (25349725). WORKFLOWAUTH grid metadata is missing on CymBuild_QA2 (present on Dev/UAT_Test) - verify on UAT."),
    "CYB-475": ("In progress", "Stephen Brett", "Pushed bugfix/SB_CYB-475-26.4-qa-sage-vat-code (4a82c027). Also edit the deployed QA server appsettings.json by hand (server-owned, not overwritten by deploy). QA2 VatCodes already 10; UAT (Test.json) already 10."),
    "CYB-261": ("In progress", "Stephen Brett", "Pushed bugfix/SB_CYB-261-26.4-team-f10-expiry-bu-dept (718eac90). TVF lacks the columns on Dev, QA2 and UAT_Test; apply dev-pending/CYB-261 script to DEV, then -SyncSource."),
    "CYB-489": ("In progress", "Stephen Brett", "Pushed bugfix/SB_CYB-489-26.4-monthly-drawdown-single-page (a8ec8e46)."),
    "(no ticket)": ("In progress", "Stephen Brett", "Pushed bugfix/SB_ButtonMenu-26.4-exception-data (a2ebc03f)."),
    "Enquiry Town (metadata)": ("Open", "Stephen Brett", "Metadata only - migrate entity query 64b03f27 + @*Town params to QA2/UAT via the metadata workbench. CymBuild_Dev lacks the Town proc params too (Dev264 had them)."),
}

# ---- State at 14 Oct 2026 (evening): every port merged to release/26.4 (= main, d03e5df2); CymBuild_Dev
# ---- caught up (dev-catchup/CymBuild_Dev_26.4_CatchUp.sql) and duplicate data fixed. QA is Cymbuild_QA again.
MERGED = "Merged - awaiting UAT deploy"
for _k in ("CYB-415, CYB-468", "CYB-469", "CYB-473, CYB-449", "CYB-457", "CYB-445, CYB-476", "CYB-506", "CYB-485"):
    BUILD[_k] = MERGED
BUILD["CYB-475"] = "Merged - QA server appsettings still VAT 22 (manual)"
BUILD["CYB-515"] = "In build - hardening merged, awaiting UAT deploy"
BUILD["CYB-489, CYB-553, CYB-573"] = "In build - monthly grid fix merged, awaiting UAT deploy"

_DEPLOY = " Merged to release/26.4 and main. CymBuild_Dev applied 14 Oct. Next: Cymbuild_QA migration, UAT deploy, then set Deployed to UAT."
GAP_STATE.update({
    "CYB-415 / CYB-468": ("Merged to 26.4", "Stephen Brett", "PR #895." + _DEPLOY),
    "CYB-473 / CYB-457 / CYB-469": ("Merged to 26.4", "Stephen Brett", "PR #894." + _DEPLOY),
    "CYB-445 / CYB-476": ("Merged to 26.4", "Stephen Brett", "PR #891." + _DEPLOY),
    "CYB-506": ("Merged to 26.4", "Stephen Brett", "PR #893." + _DEPLOY),
    "(no ticket) / CYB-580": ("Merged to 26.4", "Stephen Brett", "PR #892." + _DEPLOY + " Oliver's CYB-580 branch must re-run tools/r4hash.py after rebasing."),
    "CYB-515 (hardening)": ("Merged to 26.4", "Stephen Brett", "Proc + triggers applied to CymBuild_Dev by the catch-up script; run -SyncSource so the generated Tables file picks up the triggers." + _DEPLOY),
    "CYB-485": ("Merged to 26.4", "Stephen Brett", "WORKFLOWAUTH grid metadata exists on CymBuild_Dev and UAT_Test (was missing on QA2)." + _DEPLOY),
    "CYB-475": ("Merged to 26.4", "Stephen Brett", "Repo fixed. STILL TO DO: edit the deployed QA server appsettings.json DefaultTaxCode 22 -> 10 by hand (server-owned file, never overwritten by deploy). UAT (Test.json) already 10."),
    "CYB-261": ("Merged to 26.4", "Stephen Brett", "TVF applied to CymBuild_Dev by the catch-up script." + _DEPLOY),
    "CYB-489": ("Merged to 26.4", "Stephen Brett", _DEPLOY.strip()),
    "(no ticket)": ("Merged to 26.4", "Stephen Brett", "ButtonMenu SetExceptionData." + _DEPLOY),
    "Enquiry Town (metadata)": ("In progress", "Stephen Brett", "Statement + 4 Town params applied to CymBuild_Dev 14 Oct (catch-up script). Next: metadata workbench migration CymBuild_Dev -> Cymbuild_QA -> UAT."),
    "Duplicate data": ("In progress", "Stephen Brett", "Applied to CymBuild_Dev 14 Oct (IX_UQ_EntityProperties_Hobt_Name created). Run data-fixes/Fix_DuplicateProductsAndEntityProperties.sql (preview, then @Apply=1) on QA, UAT and LIVE - BRAC HRB ADVISORY is duplicated on LIVE."),
    "FIRE-SIT": ("Open", "Business (Fire Engineering)", "Decide a new Code for one of the two products; until then IX_UQ_Products_Code cannot be created."),
    "Cyb333 test": ("Open", "Oliver Eros", "Decide whether the fee-amendment validation flags InvoicingValue only (current SQL) or both Value and Quantity (current test), then align."),
})
GAPS += [
    ("Duplicate data", "data-fixes/Fix_DuplicateProductsAndEntityProperties.sql",
     "Duplicate products (BRAC HRB ADVISORY, FIRE-DFS, IRE-FTC) and duplicate field definitions (Accounts.DefaultCreditTermsId, InvoiceRequests.FinanceBillingNotes/JobBillingNotes)",
     "True duplicates merged: references moved to the survivor, duplicate set RowStatus 254. Blocks the 26.4 unique indexes IX_UQ_Products_Code / IX_UQ_EntityProperties_Hobt_Name.", "Medium"),
    ("FIRE-SIT", "-", "Two different products share the code FIRE-SIT (Fire Engineering UK ID 76 / Fire Modelling ID 3262)",
     "Not a duplicate - one product needs a new Code (business decision).", "Low"),
    ("Cyb333 test", "262f8205 / 3e9347ab", "Fee amendment validation highlights Invoicing Value only",
     "Architecture test Cyb333...ActivitiesValidate fails on release/26.4: SQL and test (both 12 Oct, Oliver) disagree.", "Low"),
]

GAP_STATUS_LIST = '"Open,In progress,Merged to 26.4,Deployed to UAT,Won' + "'" + 't fix (agreed)"'

# ---------------- styles ----------------
F = "Arial"
navy = "1F3864"
hdr_fill = PatternFill("solid", fgColor=navy)
area_fill = PatternFill("solid", fgColor="D9E1F2")
input_fill = PatternFill("solid", fgColor="FFF2CC")
thin = Side(style="thin", color="BFBFBF")
box = Border(left=thin, right=thin, top=thin, bottom=thin)
wrap = Alignment(wrap_text=True, vertical="top")
hfont = Font(name=F, bold=True, color="FFFFFF", size=10)
body = Font(name=F, size=10)

wb = Workbook()

# ================= Sheet 1: Read Me & Sign-off =================
rs = wb.active
rs.title = "Read Me & Sign-off"
rs.sheet_view.showGridLines = False
rs.column_dimensions["A"].width = 30
for c in "BCDEFG":
    rs.column_dimensions[c].width = 16

rs["A1"] = "CymBuild 26.4 - User Acceptance & Release Sign-off"
rs["A1"].font = Font(name=F, bold=True, size=16, color=navy)
rs["A2"] = "Changes from LIVE (26.2) to UAT (26.4). This is the final full feature release of CymBuild."
rs["A2"].font = Font(name=F, italic=True, size=10)

info = [
    ("Test environment", "CymBuild UAT (release 26.4)"),
    ("Baseline (current LIVE)", "26.2"),
    ("Sheet prepared", "14 Oct 2026"),
    ("Source", "Jira tickets (CYB) in release/26.4 but not in 26.2, Jira fix versions 26.3/26.4, open In Testing tickets, and an audit of every 26.2/26.3 fix against 26.4"),
]
r = 4
for k, v in info:
    rs.cell(r, 1, k).font = Font(name=F, bold=True, size=10)
    rs.cell(r, 2, v).font = body
    r += 1

r += 1
rs.cell(r, 1, "How to use this sheet").font = Font(name=F, bold=True, size=12, color=navy); r += 1
steps = [
    "1. Go to the 'Test Checklist' tab. Filter the 'Suggested testers' or 'Area' column to find the tests for your team.",
    "2. Follow 'How to test' in UAT and compare with 'Expected result'.",
    "3. Fill in ONLY the yellow columns: Tester, Date tested, Result and Comments / defect ref.",
    "4. Result: Pass = works as expected | Fail = does not | Blocked = can't test (data, access, environment) | N/A = not relevant (add a reason).",
    "5. For every Fail or Blocked, put the Jira/defect reference or a short description in Comments.",
    "6. Rows marked 'Already hotfixed to LIVE', and the 'LIVE 26.2 Fixes - Regression' area, check that bugs fixed in LIVE are not back in 26.4.",
    "7. If 'Build status' is orange (not merged / port needed / no fix), the fix is not in UAT yet. Test it once the CymBuild team confirms deployment; until then mark it Blocked.",
    "8. When every row is Pass or N/A and the 'Release Gaps' tab is clear, each business area lead signs off below.",
]
for s in steps:
    rs.cell(r, 1, s).font = body
    rs.merge_cells(start_row=r, start_column=1, end_row=r, end_column=7)
    r += 1

# Summary
r += 1
rs.cell(r, 1, "Progress summary (updates automatically)").font = Font(name=F, bold=True, size=12, color=navy); r += 1
heads = ["Area", "Tests", "Pass", "Fail", "Blocked", "N/A", "Not started"]
for i, h in enumerate(heads, 1):
    c = rs.cell(r, i, h); c.font = hfont; c.fill = hdr_fill; c.border = box; c.alignment = Alignment(horizontal="center")
r += 1
areas = []
for t in T:
    if t[0] not in areas:
        areas.append(t[0])
first_sum = r
n = len(T)
CL = "'Test Checklist'"
rng_area = f"{CL}!$B$3:$B${n+2}"
rng_res = f"{CL}!$P$3:$P${n+2}"
for a in areas:
    rs.cell(r, 1, a).font = body
    rs.cell(r, 2, f'=COUNTIF({rng_area},A{r})')
    rs.cell(r, 3, f'=COUNTIFS({rng_area},A{r},{rng_res},"Pass")')
    rs.cell(r, 4, f'=COUNTIFS({rng_area},A{r},{rng_res},"Fail")')
    rs.cell(r, 5, f'=COUNTIFS({rng_area},A{r},{rng_res},"Blocked")')
    rs.cell(r, 6, f'=COUNTIFS({rng_area},A{r},{rng_res},"N/A")')
    rs.cell(r, 7, f'=B{r}-C{r}-D{r}-E{r}-F{r}')
    for col in range(1, 8):
        rs.cell(r, col).border = box
        if col > 1:
            rs.cell(r, col).font = body
            rs.cell(r, col).alignment = Alignment(horizontal="center")
    r += 1
last_sum = r - 1
rs.cell(r, 1, "TOTAL").font = Font(name=F, bold=True, size=10)
for col in range(2, 8):
    L_ = get_column_letter(col)
    c = rs.cell(r, col, f"=SUM({L_}{first_sum}:{L_}{last_sum})")
    c.font = Font(name=F, bold=True, size=10); c.alignment = Alignment(horizontal="center")
for col in range(1, 8):
    rs.cell(r, col).border = box
    rs.cell(r, col).fill = area_fill
tot = r
r += 2
rs.cell(r, 1, "% complete (Pass + N/A)").font = Font(name=F, bold=True, size=11)
c = rs.cell(r, 2, f"=IF(B{tot}=0,0,(C{tot}+F{tot})/B{tot})"); c.number_format = "0%"; c.font = Font(name=F, bold=True, size=11)
r += 1
rs.cell(r, 1, "Open release gaps (dev)").font = Font(name=F, bold=True, size=11)
gap_last = len(GAPS) + 2
c = rs.cell(r, 2, f"=COUNTA('Release Gaps'!$A$3:$A${gap_last})-COUNTIF('Release Gaps'!$F$3:$F${gap_last},\"Deployed to UAT\")-COUNTIF('Release Gaps'!$F$3:$F${gap_last},\"Won't fix (agreed)\")")
c.font = Font(name=F, bold=True, size=11); c.alignment = Alignment(horizontal="left")
gaps_cell = f"B{r}"
r += 1
rs.cell(r, 1, "Release readiness").font = Font(name=F, bold=True, size=11)
c = rs.cell(r, 2, f'=IF(AND(D{tot}=0,E{tot}=0,G{tot}=0,{gaps_cell}=0),"READY FOR SIGN-OFF",IF(D{tot}>0,"NOT READY - "&D{tot}&" failed",IF({gaps_cell}>0,"NOT READY - "&{gaps_cell}&" release gaps open","IN PROGRESS")))')
c.font = Font(name=F, bold=True, size=11)
rs.merge_cells(start_row=r, start_column=2, end_row=r, end_column=5)
ready_row = r
rs.conditional_formatting.add(f"B{ready_row}", FormulaRule(formula=[f'LEFT(B{ready_row},5)="READY"'], fill=PatternFill("solid", fgColor="C6EFCE"), font=Font(color="006100", bold=True)))
rs.conditional_formatting.add(f"B{ready_row}", FormulaRule(formula=[f'LEFT(B{ready_row},9)="NOT READY"'], fill=PatternFill("solid", fgColor="FFC7CE"), font=Font(color="9C0006", bold=True)))
rs.conditional_formatting.add(f"B{ready_row}", FormulaRule(formula=[f'B{ready_row}="IN PROGRESS"'], fill=PatternFill("solid", fgColor="FFEB9C"), font=Font(color="9C5700", bold=True)))

# Sign-off table
r += 2
rs.cell(r, 1, "Business sign-off").font = Font(name=F, bold=True, size=12, color=navy); r += 1
sh = ["Business area", "Approver name", "Role", "Decision (Approve / Reject)", "Date", "Comments", ""]
for i, h in enumerate(sh[:6], 1):
    c = rs.cell(r, i, h); c.font = hfont; c.fill = hdr_fill; c.border = box; c.alignment = Alignment(wrap_text=True, horizontal="center")
r += 1
dv_dec = DataValidation(type="list", formula1='"Approve,Reject"', allow_blank=True)
rs.add_data_validation(dv_dec)
signoff_areas = ["Enquiries & Quoting", "Jobs, Activities & Fees", "Finance, Invoicing & Sage", "Fire Engineering",
                 "CDM", "BRAC / Building Safety", "Engineering / Sustainability", "IT / CymBuild Product Owner"]
for a in signoff_areas:
    rs.cell(r, 1, a).font = body
    for col in range(1, 7):
        rs.cell(r, col).border = box
        if col > 1:
            rs.cell(r, col).fill = input_fill
            rs.cell(r, col).font = body
    rs.cell(r, 5).number_format = "dd/mm/yyyy"
    dv_dec.add(rs.cell(r, 4))
    r += 1
r += 1
rs.cell(r, 1, "Yellow cells are for you to fill in. Everything else is calculated or fixed.").font = Font(name=F, italic=True, size=9)

# ================= Sheet 2: Test Checklist =================
ws = wb.create_sheet("Test Checklist")
cols = [("Test ID", 8), ("Area", 18), ("Jira", 16), ("Change", 30), ("Type", 12), ("What changed", 42),
        ("How to test", 52), ("Expected result", 42), ("Suggested testers", 20), ("Priority", 9), ("Build status", 16), ("Notes", 32),
        ("Tester", 16), ("Date tested", 12), ("Comments / defect ref", 30), ("Result", 11)]
# keep Result next to Comments but make it column O for formulas
ws["A1"] = "Test Checklist - fill in the yellow columns (Tester, Date tested, Comments, Result). Orange 'Build status' = fix not yet in the UAT build."
ws["A1"].font = Font(name=F, bold=True, size=11, color=navy)
for i, (h, w) in enumerate(cols, 1):
    c = ws.cell(2, i, h); c.font = hfont; c.fill = hdr_fill; c.border = box
    c.alignment = Alignment(wrap_text=True, vertical="center", horizontal="center")
    ws.column_dimensions[get_column_letter(i)].width = w
ws.row_dimensions[2].height = 30

dv_res = DataValidation(type="list", formula1='"Pass,Fail,Blocked,N/A"', allow_blank=True,
                        showErrorMessage=True, errorTitle="Result", error="Choose Pass, Fail, Blocked or N/A")
ws.add_data_validation(dv_res)
dv_date = DataValidation(type="date", operator="greaterThan", formula1="DATE(2026,1,1)", allow_blank=True)
ws.add_data_validation(dv_date)

prefix = {}
for idx, t in enumerate(T):
    r = idx + 3
    area, keys, title, typ, what, how, exp, who, pri, note = t
    p = {"General UI & Navigation": "UI", "BU & Department Filters": "BU", "Enquiries": "ENQ", "Quotes": "QUO",
         "Jobs & Activities": "JOB", "Fees & Fee Amendments": "FEE", "Invoicing & Finance": "FIN", "Sage Integration": "SAGE",
         "Documents & SharePoint": "DOC", "Outlook Add-in": "OUT", "Schedule & Availability": "SCH", "Security & Access": "SEC",
         "LIVE 26.2 Fixes - Regression": "LIVE"}[area]
    prefix[p] = prefix.get(p, 0) + 1
    vals = [f"{p}-{prefix[p]:02d}", area, keys, title, typ, what, how, exp, who, pri, BUILD.get(keys, IN_BUILD), note, None, None, None, None]
    for i, v in enumerate(vals, 1):
        c = ws.cell(r, i, v)
        c.font = body; c.alignment = wrap; c.border = box
        if i in (13, 14, 15, 16):
            c.fill = input_fill
    first_key = keys.split(",")[0].strip()
    if first_key.startswith("CYB-"):
        ws.cell(r, 3).hyperlink = JIRA + first_key
        ws.cell(r, 3).font = Font(name=F, size=10, color="0563C1", underline="single")
    ws.cell(r, 14).number_format = "dd/mm/yyyy"
    ws.cell(r, 16).alignment = Alignment(horizontal="center", vertical="top")
    ws.cell(r, 10).alignment = Alignment(horizontal="center", vertical="top")
    dv_res.add(ws.cell(r, 16)); dv_date.add(ws.cell(r, 14))

last = len(T) + 2
res_rng = f"P3:P{last}"
ws.conditional_formatting.add(f"K3:K{last}", FormulaRule(formula=[f'K3<>"{IN_BUILD}"'], fill=PatternFill("solid", fgColor="F8CBAD"), font=Font(color="833C0B", bold=True)))
ws.conditional_formatting.add(res_rng, CellIsRule(operator="equal", formula=['"Pass"'], fill=PatternFill("solid", fgColor="C6EFCE"), font=Font(color="006100", bold=True)))
ws.conditional_formatting.add(res_rng, CellIsRule(operator="equal", formula=['"Fail"'], fill=PatternFill("solid", fgColor="FFC7CE"), font=Font(color="9C0006", bold=True)))
ws.conditional_formatting.add(res_rng, CellIsRule(operator="equal", formula=['"Blocked"'], fill=PatternFill("solid", fgColor="FFEB9C"), font=Font(color="9C5700", bold=True)))
ws.conditional_formatting.add(res_rng, CellIsRule(operator="equal", formula=['"N/A"'], fill=PatternFill("solid", fgColor="EDEDED")))
ws.conditional_formatting.add(f"J3:J{last}", CellIsRule(operator="equal", formula=['"High"'], font=Font(color="C00000", bold=True)))

# Example row guidance (as a note below the table, not a test row)
ex = last + 2
ws.cell(ex, 1, "Example of a completed row:").font = Font(name=F, bold=True, size=9, italic=True)
ws.cell(ex, 13, "Jane Smith").font = Font(name=F, size=9, italic=True)
ws.cell(ex, 14, "21/10/2026").font = Font(name=F, size=9, italic=True)
ws.cell(ex, 15, "Worked on Q4012. Minor: label wraps on small screen.").font = Font(name=F, size=9, italic=True)
ws.cell(ex, 16, "Pass").font = Font(name=F, size=9, italic=True)

ws.freeze_panes = "E3"
ws.auto_filter.ref = f"A2:P{last}"
ws.print_title_rows = "2:2"
ws.page_setup.orientation = "landscape"
ws.page_setup.fitToWidth = 1
ws.page_setup.fitToHeight = 0
ws.sheet_properties.pageSetUpPr.fitToPage = True

# ================= Sheet 3: Not in scope =================
os_ = wb.create_sheet("Not in Release or Internal")
os_["A1"] = "Items not tested by users: not in this release, held, or internal/technical only"
os_["A1"].font = Font(name=F, bold=True, size=11, color=navy)
for i, (h, w) in enumerate([("Jira", 24), ("Item", 50), ("Reason", 80)], 1):
    c = os_.cell(2, i, h); c.font = hfont; c.fill = hdr_fill; c.border = box
    os_.column_dimensions[get_column_letter(i)].width = w
for j, row in enumerate(OUT_OF_SCOPE, 3):
    for i, v in enumerate(row, 1):
        c = os_.cell(j, i, v); c.font = body; c.alignment = wrap; c.border = box

# ================= Sheet: Release Gaps =================
gs = wb.create_sheet("Release Gaps", 1)
gs["A1"] = "Release Gaps - fixes in LIVE 26.2 / 26.3 (or open tickets) that are NOT yet in the 26.4 UAT build. All must be Deployed to UAT (or agreed Won't fix) before sign-off."
gs["A1"].font = Font(name=F, bold=True, size=11, color="C00000")
gcols = [("Jira", 20), ("Source fix (26.2/26.3 commit)", 24), ("Symptom for users", 42), ("What is missing in 26.4", 70), ("Priority", 9),
         ("Status", 18), ("Owner", 16), ("Target date", 12), ("Notes", 30)]
for i, (h, w) in enumerate(gcols, 1):
    c = gs.cell(2, i, h); c.font = hfont; c.fill = hdr_fill; c.border = box
    c.alignment = Alignment(wrap_text=True, vertical="center", horizontal="center")
    gs.column_dimensions[get_column_letter(i)].width = w
dv_gs = DataValidation(type="list", formula1=GAP_STATUS_LIST, allow_blank=False)
gs.add_data_validation(dv_gs)
for j, g in enumerate(GAPS, 3):
    st = GAP_STATE.get(g[0], ("Open", None, None))
    vals = list(g) + [st[0], st[1], None, st[2]]
    for i, v in enumerate(vals, 1):
        c = gs.cell(j, i, v); c.font = body; c.alignment = wrap; c.border = box
        if i >= 6:
            c.fill = input_fill
    gs.cell(j, 8).number_format = "dd/mm/yyyy"
    dv_gs.add(gs.cell(j, 6))
    k = g[0].split()[0]
    if k.startswith("CYB-"):
        gs.cell(j, 1).hyperlink = JIRA + k
        gs.cell(j, 1).font = Font(name=F, size=10, color="0563C1", underline="single")
gl = len(GAPS) + 2
gs.conditional_formatting.add(f"F3:F{gl}", CellIsRule(operator="equal", formula=['"Open"'], fill=PatternFill("solid", fgColor="FFC7CE"), font=Font(color="9C0006", bold=True)))
gs.conditional_formatting.add(f"F3:F{gl}", CellIsRule(operator="equal", formula=['"Deployed to UAT"'], fill=PatternFill("solid", fgColor="C6EFCE"), font=Font(color="006100", bold=True)))
gs.conditional_formatting.add(f"E3:E{gl}", CellIsRule(operator="equal", formula=['"High"'], font=Font(color="C00000", bold=True)))
gs.freeze_panes = "B3"
gs.auto_filter.ref = f"A2:I{gl}"
gn = gl + 2
gs.cell(gn, 1, "How this list was produced: every commit on release/26.2 and release/26.3 that is not in release/26.4 was compared by file content at the 26.4 tip (14 Oct 2026, eb2da124). Telerik-only fixes are excluded (see 'Not in Release or Internal'). UI items are code-level findings: reproduce in UAT before porting.").font = Font(name=F, italic=True, size=9)
gs.merge_cells(start_row=gn, start_column=1, end_row=gn, end_column=9)
gs.cell(gn, 1).alignment = Alignment(wrap_text=True)
gs.row_dimensions[gn].height = 30

wb.save(OUT)
print("tests:", len(T), "areas:", len(areas))

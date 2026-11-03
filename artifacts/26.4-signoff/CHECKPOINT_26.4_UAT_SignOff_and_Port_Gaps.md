# Checkpoint: 26.4 UAT sign-off and LIVE-fix port gaps

Written 2026-10-14. The repo is back on `hotfix/SB_EnquiryTown-26.2-inline-town-save`, clean apart from the untracked `artifacts/`.

## Goal
26.4 is the final full CymBuild release. The deliverables are:
1. A user regression and sign-off sheet covering LIVE 26.2 to UAT 26.4. When every row passes, the release is ready to deploy.
2. Every bug fix in 26.2 or 26.3 also present in 26.4. Telerik-only 26.2 fixes are excluded.

User rules:
- In Testing tickets are included, flagged "not merged" where that applies.
- Missing fixes such as CYB-580 must be in the UAT build before sign-off.

## Deliverable 1: sign-off workbook (done; refresh as things change)
- **File:** `C:\Users\stephen.brett\source\CymBuild.Monorepo\artifacts\CymBuild_26.4_UAT_SignOff_Checklist.xlsx`. It's untracked, so open it from Explorer.
- **Generator:** `artifacts\26.4-signoff\tools\build_signoff.py <out.xlsx>`. The patches are already folded into this copy.
- **Tabs:**
  - **Read Me & Sign-off:** instructions, per-area summary formulas, open-gaps count, readiness flag and approver table.
  - **Release Gaps:** 14 dev items with a Status dropdown (Open / In progress / Merged to 26.4 / Deployed to UAT / Won't fix (agreed)), plus Owner and Notes.
  - **Test Checklist:** 98 tests in 13 areas, including "LIVE 26.2 Fixes - Regression" with 15 rows. Build status is in column K; Result is in column P.
  - **Not in Release or Internal:** Telerik-only and internal items.
- **Readiness logic:** it reads READY only when there are no Fail, Blocked or Not-started tests and no open gaps. It currently reads **"NOT READY - 14 release gaps open"**.
- **Recalculating:** `recalc.py` (LibreOffice) doesn't work on Windows. Recalculate and verify with Excel COM from PowerShell instead.
- **Refreshing gap statuses:** edit the `GAP_STATE` / `BUILD` dicts in `build_signoff.py`, then rebuild. Users may have typed results into the file by then, so if it's been circulated, edit the xlsx in place rather than regenerating it.

## Deliverable 2: port-gap audit (done)
- **Method:** `git cherry` of release/26.2 and release/26.3 against release/26.4, then every non-equivalent commit checked by content at the 26.4 tip (eb2da124). Three subagents did the batches.
- **Result:** 26.3 has nothing missing. 26.2 has the 14 gaps listed on the Release Gaps tab.
- **Excluded as Telerik-only:** CYB-463, CYB-459, CYB-465, and the modal part of CYB-407. CYB-358 was a LIVE data repair only.

## High-priority ports: pushed, no PRs yet
All five branch off origin/release/26.4. A merge-tree simulation shows they merge together cleanly.

| Branch | Commit | Fix | Dev264 |
|---|---|---|---|
| `bugfix/SB_CYB-445-26.4-transaction-detail-ir-link` | a519f895 | `SFin.TransactionDetailsUpsert` keeps the IR item link; THROW 60076 on an unresolved Guid | Applied and verified |
| `bugfix/SB_NoRibaStage-26.4-invoice-request-sentinel` | efc02c86 | `InvoiceRequestItemsUpsert` uses the -1 sentinel; `InvoiceRequestCreateInvoice` COALESCEs to -1 | Applied and verified |
| `bugfix/SB_CYB-506-26.4-child-grid-page` | 5bc7407d | `DynamicGridView.PersistsPageNumber`: only full, parentless grids save or restore the page | n/a |
| `bugfix/SB_CYB-473-26.4-parent-record-fixes` | ac936d35 | Windowed double-click parent override, `OriginalRecordGuid`, Tasks menu null guard, Contact and Account grids using `editPage.dataObject.Guid` | n/a |
| `bugfix/SB_CYB-415-26.4-editpage-init-save` | 37a894d0 | 3-way merge of LIVE's net EditPage/AccountDetail/AddressDetail delta (base 097d2394): non-blocking hub, awaited initial state, windowed refresh, rebase after save | n/a |

- **Tests:** each branch has a source-contract test in `tests/CymBuild.Architecture.Tests` (Cyb445*, InvoiceRequestNoRibaStage*, Cyb506*, Cyb473*, Cyb415*).
  - On the CYB-415 branch, architecture tests are 300/301 and Concursus.PWA.Tests are 122/122.
  - The one failure is Cyb333 `ActivitiesValidate`. It already fails on release/26.4 (Oliver's 262f8205), so it's not ours.
- **Dev264 rollback copies:** `artifacts\26.4-signoff\dev264\rollback_*.sql`. Apply scripts are in the same folder.
- **R4 manifest:** hashes were refreshed with `artifacts\26.4-signoff\tools\r4hash.py <repo> <Schema-relative path>`.
- **Merge order with CYB-580:** the no-stage branch and Oliver's CYB-580 branch conflict only on the R4 hash line for `SFin.InvoiceRequestItemsUpsert`. After merging the second one, re-run r4hash.py.

## Open: next steps
1. Raise PRs for the five branches into release/26.4. The user or Oliver merges them. Then redeploy QA and UAT (`Publish-CymBuildServer.ps1`), apply the SQL to QA2 and UAT, and set the gaps to "Deployed to UAT" in the workbook.
2. Reproduce on UAT after deployment. This covers the code-level UI ports, especially:
   - a new Account or Account Address from an Enquiry pop-out;
   - Quote Item dropdowns opened by double-click;
   - Asset tabs;
   - Contact Details;
   - Job Fees paging.
3. Port the medium and low gaps that remain:
   - **52eb8f94 (CYB-515):** workflow notification outcome codes (enqueue proc OUTPUT codes, WorkflowOutboxRepository handling, trigger CATCH/error log, queue-trigger WHERE). SQL: Dev264 first, then sync.
   - **CYB-485:** `WorkflowDetail.razor` WORKFLOWSTATUS/WORKFLOWAUTH grids pass ParentGuid, ParentDataObjectReference and ParentRowStatus instead of DrawerGuid. Check the grid metadata through the workbench.
   - **CYB-475:** `services/Concursus.API/appsettings.QA.json` DefaultTaxCode 22 should be 10. Can share a branch with the CYB-461 RecordExpiry config fix (ed050591). Confirm the VatCodes SageVatNo=10 script ran on QA2 and UAT.
   - **CYB-261:** `SJob.tvf_Jobs_TeamF10ExpiryList` needs Department/BusinessUnit columns and joins.
   - **c24d3cb7 (CYB-489):** the INVSCEDMONTHLY grid loses inline edits when paging past 50 rows.
   - **8c9eb85c:** in `ButtonMenu.razor.cs`, replace the remaining `ex.Data.Add` calls with `SetExceptionData`.
   - **Enquiry Town metadata:** migrate entity query 64b03f27 statement and `@*Town` params to QA2/UAT through the metadata workbench.
4. Oliver to review and merge the **CYB-580** branch (bugfix/Oliver-CYB-580, 304c510e).
5. Decide whether **CYB-581** ([Live] transactions CDM662-667 missing; In Progress) must be in 26.4. The branch has no commits yet.
6. Tell the team about the new **NuGet advisories** that break the PWA build (NU1902/NU1903):
   - `Microsoft.AspNetCore.SignalR.Common` 10.0.12
   - `System.Security.Cryptography.Pkcs` 10.0.0

   Local builds used `-p:NuGetAudit=false`. CI will fail until the packages are upgraded.
7. Ask Oliver about the failing **Cyb333** contract test, which may be another lost fix.

## Traps found this session
- **sqlcmd:** needs `env -u SQLCMDUSER -u SQLCMDPASSWORD sqlcmd -S "10.100.34.114\general" -d CymBuild_Dev264 -E -C ...`, and `cygpath -w` for `-i`/`-o` paths. Dev264 writes were allowed this session.
- **Procedure files:** editable in the repo (only Tables, Indexes and Constraints are generated). Keep the generated header and refresh the R4 hash.
- **Python on Windows:** text-mode writes add CRLF. Use binary mode, or strip with `tr -d '\r'`, when diffing or merging.
- **Ticket keys aren't proof:** a key appearing in 26.4 history doesn't mean the fix is there. DEV syncs and the Telerik rewrite both dropped code.

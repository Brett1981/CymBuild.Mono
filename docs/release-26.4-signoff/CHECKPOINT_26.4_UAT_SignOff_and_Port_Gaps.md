# Checkpoint: 26.4 UAT sign-off and LIVE-fix port gaps

Written 2026-10-14. Work continues on branch **`docs/SB_26.4-uat-signoff-checklist`** (off origin/release/26.4 at eb2da124). This pack lives in `docs/release-26.4-signoff/`: checkpoint, workbook, `tools/` and `dev264/` scripts. `/artifacts/` is git-ignored on 26.4, which is why the pack isn't there.

## Goal
26.4 is the final full CymBuild release. The deliverables are:
1. A user regression and sign-off sheet covering LIVE 26.2 to UAT 26.4. When every row passes, the release is ready to deploy.
2. Every bug fix in 26.2 or 26.3 also present in 26.4. Telerik-only 26.2 fixes are excluded.

User rules:
- In Testing tickets are included, flagged "not merged" where that applies.
- Missing fixes such as CYB-580 must be in the UAT build before sign-off.

## Deliverable 1: sign-off workbook (done; refresh as things change)
- **File:** `docs\release-26.4-signoff\CymBuild_26.4_UAT_SignOff_Checklist.xlsx` (committed on `docs/SB_26.4-uat-signoff-checklist`). An untracked working copy is also at `artifacts\CymBuild_26.4_UAT_SignOff_Checklist.xlsx`.
- **Generator:** `docs\release-26.4-signoff\tools\build_signoff.py <out.xlsx>`. The patches are already folded into this copy.
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

## Port branches: all 14 gaps covered, pushed, no PRs yet
All eleven branches are off origin/release/26.4. Their combined merge (temp commit 66d1a8e3) builds, PWA and API both. Test results on it:
- Architecture tests: 333/334. The one failure is Cyb333, explained below.
- Concursus.PWA.Tests: 122/122.
- Concursus.API.Tests: 291/291.

| Branch | Commit | Fix | SQL to DEV |
|---|---|---|---|
| `bugfix/SB_CYB-445-26.4-transaction-detail-ir-link` | a519f895 | `SFin.TransactionDetailsUpsert` keeps the IR item link | `dev-pending/01` |
| `bugfix/SB_NoRibaStage-26.4-invoice-request-sentinel` | efc02c86 | Invoice request items and transactions never get a NULL stage | `dev-pending/02` |
| `bugfix/SB_CYB-506-26.4-child-grid-page` | 5bc7407d | Only full, parentless grids persist their page | n/a |
| `bugfix/SB_CYB-473-26.4-parent-record-fixes` | ac936d35 | CYB-473/457/469/468 parent-record fixes | n/a |
| `bugfix/SB_CYB-415-26.4-editpage-init-save` | 37a894d0 | EditPage non-blocking hub, awaited init, windowed refresh, rebase after save | n/a |
| `bugfix/SB_CYB-475-26.4-qa-sage-vat-code` | 4a82c027 | `appsettings.QA.json` DefaultTaxCode 22 -> 10 | n/a, but see QA server note below |
| `bugfix/SB_CYB-485-26.4-workflow-detail-grids` | 25349725 | WORKFLOWSTATUS/WORKFLOWAUTH bound to the workflow (the AUTH tab was empty) | n/a |
| `bugfix/SB_ButtonMenu-26.4-exception-data` | a2ebc03f | 39 catch blocks use `SetExceptionData` | n/a |
| `bugfix/SB_CYB-489-26.4-monthly-drawdown-single-page` | a8ec8e46 | Monthly drawdown grid always on one page (at least 150 rows) | n/a |
| `bugfix/SB_CYB-261-26.4-team-f10-expiry-bu-dept` | 718eac90 | `tvf_Jobs_TeamF10ExpiryList` returns Department and BusinessUnit | `dev-pending/03` |
| `bugfix/SB_CYB-515-26.4-workflow-notification-outcomes` | de470213 | Enqueue proc outcome codes, repository retry handling, upgrade script for the triggers | `dev-pending/04`, then -SyncSource |

- **Tests:** every branch has a source-contract test in `tests/CymBuild.Architecture.Tests`.
- **SQL:** `dev-pending/README.md` lists the four scripts and the order to apply them.
  - `CymBuild_Dev264` stopped accepting logins on 14 Oct and is no longer listed on the server, so 01 and 02 are lost with it.
  - The old `CymBuild_Dev` is back online but has none of these changes.
  - Pre-change rollback copies are in `dev264/`.
- **Cyb333 test failure:** this is not a port gap. Oliver's 12 Oct SQL (262f8205) flags `InvoicingValue` only, but his test from the same day (3e9347ab) expects both InvoicingValue and InvoicingQuantity. The two-field version never existed in the repo.
- **Merge order with CYB-580:** the no-stage branch and Oliver's CYB-580 branch conflict only on the R4 hash line for `SFin.InvoiceRequestItemsUpsert`. Re-run `tools/r4hash.py` after merging the second one.

## Open: next steps
1. **Which DEV database is current now?** Apply `dev-pending/01..04` to it, then run -SyncSource for the CYB-515 triggers.
2. **Raise PRs** for the 11 branches into release/26.4. Then redeploy QA and UAT and set the gaps to "Deployed to UAT" in the workbook.
3. **Fix the QA server's VAT setting by hand.** Change `DefaultTaxCode` from 22 to 10 in its `appsettings.json`: server-owned files are never overwritten by the deploy. UAT (`appsettings.Test.json`) and QA2's VatCodes data are already correct.
4. **Migrate the Enquiry Town metadata** to QA2 and UAT through the metadata workbench: entity query 64b03f27 and the `@*Town` parameters.
5. **Fix QA2's missing WORKFLOWAUTH grid metadata.** It's present on CymBuild_Dev and UAT_Test, so verify CYB-485 on UAT for now.
6. **Reproduce the UI ports on UAT after deployment:**
   - a new Account or Account Address from an Enquiry pop-out;
   - Quote Item dropdowns opened by double-click;
   - Asset tabs;
   - Contact Details;
   - Job Fees paging;
   - Workflow Authorisation tab;
   - a monthly drawdown schedule longer than 50 months;
   - Team F10 BU/Department filters.
7. **Oliver:**
   - merge CYB-580;
   - decide whether CYB-581 is needed for 26.4;
   - resolve the Cyb333 test/code mismatch.
8. **Tell the team about the NuGet advisories** that break the PWA/API build (NU1902/NU1903):
   - SignalR.Common 10.0.12
   - Cryptography.Pkcs 10.0.0

   Local builds use `-p:NuGetAudit=false`.

## Traps found this session
- **sqlcmd:** needs `env -u SQLCMDUSER -u SQLCMDPASSWORD sqlcmd -S "10.100.34.114\general" -d <db> -E -C ...`, and `cygpath -w` for `-i`/`-o` paths. Use `SET NOEXEC ON` for compile-only checks. UAT_Test is on `SOC-SQLBRE01\SQL2022` (read access works).
- **Visual Studio locks Debug obj:** while VS is open, build and test with `-c Release`.
- **API project:** build `services/Concursus.API/Concursus.API.csproj` directly; the `.sln` next to it is stale.
- **Procedure files:** editable in the repo (only Tables, Indexes and Constraints are generated). Keep the generated header and refresh the R4 hash.
- **Python on Windows:** text-mode writes add CRLF. Use binary mode, or strip with `tr -d '\r'`, when diffing or merging.
- **Ticket keys aren't proof:** a key appearing in 26.4 history doesn't mean the fix is there. DEV syncs and the Telerik rewrite both dropped code.

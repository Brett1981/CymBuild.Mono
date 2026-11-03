---
workflow: bulk-update-job-activities
last_verified: 2026-10-08
verification_status: verified
verified_against: local DEV (https://localhost:44368, API on https://localhost:7202, DB ShoreDB -> 10.100.34.114\general / CymBuild_DEV264, release/26.4 @ c58053e9)
target_environment: local DEV only
---

# Bulk Update Job Activities (CYB-579 select-all)

## Purpose

Verify that **Select All** in the Job Activity bulk update applies to every
filtered row across pages, not just the visible page.

## Test-data contract

- There is no UITEST activity data; this edits existing DEV activities, so the
  user must approve it, and every change must be reverted afterwards.
- Pick a Job with **11-20 non-Complete activities**; the bulk grid pages
  client-side at 10 rows (`ActivityBulkUpdateGrid.ClientPageSize`).
  **Complete activities are not changed**; since #840 they are reported as
  skipped.
- Before changing anything, snapshot `SJob.Activities.SurveyorID` for the job
  (read-only query) so it can be restored.

## Steps

1. Open the Job -> **Activities** tab -> **Bulk Update** (opens the "Batch
   Edit / Job Activity" window, Rows N, Selected 0, "Page 1 of 2").
2. Tick the header checkbox. Expect `Selected N` and "All N matching rows
   selected across 2 pages."; page 2 rows are ticked too.
3. **Next** -> "Apply selected changes": tick the field's enable checkbox
   (e.g. Assignee = `Enable editing for SurveyorID`) and pick the value.
4. **Confirm** -> an in-page "Apply bulk update?" panel (since #840; it
   replaced the native `window.confirm`) with **Cancel** / **Apply changes**.
   Automation can click both.
5. Progress bar "Updating record x of N". If every record updated, the window
   closes and the grid refreshes. If any were skipped or failed, a "Bulk
   update finished" panel stays up (e.g. "0 of 11 records updated. 11 skipped
   (fields read-only or record not found).") -> **Close**.
6. Verify in the DB (read-only) that all N rows changed, then revert with a
   second bulk update to the original value.

## Verified result (2026-10-08)

- Job 9397 (11 activities, all Complete): select-all covered both pages, but
  0 rows changed (11 upserts returned 200). No "skipped" or failure summary
  was shown.
- Job 9579 (11 Tentative activities, all Elliot Grew / 1618): set Assignee
  to Stephen Brett (722) -> all 11 changed across both pages; reverted to
  1618 -> all 11 restored.

## Retest (2026-10-08, release/26.4 @ 8a4a6580 + #850)

- Job 9397 (11 Complete): Cancel closes the confirmation; Apply changes
  shows "0 of 11 records updated. 11 skipped"; Close dismisses it.
- On release/26.4 without #850 the overlay buttons (Stop, Cancel, Apply
  changes, Close) could not be clicked: they inherited `EditPage.razor`'s
  global `.overlay { pointer-events: none }`. #850 gives them their own class.

## Gotchas

- Before #840 the confirmation was a native `window.confirm`, which froze
  Claude-in-Chrome until a human clicked OK. If you are testing an older
  branch, plan for the user to click it.
- Before #840, bulk-updating Complete activities silently did nothing.

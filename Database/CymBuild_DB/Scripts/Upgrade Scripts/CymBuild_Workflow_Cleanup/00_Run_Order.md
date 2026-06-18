# CymBuild Workflow Cleanup / Alignment v14 Run Order

## A. Clean UAT
1. `01_UAT_Cleanup/00_Discovery.sql`
2. `01_UAT_Cleanup/01_PreValidation.sql`
3. `01_UAT_Cleanup/02_Apply_WorkflowCleanup.sql`
4. `01_UAT_Cleanup/03_PostValidation.sql`

## B. Generate single source snapshot from cleaned UAT
5. Run `02_UAT_to_DEV_Alignment/01_UAT_Generate_Workflow_Config_Source_Block_v14.sql` against cleaned UAT.
6. Copy the generated `SqlText` lines in order.

## C. Apply/validate in DEV
Paste the same generated source snapshot into each DEV script before running it.

7. `02_DEV_Preflight_Compare_Source_To_Target_v14.sql`
8. `03_DEV_Apply_Workflow_Groups_From_UAT_v14.sql`
9. `04_DEV_Apply_Workflow_OrganisationalUnits_From_UAT_v14.sql`
10. `05_DEV_Diagnose_Workflow_Notification_Group_Resolution_v14.sql`
11. `06_DEV_Apply_Workflow_Config_From_UAT_v14.sql`
12. `07_DEV_Validate_Workflow_Config_Final_v14.sql`
13. `09_DEV_Workflow_Active_State_Validation.sql`

## Notes
- Run Groups before OrganisationalUnits because `SCore.OrganisationalUnits.DefaultSecurityGroupId` has an FK to `SCore.Groups.ID`.
- The OU v14 step aligns the full required OU config shape, not only `ID/Guid/Name`.
- Runtime workflow history is not copied from UAT to DEV.

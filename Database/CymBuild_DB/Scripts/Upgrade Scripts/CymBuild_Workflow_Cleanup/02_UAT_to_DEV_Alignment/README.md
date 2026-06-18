# UAT to DEV Workflow Alignment v14

Run `01_UAT_Generate_Workflow_Config_Source_Block_v14.sql` on cleaned UAT, then paste the generated source block into each DEV script.

DEV order:

1. `02_DEV_Preflight_Compare_Source_To_Target_v14.sql`
2. `03_DEV_Apply_Workflow_Groups_From_UAT_v14.sql`
3. `04A_DEV_Diagnose_OrganisationalUnit_ID_GUID_Conflicts_v14.sql`
4. Prefer `04_DEV_Apply_Workflow_OrganisationalUnits_From_UAT_v14.sql` for strict full OU dependency alignment.
5. Use `04B_DEV_Apply_Workflow_Leaf_OrganisationalUnits_From_UAT_v14.sql` only if strict OU alignment blocks because the conflict is ancestor-only. v14 resolves missing direct OU parents to the nearest existing target ancestor.
6. `05_DEV_Diagnose_Workflow_Notification_Group_Resolution_v14.sql`
7. `06_DEV_Apply_Workflow_Config_From_UAT_v14.sql`
8. `07_DEV_Validate_Workflow_Config_Final_v14.sql`
9. `09_DEV_Workflow_Active_State_Validation.sql`

If a direct workflow OU ID exists in DEV with a different GUID, stop and use onboarding/security master alignment.

`04B` is intentionally not a full OU/security migration. It is only a workflow dependency repair for DEV/test alignment where direct workflow OU rows need to exist so `SCore.Workflow.OrganisationalUnitId` can resolve.

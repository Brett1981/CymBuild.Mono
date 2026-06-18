# Workflow Cleanup Pack v2 Hotfix Notes

This version fixes the failure raised by `tg_WorkflowStatusNotificationGroups_RecordHistory`:

```text
Data integrity exception: Attempt to alter -1 record
```

## Root cause
The original apply script attempted to repair `SCore.WorkflowStatusNotificationGroups.ID = -1` by updating its `WorkflowStatusGuid`.
That row is a CymBuild sentinel row and is protected by the record-history trigger.

## Fix
The v2 scripts now treat `SCore.WorkflowStatusNotificationGroups.ID = -1` as protected:

- It is not backed up for mutation rollback.
- It is not updated during status-GUID consolidation.
- It is not deleted as a hidden/orphan row.
- Post-validation ignores this sentinel when checking orphan notification-group status GUIDs.
- Rollback also excludes this sentinel row.

## Before rerunning
If the failed script is still in the same SSMS session, run:

```sql
IF XACT_STATE() <> 0
BEGIN
    ROLLBACK TRANSACTION;
END;

SELECT @@TRANCOUNT AS TranCount, XACT_STATE() AS XactState;
```

Then run the v2 pre-validation and apply scripts.


## v3 syntax fix

Corrected final duplicate validation blocks in `02_Apply_WorkflowCleanup.sql`.
SQL Server does not allow a CTE to be followed directly by `IF EXISTS`; the checks now use derived tables inside `IF EXISTS`.

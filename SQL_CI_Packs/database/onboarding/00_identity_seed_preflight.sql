/* ================================================================================================
   CymBuild Onboarding Migration - Identity seed preflight

   Purpose:
   - Reports identity current values and table max values for target tables used by onboarding apply.
   - Does not mutate data.

   Run with:
   sqlcmd -S <server> -d <target_db> -b -i database/onboarding/00_identity_seed_preflight.sql
   ================================================================================================ */

SET NOCOUNT ON;

DECLARE @Tables TABLE
(
    TableName SYSNAME NOT NULL
);

INSERT INTO @Tables (TableName)
VALUES
    (N'SCore.Groups'),
    (N'SCrm.Addresses'),
    (N'SCrm.Contacts'),
    (N'SCore.OrganisationalUnits'),
    (N'SCore.Identities'),
    (N'SCore.UserGroups'),
    (N'SCore.Workflow'),
    (N'SCore.WorkflowStatusNotificationGroups'),
    (N'SJob.JobTypes'),
    (N'SJob.ActivityTypes'),
    (N'SJob.MilestoneTypes'),
    (N'SJob.JobTypeActivityTypes'),
    (N'SJob.JobTypeMilestoneTemplates'),
    (N'SProd.Products'),
    (N'SJob.ProductJobActivities');

SELECT
    t.TableName,
    CurrentIdentityValue = IDENT_CURRENT(t.TableName)
FROM @Tables AS t
ORDER BY t.TableName;
GO

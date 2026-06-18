/* ================================================================================================
   CymBuild Onboarding Migration - Identity seed alignment

   Purpose:
   - Aligns identity seeds after database copy/restore where SQL Server identity metadata can lag.
   - Source-controlled, idempotent, deployment-safe for controlled DEV/QA/UAT runs.
   - Do not run as an ad-hoc LIVE fix. In LIVE, execute only as part of approved deployment.

   Notes:
   - DBCC CHECKIDENT(..., RESEED) reseeds to current MAX(identity) when current identity is lower.
   - This does not insert/update/delete business rows.
   ================================================================================================ */

SET NOCOUNT ON;

DBCC CHECKIDENT ('SCore.Groups', RESEED);
DBCC CHECKIDENT ('SCrm.Addresses', RESEED);
DBCC CHECKIDENT ('SCrm.Contacts', RESEED);
DBCC CHECKIDENT ('SCore.OrganisationalUnits', RESEED);
DBCC CHECKIDENT ('SCore.Identities', RESEED);
DBCC CHECKIDENT ('SCore.UserGroups', RESEED);
DBCC CHECKIDENT ('SCore.Workflow', RESEED);
DBCC CHECKIDENT ('SCore.WorkflowStatusNotificationGroups', RESEED);
DBCC CHECKIDENT ('SJob.JobTypes', RESEED);
DBCC CHECKIDENT ('SJob.ActivityTypes', RESEED);
DBCC CHECKIDENT ('SJob.MilestoneTypes', RESEED);
DBCC CHECKIDENT ('SJob.JobTypeActivityTypes', RESEED);
DBCC CHECKIDENT ('SJob.JobTypeMilestoneTemplates', RESEED);
DBCC CHECKIDENT ('SProd.Products', RESEED);
DBCC CHECKIDENT ('SJob.ProductJobActivities', RESEED);
GO

/*
    CymBuild Workflow Cleanup & Rationalisation
    Generated from UAT Workflows.zip export.
    Safety rules:
      - No direct entity current status update.
      - SCore.DataObjectTransition rows are preserved.
      - Duplicate status references are migrated before duplicate status rows are removed.
      - RowStatus filters use RowStatus NOT IN (0,254) for active checks.
      - No SELECT *.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @CleanupRunGuid uniqueidentifier = N'6f8a8d20-1a15-4be7-9c2d-4b2a7c5f2601';

PRINT CONCAT(N'Rolling back workflow cleanup run: ', CONVERT(nvarchar(36), @CleanupRunGuid));

IF NOT EXISTS (SELECT 1 FROM SCore.WorkflowCleanupRuns WHERE RunGuid = @CleanupRunGuid)
BEGIN
    THROW 62000, N'Workflow cleanup backup run was not found.', 1;
END;

BEGIN TRANSACTION;

/* Restore deleted DataObjects first so restored entity rows satisfy CymBuild object registry rules. */
INSERT INTO SCore.DataObjects
(
    Guid,
    RowStatus,
    EntityTypeId
)
SELECT
    b.Guid,
    b.RowStatus,
    b.EntityTypeId
FROM SCore.WorkflowCleanupBackup_DataObjects AS b
WHERE b.RunGuid = @CleanupRunGuid
  AND NOT EXISTS
  (
      SELECT 1
      FROM SCore.DataObjects AS dob
      WHERE dob.Guid = b.Guid
  );

SET IDENTITY_INSERT SCore.WorkflowStatus ON;
INSERT INTO SCore.WorkflowStatus
(
    ID,
    RowStatus,
    Guid,
    OrganisationalUnitId,
    Name,
    Description,
    ShowInEnquiries,
    ShowInQuotes,
    ShowInJobs,
    Enabled,
    IsPredefined,
    SortOrder,
    Colour,
    Icon,
    SendNotification,
    IsCompleteStatus,
    IsCustomerWaitingStatus,
    RequiresUsersAction,
    IsActiveStatus,
    AuthorisationNeeded,
    IsAuthStatus
)
SELECT
    b.ID,
    b.RowStatus,
    b.Guid,
    b.OrganisationalUnitId,
    b.Name,
    b.Description,
    b.ShowInEnquiries,
    b.ShowInQuotes,
    b.ShowInJobs,
    b.Enabled,
    b.IsPredefined,
    b.SortOrder,
    b.Colour,
    b.Icon,
    b.SendNotification,
    b.IsCompleteStatus,
    b.IsCustomerWaitingStatus,
    b.RequiresUsersAction,
    b.IsActiveStatus,
    b.AuthorisationNeeded,
    b.IsAuthStatus
FROM SCore.WorkflowCleanupBackup_WorkflowStatus AS b
WHERE b.RunGuid = @CleanupRunGuid
  AND NOT EXISTS
  (
      SELECT 1
      FROM SCore.WorkflowStatus AS ws
      WHERE ws.ID = b.ID
  );
SET IDENTITY_INSERT SCore.WorkflowStatus OFF;

UPDATE ws
SET
    RowStatus = b.RowStatus,
    Guid = b.Guid,
    OrganisationalUnitId = b.OrganisationalUnitId,
    Name = b.Name,
    Description = b.Description,
    ShowInEnquiries = b.ShowInEnquiries,
    ShowInQuotes = b.ShowInQuotes,
    ShowInJobs = b.ShowInJobs,
    Enabled = b.Enabled,
    IsPredefined = b.IsPredefined,
    SortOrder = b.SortOrder,
    Colour = b.Colour,
    Icon = b.Icon,
    SendNotification = b.SendNotification,
    IsCompleteStatus = b.IsCompleteStatus,
    IsCustomerWaitingStatus = b.IsCustomerWaitingStatus,
    RequiresUsersAction = b.RequiresUsersAction,
    IsActiveStatus = b.IsActiveStatus,
    AuthorisationNeeded = b.AuthorisationNeeded,
    IsAuthStatus = b.IsAuthStatus
FROM SCore.WorkflowStatus AS ws
JOIN SCore.WorkflowCleanupBackup_WorkflowStatus AS b
    ON b.ID = ws.ID
WHERE b.RunGuid = @CleanupRunGuid;

SET IDENTITY_INSERT SCore.Workflow ON;
INSERT INTO SCore.Workflow
(
    ID,
    RowStatus,
    Guid,
    OrganisationalUnitId,
    EntityTypeID,
    EntityHoBTID,
    Name,
    Description,
    Enabled
)
SELECT
    b.ID,
    b.RowStatus,
    b.Guid,
    b.OrganisationalUnitId,
    b.EntityTypeID,
    b.EntityHoBTID,
    b.Name,
    b.Description,
    b.Enabled
FROM SCore.WorkflowCleanupBackup_Workflow AS b
WHERE b.RunGuid = @CleanupRunGuid
  AND NOT EXISTS
  (
      SELECT 1
      FROM SCore.Workflow AS wf
      WHERE wf.ID = b.ID
  );
SET IDENTITY_INSERT SCore.Workflow OFF;

SET IDENTITY_INSERT SCore.WorkflowTransition ON;
INSERT INTO SCore.WorkflowTransition
(
    ID,
    RowStatus,
    Guid,
    WorkflowID,
    FromStatusID,
    ToStatusID,
    IsFinal,
    Enabled,
    SortOrder,
    Description
)
SELECT
    b.ID,
    b.RowStatus,
    b.Guid,
    b.WorkflowID,
    b.FromStatusID,
    b.ToStatusID,
    b.IsFinal,
    b.Enabled,
    b.SortOrder,
    b.Description
FROM SCore.WorkflowCleanupBackup_WorkflowTransition AS b
WHERE b.RunGuid = @CleanupRunGuid
  AND NOT EXISTS
  (
      SELECT 1
      FROM SCore.WorkflowTransition AS wt
      WHERE wt.ID = b.ID
  );
SET IDENTITY_INSERT SCore.WorkflowTransition OFF;

UPDATE wt
SET
    RowStatus = b.RowStatus,
    Guid = b.Guid,
    WorkflowID = b.WorkflowID,
    FromStatusID = b.FromStatusID,
    ToStatusID = b.ToStatusID,
    IsFinal = b.IsFinal,
    Enabled = b.Enabled,
    SortOrder = b.SortOrder,
    Description = b.Description
FROM SCore.WorkflowTransition AS wt
JOIN SCore.WorkflowCleanupBackup_WorkflowTransition AS b
    ON b.ID = wt.ID
WHERE b.RunGuid = @CleanupRunGuid;

SET IDENTITY_INSERT SCore.WorkflowStatusNotificationGroups ON;
INSERT INTO SCore.WorkflowStatusNotificationGroups
(
    ID,
    RowStatus,
    Guid,
    WorkflowID,
    WorkflowStatusGuid,
    GroupID,
    CanAction
)
SELECT
    b.ID,
    b.RowStatus,
    b.Guid,
    b.WorkflowID,
    b.WorkflowStatusGuid,
    b.GroupID,
    b.CanAction
FROM SCore.WorkflowCleanupBackup_WorkflowStatusNotificationGroups AS b
WHERE b.RunGuid = @CleanupRunGuid
  AND b.ID <> -1
  AND NOT EXISTS
  (
      SELECT 1
      FROM SCore.WorkflowStatusNotificationGroups AS ng
      WHERE ng.ID = b.ID
  );
SET IDENTITY_INSERT SCore.WorkflowStatusNotificationGroups OFF;

UPDATE ng
SET
    RowStatus = b.RowStatus,
    Guid = b.Guid,
    WorkflowID = b.WorkflowID,
    WorkflowStatusGuid = b.WorkflowStatusGuid,
    GroupID = b.GroupID,
    CanAction = b.CanAction
FROM SCore.WorkflowStatusNotificationGroups AS ng
JOIN SCore.WorkflowCleanupBackup_WorkflowStatusNotificationGroups AS b
    ON b.ID = ng.ID
WHERE b.RunGuid = @CleanupRunGuid
  AND ng.ID <> -1;

UPDATE dot
SET
    StatusID = b.StatusID,
    OldStatusID = b.OldStatusID
FROM SCore.DataObjectTransition AS dot
JOIN SCore.WorkflowCleanupBackup_DataObjectTransition AS b
    ON b.ID = dot.ID
WHERE b.RunGuid = @CleanupRunGuid;

UPDATE q
SET StatusId = b.StatusId
FROM SCore.WorkflowNotificationQueue AS q
JOIN SCore.WorkflowCleanupBackup_WorkflowNotificationQueue AS b
    ON b.ID = q.ID
WHERE b.RunGuid = @CleanupRunGuid;

UPDATE el
SET StatusId = b.StatusId
FROM SCore.WorkflowNotificationQueueErrorLog AS el
JOIN SCore.WorkflowCleanupBackup_WorkflowNotificationQueueErrorLog AS b
    ON b.ID = el.ID
WHERE b.RunGuid = @CleanupRunGuid;

UPDATE SCore.WorkflowCleanupRuns
SET CompletedOnUtc = NULL,
    Notes = CONCAT(ISNULL(Notes, N''), N' Rolled back on ', CONVERT(nvarchar(33), SYSUTCDATETIME(), 126), N'.')
WHERE RunGuid = @CleanupRunGuid;

COMMIT TRANSACTION;

PRINT N'Workflow cleanup rollback completed.';

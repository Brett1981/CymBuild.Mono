/*
    CymBuild Workflow Config Alignment Rollback
    Use only if the DEV alignment script committed and needs to be reverted.
    Set @RunGuid to the value printed by the apply script.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @RunGuid uniqueidentifier = N'00000000-0000-0000-0000-000000000000';

IF @RunGuid = N'00000000-0000-0000-0000-000000000000'
BEGIN
    ;THROW 73000, N'Set @RunGuid before running rollback.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM SCore.WorkflowConfigAlignRuns AS r
    WHERE r.RunGuid = @RunGuid
      AND r.CompletedOnUtc IS NOT NULL
)
BEGIN
    ;THROW 73001, N'No completed workflow config alignment run found for @RunGuid.', 1;
END;

BEGIN TRANSACTION;

/* Restore runtime status references first. */
UPDATE dot
SET
    StatusID = b.StatusID,
    OldStatusID = b.OldStatusID
FROM SCore.DataObjectTransition AS dot
INNER JOIN SCore.WorkflowConfigAlignBackup_DataObjectTransition AS b
    ON b.ID = dot.ID
WHERE b.RunGuid = @RunGuid;

UPDATE q
SET StatusId = b.StatusId
FROM SCore.WorkflowNotificationQueue AS q
INNER JOIN SCore.WorkflowConfigAlignBackup_WorkflowNotificationQueue AS b
    ON b.ID = q.ID
WHERE b.RunGuid = @RunGuid;

UPDATE el
SET StatusId = b.StatusId
FROM SCore.WorkflowNotificationQueueErrorLog AS el
INNER JOIN SCore.WorkflowConfigAlignBackup_WorkflowNotificationQueueErrorLog AS b
    ON b.ID = el.ID
WHERE b.RunGuid = @RunGuid;

/* Restore config tables. Child rows first deleted, then parents restored with identity insert. */
DELETE ng
FROM SCore.WorkflowStatusNotificationGroups AS ng
WHERE ng.ID <> -1;

DELETE wt
FROM SCore.WorkflowTransition AS wt
WHERE wt.ID <> -1;

DELETE wf
FROM SCore.Workflow AS wf
WHERE wf.ID <> -1;

DELETE ws
FROM SCore.WorkflowStatus AS ws
WHERE ws.ID <> -1;

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
FROM SCore.WorkflowConfigAlignBackup_WorkflowStatus AS b
WHERE b.RunGuid = @RunGuid
  AND b.ID <> -1;
SET IDENTITY_INSERT SCore.WorkflowStatus OFF;

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
FROM SCore.WorkflowConfigAlignBackup_Workflow AS b
WHERE b.RunGuid = @RunGuid
  AND b.ID <> -1;
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
FROM SCore.WorkflowConfigAlignBackup_WorkflowTransition AS b
WHERE b.RunGuid = @RunGuid
  AND b.ID <> -1;
SET IDENTITY_INSERT SCore.WorkflowTransition OFF;

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
FROM SCore.WorkflowConfigAlignBackup_WorkflowStatusNotificationGroups AS b
WHERE b.RunGuid = @RunGuid
  AND b.ID <> -1;
SET IDENTITY_INSERT SCore.WorkflowStatusNotificationGroups OFF;

/* Restore DataObjects that were backed up. */
UPDATE dob
SET
    RowStatus = b.RowStatus,
    EntityTypeId = b.EntityTypeId
FROM SCore.DataObjects AS dob
INNER JOIN SCore.WorkflowConfigAlignBackup_DataObjects AS b
    ON b.Guid = dob.Guid
WHERE b.RunGuid = @RunGuid;

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
FROM SCore.WorkflowConfigAlignBackup_DataObjects AS b
WHERE b.RunGuid = @RunGuid
  AND NOT EXISTS
  (
      SELECT 1
      FROM SCore.DataObjects AS dob
      WHERE dob.Guid = b.Guid
  );

UPDATE SCore.WorkflowConfigAlignRuns
SET CompletedOnUtc = NULL,
    Notes = CONCAT(ISNULL(Notes,N''), N' Rolled back on ', CONVERT(nvarchar(33), SYSUTCDATETIME(), 126), N' UTC.')
WHERE RunGuid = @RunGuid;

COMMIT TRANSACTION;

PRINT N'Workflow config alignment rollback completed.';

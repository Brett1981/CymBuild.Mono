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
DECLARE @StartedOnUtc datetime2(7) = SYSUTCDATETIME();

PRINT CONCAT(N'Workflow cleanup run: ', CONVERT(nvarchar(36), @CleanupRunGuid));

IF OBJECT_ID(N'SCore.WorkflowCleanupRuns', N'U') IS NULL
BEGIN
    CREATE TABLE SCore.WorkflowCleanupRuns
    (
        RunGuid uniqueidentifier NOT NULL CONSTRAINT PK_WorkflowCleanupRuns PRIMARY KEY,
        StartedOnUtc datetime2(7) NOT NULL,
        CompletedOnUtc datetime2(7) NULL,
        ScriptName nvarchar(200) NOT NULL,
        Notes nvarchar(1000) NULL
    );
END;

IF OBJECT_ID(N'SCore.WorkflowCleanupBackup_DataObjectTransition', N'U') IS NULL
BEGIN
    CREATE TABLE SCore.WorkflowCleanupBackup_DataObjectTransition
    (
        RunGuid uniqueidentifier NOT NULL,
        ID int NOT NULL,
        StatusID int NOT NULL,
        OldStatusID int NULL,
        CONSTRAINT PK_WorkflowCleanupBackup_DataObjectTransition PRIMARY KEY (RunGuid, ID)
    );
END;

IF OBJECT_ID(N'SCore.WorkflowCleanupBackup_WorkflowTransition', N'U') IS NULL
BEGIN
    CREATE TABLE SCore.WorkflowCleanupBackup_WorkflowTransition
    (
        RunGuid uniqueidentifier NOT NULL,
        ID int NOT NULL,
        RowStatus tinyint NOT NULL,
        Guid uniqueidentifier NULL,
        WorkflowID int NOT NULL,
        FromStatusID int NOT NULL,
        ToStatusID int NOT NULL,
        IsFinal bit NOT NULL,
        Enabled bit NOT NULL,
        SortOrder int NOT NULL,
        Description nvarchar(400) NOT NULL,
        CONSTRAINT PK_WorkflowCleanupBackup_WorkflowTransition PRIMARY KEY (RunGuid, ID)
    );
END;

IF OBJECT_ID(N'SCore.WorkflowCleanupBackup_WorkflowStatus', N'U') IS NULL
BEGIN
    CREATE TABLE SCore.WorkflowCleanupBackup_WorkflowStatus
    (
        RunGuid uniqueidentifier NOT NULL,
        ID int NOT NULL,
        RowStatus tinyint NOT NULL,
        Guid uniqueidentifier NULL,
        OrganisationalUnitId int NOT NULL,
        Name nvarchar(100) NOT NULL,
        Description nvarchar(400) NOT NULL,
        ShowInEnquiries bit NOT NULL,
        ShowInQuotes bit NOT NULL,
        ShowInJobs bit NOT NULL,
        Enabled bit NOT NULL,
        IsPredefined bit NOT NULL,
        SortOrder int NOT NULL,
        Colour nvarchar(7) NOT NULL,
        Icon nvarchar(50) NULL,
        SendNotification bit NOT NULL,
        IsCompleteStatus bit NOT NULL,
        IsCustomerWaitingStatus bit NOT NULL,
        RequiresUsersAction bit NOT NULL,
        IsActiveStatus bit NOT NULL,
        AuthorisationNeeded bit NOT NULL,
        IsAuthStatus bit NOT NULL,
        CONSTRAINT PK_WorkflowCleanupBackup_WorkflowStatus PRIMARY KEY (RunGuid, ID)
    );
END;

IF OBJECT_ID(N'SCore.WorkflowCleanupBackup_Workflow', N'U') IS NULL
BEGIN
    CREATE TABLE SCore.WorkflowCleanupBackup_Workflow
    (
        RunGuid uniqueidentifier NOT NULL,
        ID int NOT NULL,
        RowStatus tinyint NOT NULL,
        Guid uniqueidentifier NULL,
        OrganisationalUnitId int NOT NULL,
        EntityTypeID int NOT NULL,
        EntityHoBTID int NULL,
        Name nvarchar(100) NOT NULL,
        Description nvarchar(400) NULL,
        Enabled bit NOT NULL,
        CONSTRAINT PK_WorkflowCleanupBackup_Workflow PRIMARY KEY (RunGuid, ID)
    );
END;

IF OBJECT_ID(N'SCore.WorkflowCleanupBackup_WorkflowStatusNotificationGroups', N'U') IS NULL
BEGIN
    CREATE TABLE SCore.WorkflowCleanupBackup_WorkflowStatusNotificationGroups
    (
        RunGuid uniqueidentifier NOT NULL,
        ID int NOT NULL,
        RowStatus tinyint NOT NULL,
        Guid uniqueidentifier NOT NULL,
        WorkflowID int NOT NULL,
        WorkflowStatusGuid uniqueidentifier NOT NULL,
        GroupID int NOT NULL,
        CanAction bit NOT NULL,
        CONSTRAINT PK_WorkflowCleanupBackup_WorkflowStatusNotificationGroups PRIMARY KEY (RunGuid, ID)
    );
END;

IF OBJECT_ID(N'SCore.WorkflowCleanupBackup_WorkflowNotificationQueue', N'U') IS NULL
BEGIN
    CREATE TABLE SCore.WorkflowCleanupBackup_WorkflowNotificationQueue
    (
        RunGuid uniqueidentifier NOT NULL,
        ID bigint NOT NULL,
        StatusId int NOT NULL,
        CONSTRAINT PK_WorkflowCleanupBackup_WorkflowNotificationQueue PRIMARY KEY (RunGuid, ID)
    );
END;

IF OBJECT_ID(N'SCore.WorkflowCleanupBackup_WorkflowNotificationQueueErrorLog', N'U') IS NULL
BEGIN
    CREATE TABLE SCore.WorkflowCleanupBackup_WorkflowNotificationQueueErrorLog
    (
        RunGuid uniqueidentifier NOT NULL,
        ID int NOT NULL,
        StatusId int NULL,
        CONSTRAINT PK_WorkflowCleanupBackup_WorkflowNotificationQueueErrorLog PRIMARY KEY (RunGuid, ID)
    );
END;

IF OBJECT_ID(N'SCore.WorkflowCleanupBackup_DataObjects', N'U') IS NULL
BEGIN
    CREATE TABLE SCore.WorkflowCleanupBackup_DataObjects
    (
        RunGuid uniqueidentifier NOT NULL,
        Guid uniqueidentifier NOT NULL,
        RowStatus tinyint NOT NULL,
        EntityTypeId int NOT NULL,
        CONSTRAINT PK_WorkflowCleanupBackup_DataObjects PRIMARY KEY (RunGuid, Guid)
    );
END;

IF EXISTS (SELECT 1 FROM SCore.WorkflowCleanupRuns WHERE RunGuid = @CleanupRunGuid AND CompletedOnUtc IS NOT NULL)
BEGIN
    PRINT N'This cleanup run has already completed. No action taken.';
    RETURN;
END;

BEGIN TRANSACTION;

IF NOT EXISTS (SELECT 1 FROM SCore.WorkflowCleanupRuns WHERE RunGuid = @CleanupRunGuid)
BEGIN
    INSERT INTO SCore.WorkflowCleanupRuns
    (
        RunGuid,
        StartedOnUtc,
        CompletedOnUtc,
        ScriptName,
        Notes
    )
    VALUES
    (
        @CleanupRunGuid,
        @StartedOnUtc,
        NULL,
        N'02_Apply_WorkflowCleanup.sql',
        N'CymBuild workflow duplicate and hidden-row rationalisation from UAT export.'
    );
END;

DECLARE @StatusMap TABLE
(
    OldStatusID int NOT NULL PRIMARY KEY,
    NewStatusID int NOT NULL,
    Reason nvarchar(400) NOT NULL
);

INSERT INTO @StatusMap (OldStatusID, NewStatusID, Reason)
VALUES
    (37, 3,  N'Duplicate Declined'),
    (53, 8,  N'Duplicate Rejected'),
    (52, 14, N'Duplicate Ready to Send'),
    (29, 50, N'Duplicate Quoting'),
    (33, 48, N'Duplicate New'),
    (41, 14, N'Hidden duplicate Ready to Send');

DECLARE @RetireTransition TABLE
(
    WorkflowTransitionID int NOT NULL PRIMARY KEY,
    RetainedWorkflowTransitionID int NOT NULL,
    Reason nvarchar(400) NOT NULL
);

INSERT INTO @RetireTransition (WorkflowTransitionID, RetainedWorkflowTransitionID, Reason)
VALUES
    (395, 242, N'Duplicate active transition'),
    (349, 284, N'Duplicate active transition'),
    (439, 423, N'Duplicate active transition');

DECLARE @DeletedDataObjectGuids TABLE
(
    Guid uniqueidentifier NOT NULL PRIMARY KEY,
    SourceTable sysname NOT NULL,
    SourceID int NOT NULL
);

/* Back up rows before mutation. */
INSERT INTO SCore.WorkflowCleanupBackup_DataObjectTransition
(
    RunGuid,
    ID,
    StatusID,
    OldStatusID
)
SELECT
    @CleanupRunGuid,
    dot.ID,
    dot.StatusID,
    dot.OldStatusID
FROM SCore.DataObjectTransition AS dot
WHERE (dot.StatusID IN (SELECT sm.OldStatusID FROM @StatusMap AS sm)
    OR dot.OldStatusID IN (SELECT sm.OldStatusID FROM @StatusMap AS sm))
  AND NOT EXISTS
  (
      SELECT 1
      FROM SCore.WorkflowCleanupBackup_DataObjectTransition AS b
      WHERE b.RunGuid = @CleanupRunGuid
        AND b.ID = dot.ID
  );

INSERT INTO SCore.WorkflowCleanupBackup_WorkflowTransition
(
    RunGuid,
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
    @CleanupRunGuid,
    wt.ID,
    wt.RowStatus,
    wt.Guid,
    wt.WorkflowID,
    wt.FromStatusID,
    wt.ToStatusID,
    wt.IsFinal,
    wt.Enabled,
    wt.SortOrder,
    wt.Description
FROM SCore.WorkflowTransition AS wt
WHERE wt.RowStatus = 254
   OR wt.ID IN (SELECT rt.WorkflowTransitionID FROM @RetireTransition AS rt)
   OR wt.FromStatusID IN (SELECT sm.OldStatusID FROM @StatusMap AS sm)
   OR wt.ToStatusID IN (SELECT sm.OldStatusID FROM @StatusMap AS sm)
   OR wt.WorkflowID IN (SELECT wf.ID FROM SCore.Workflow AS wf WHERE wf.RowStatus = 254)
  AND NOT EXISTS
  (
      SELECT 1
      FROM SCore.WorkflowCleanupBackup_WorkflowTransition AS b
      WHERE b.RunGuid = @CleanupRunGuid
        AND b.ID = wt.ID
  );

INSERT INTO SCore.WorkflowCleanupBackup_WorkflowStatus
(
    RunGuid,
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
    @CleanupRunGuid,
    ws.ID,
    ws.RowStatus,
    ws.Guid,
    ws.OrganisationalUnitId,
    ws.Name,
    ws.Description,
    ws.ShowInEnquiries,
    ws.ShowInQuotes,
    ws.ShowInJobs,
    ws.Enabled,
    ws.IsPredefined,
    ws.SortOrder,
    ws.Colour,
    ws.Icon,
    ws.SendNotification,
    ws.IsCompleteStatus,
    ws.IsCustomerWaitingStatus,
    ws.RequiresUsersAction,
    ws.IsActiveStatus,
    ws.AuthorisationNeeded,
    ws.IsAuthStatus
FROM SCore.WorkflowStatus AS ws
WHERE ws.ID IN (3,8,14,48,50)
   OR ws.ID IN (SELECT sm.OldStatusID FROM @StatusMap AS sm)
   OR ws.RowStatus = 254
  AND NOT EXISTS
  (
      SELECT 1
      FROM SCore.WorkflowCleanupBackup_WorkflowStatus AS b
      WHERE b.RunGuid = @CleanupRunGuid
        AND b.ID = ws.ID
  );

INSERT INTO SCore.WorkflowCleanupBackup_Workflow
(
    RunGuid,
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
    @CleanupRunGuid,
    wf.ID,
    wf.RowStatus,
    wf.Guid,
    wf.OrganisationalUnitId,
    wf.EntityTypeID,
    wf.EntityHoBTID,
    wf.Name,
    wf.Description,
    wf.Enabled
FROM SCore.Workflow AS wf
WHERE wf.RowStatus = 254
  AND NOT EXISTS
  (
      SELECT 1
      FROM SCore.WorkflowCleanupBackup_Workflow AS b
      WHERE b.RunGuid = @CleanupRunGuid
        AND b.ID = wf.ID
  );

INSERT INTO SCore.WorkflowCleanupBackup_WorkflowStatusNotificationGroups
(
    RunGuid,
    ID,
    RowStatus,
    Guid,
    WorkflowID,
    WorkflowStatusGuid,
    GroupID,
    CanAction
)
SELECT
    @CleanupRunGuid,
    ng.ID,
    ng.RowStatus,
    ng.Guid,
    ng.WorkflowID,
    ng.WorkflowStatusGuid,
    ng.GroupID,
    ng.CanAction
FROM SCore.WorkflowStatusNotificationGroups AS ng
LEFT JOIN SCore.WorkflowStatus AS ws
    ON ws.Guid = ng.WorkflowStatusGuid
WHERE ng.ID <> -1
  AND (ng.RowStatus = 254
       OR ws.ID IN (SELECT sm.OldStatusID FROM @StatusMap AS sm))
  AND NOT EXISTS
  (
      SELECT 1
      FROM SCore.WorkflowCleanupBackup_WorkflowStatusNotificationGroups AS b
      WHERE b.RunGuid = @CleanupRunGuid
        AND b.ID = ng.ID
  );

INSERT INTO SCore.WorkflowCleanupBackup_WorkflowNotificationQueue
(
    RunGuid,
    ID,
    StatusId
)
SELECT
    @CleanupRunGuid,
    q.ID,
    q.StatusId
FROM SCore.WorkflowNotificationQueue AS q
WHERE q.StatusId IN (SELECT sm.OldStatusID FROM @StatusMap AS sm)
  AND NOT EXISTS
  (
      SELECT 1
      FROM SCore.WorkflowCleanupBackup_WorkflowNotificationQueue AS b
      WHERE b.RunGuid = @CleanupRunGuid
        AND b.ID = q.ID
  );

INSERT INTO SCore.WorkflowCleanupBackup_WorkflowNotificationQueueErrorLog
(
    RunGuid,
    ID,
    StatusId
)
SELECT
    @CleanupRunGuid,
    el.ID,
    el.StatusId
FROM SCore.WorkflowNotificationQueueErrorLog AS el
WHERE el.StatusId IN (SELECT sm.OldStatusID FROM @StatusMap AS sm)
  AND NOT EXISTS
  (
      SELECT 1
      FROM SCore.WorkflowCleanupBackup_WorkflowNotificationQueueErrorLog AS b
      WHERE b.RunGuid = @CleanupRunGuid
        AND b.ID = el.ID
  );

/* Align retained status visibility required by the merged duplicate rows. */
UPDATE ws
SET
    ShowInEnquiries = CASE WHEN ws.ID IN (8,14) THEN CONVERT(bit,1) ELSE ws.ShowInEnquiries END,
    ShowInQuotes = CASE WHEN ws.ID IN (8,14,48,50) THEN CONVERT(bit,1) ELSE ws.ShowInQuotes END,
    ShowInJobs = CASE WHEN ws.ID = 48 THEN CONVERT(bit,1) ELSE ws.ShowInJobs END,
    Enabled = CONVERT(bit,1),
    RowStatus = CONVERT(tinyint,1)
FROM SCore.WorkflowStatus AS ws
WHERE ws.ID IN (3,8,14,48,50);

/* Migrate workflow history references. Rows are preserved. */
UPDATE dot
SET StatusID = sm.NewStatusID
FROM SCore.DataObjectTransition AS dot
JOIN @StatusMap AS sm
    ON sm.OldStatusID = dot.StatusID;

UPDATE dot
SET OldStatusID = sm.NewStatusID
FROM SCore.DataObjectTransition AS dot
JOIN @StatusMap AS sm
    ON sm.OldStatusID = dot.OldStatusID;

/* Migrate workflow configuration references. */
UPDATE wt
SET FromStatusID = sm.NewStatusID
FROM SCore.WorkflowTransition AS wt
JOIN @StatusMap AS sm
    ON sm.OldStatusID = wt.FromStatusID;

UPDATE wt
SET ToStatusID = sm.NewStatusID
FROM SCore.WorkflowTransition AS wt
JOIN @StatusMap AS sm
    ON sm.OldStatusID = wt.ToStatusID;

UPDATE q
SET StatusId = sm.NewStatusID
FROM SCore.WorkflowNotificationQueue AS q
JOIN @StatusMap AS sm
    ON sm.OldStatusID = q.StatusId;

UPDATE el
SET StatusId = sm.NewStatusID
FROM SCore.WorkflowNotificationQueueErrorLog AS el
JOIN @StatusMap AS sm
    ON sm.OldStatusID = el.StatusId;

/* Remove notification-group rows that would duplicate an existing target row after status-GUID migration. */
;WITH StatusGuidMap AS
(
    SELECT
        oldStatus.Guid AS OldStatusGuid,
        newStatus.Guid AS NewStatusGuid
    FROM @StatusMap AS sm
    JOIN SCore.WorkflowStatus AS oldStatus
        ON oldStatus.ID = sm.OldStatusID
    JOIN SCore.WorkflowStatus AS newStatus
        ON newStatus.ID = sm.NewStatusID
), DuplicateNotificationGroups AS
(
    SELECT
        oldNg.ID
    FROM SCore.WorkflowStatusNotificationGroups AS oldNg
    JOIN StatusGuidMap AS sgm
        ON sgm.OldStatusGuid = oldNg.WorkflowStatusGuid
    JOIN SCore.WorkflowStatusNotificationGroups AS targetNg
        ON targetNg.WorkflowID = oldNg.WorkflowID
       AND targetNg.WorkflowStatusGuid = sgm.NewStatusGuid
       AND targetNg.GroupID = oldNg.GroupID
       AND targetNg.CanAction = oldNg.CanAction
       AND targetNg.RowStatus NOT IN (0,254)
    WHERE oldNg.ID <> -1
      AND targetNg.ID <> -1
      AND oldNg.RowStatus NOT IN (0,254)
)
DELETE ng
OUTPUT deleted.Guid, N'SCore.WorkflowStatusNotificationGroups', deleted.ID
INTO @DeletedDataObjectGuids (Guid, SourceTable, SourceID)
FROM SCore.WorkflowStatusNotificationGroups AS ng
JOIN DuplicateNotificationGroups AS dng
    ON dng.ID = ng.ID;

;WITH StatusGuidMap AS
(
    SELECT
        oldStatus.Guid AS OldStatusGuid,
        newStatus.Guid AS NewStatusGuid
    FROM @StatusMap AS sm
    JOIN SCore.WorkflowStatus AS oldStatus
        ON oldStatus.ID = sm.OldStatusID
    JOIN SCore.WorkflowStatus AS newStatus
        ON newStatus.ID = sm.NewStatusID
)
UPDATE ng
SET WorkflowStatusGuid = sgm.NewStatusGuid
FROM SCore.WorkflowStatusNotificationGroups AS ng
JOIN StatusGuidMap AS sgm
    ON sgm.OldStatusGuid = ng.WorkflowStatusGuid
WHERE ng.ID <> -1;

/* Protected sentinel notification-group rows (ID = -1) must never be updated or deleted. */

/* Delete hidden and duplicate workflow transition configuration. */
DELETE wt
OUTPUT deleted.Guid, N'SCore.WorkflowTransition', deleted.ID
INTO @DeletedDataObjectGuids (Guid, SourceTable, SourceID)
FROM SCore.WorkflowTransition AS wt
WHERE wt.RowStatus = 254
   OR wt.ID IN (SELECT rt.WorkflowTransitionID FROM @RetireTransition AS rt);

/* Delete hidden notification-group configuration. */
DELETE ng
OUTPUT deleted.Guid, N'SCore.WorkflowStatusNotificationGroups', deleted.ID
INTO @DeletedDataObjectGuids (Guid, SourceTable, SourceID)
FROM SCore.WorkflowStatusNotificationGroups AS ng
WHERE ng.RowStatus = 254
  AND ng.ID <> -1;

/* Validate duplicate status rows are no longer referenced before deletion. */
IF EXISTS
(
    SELECT 1
    FROM SCore.DataObjectTransition AS dot
    WHERE dot.StatusID IN (SELECT sm.OldStatusID FROM @StatusMap AS sm)
       OR dot.OldStatusID IN (SELECT sm.OldStatusID FROM @StatusMap AS sm)
)
BEGIN
    THROW 61001, N'Duplicate WorkflowStatus rows are still referenced by SCore.DataObjectTransition.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM SCore.WorkflowTransition AS wt
    WHERE wt.FromStatusID IN (SELECT sm.OldStatusID FROM @StatusMap AS sm)
       OR wt.ToStatusID IN (SELECT sm.OldStatusID FROM @StatusMap AS sm)
)
BEGIN
    THROW 61002, N'Duplicate WorkflowStatus rows are still referenced by SCore.WorkflowTransition.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM SCore.WorkflowNotificationQueue AS q
    WHERE q.StatusId IN (SELECT sm.OldStatusID FROM @StatusMap AS sm)
)
BEGIN
    THROW 61003, N'Duplicate WorkflowStatus rows are still referenced by SCore.WorkflowNotificationQueue.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM SCore.WorkflowNotificationQueueErrorLog AS el
    WHERE el.StatusId IN (SELECT sm.OldStatusID FROM @StatusMap AS sm)
)
BEGIN
    THROW 61004, N'Duplicate WorkflowStatus rows are still referenced by SCore.WorkflowNotificationQueueErrorLog.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM SCore.WorkflowStatusNotificationGroups AS ng
    JOIN SCore.WorkflowStatus AS ws
        ON ws.Guid = ng.WorkflowStatusGuid
    WHERE ws.ID IN (SELECT sm.OldStatusID FROM @StatusMap AS sm)
)
BEGIN
    THROW 61005, N'Duplicate WorkflowStatus rows are still referenced by SCore.WorkflowStatusNotificationGroups.', 1;
END;

DELETE ws
OUTPUT deleted.Guid, N'SCore.WorkflowStatus', deleted.ID
INTO @DeletedDataObjectGuids (Guid, SourceTable, SourceID)
FROM SCore.WorkflowStatus AS ws
WHERE ws.ID IN (SELECT sm.OldStatusID FROM @StatusMap AS sm);

/* Delete hidden workflows once transitions and notification groups no longer reference them. */
IF EXISTS
(
    SELECT 1
    FROM SCore.Workflow AS wf
    WHERE wf.RowStatus = 254
      AND EXISTS
      (
          SELECT 1
          FROM SCore.WorkflowTransition AS wt
          WHERE wt.WorkflowID = wf.ID
      )
)
BEGIN
    THROW 61006, N'Hidden workflows are still referenced by SCore.WorkflowTransition.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM SCore.Workflow AS wf
    WHERE wf.RowStatus = 254
      AND EXISTS
      (
          SELECT 1
          FROM SCore.WorkflowStatusNotificationGroups AS ng
          WHERE ng.ID <> -1
            AND ng.WorkflowID = wf.ID
      )
)
BEGIN
    THROW 61007, N'Hidden workflows are still referenced by SCore.WorkflowStatusNotificationGroups.', 1;
END;

DELETE wf
OUTPUT deleted.Guid, N'SCore.Workflow', deleted.ID
INTO @DeletedDataObjectGuids (Guid, SourceTable, SourceID)
FROM SCore.Workflow AS wf
WHERE wf.RowStatus = 254;

/* Back up and delete DataObjects for physically removed configuration rows, but only where no history/security references remain. */
IF OBJECT_ID(N'SCore.ObjectSecurity', N'U') IS NOT NULL
   AND COL_LENGTH(N'SCore.ObjectSecurity', N'RecordGuid') IS NOT NULL
   AND EXISTS
   (
       SELECT 1
       FROM SCore.ObjectSecurity AS os
       JOIN @DeletedDataObjectGuids AS ddog
           ON ddog.Guid = os.RecordGuid
   )
BEGIN
    THROW 61008, N'Deleted workflow configuration GUIDs are still referenced by SCore.ObjectSecurity.RecordGuid. Review before deleting SCore.DataObjects rows.', 1;
END;

INSERT INTO SCore.WorkflowCleanupBackup_DataObjects
(
    RunGuid,
    Guid,
    RowStatus,
    EntityTypeId
)
SELECT
    @CleanupRunGuid,
    dob.Guid,
    dob.RowStatus,
    dob.EntityTypeId
FROM SCore.DataObjects AS dob
JOIN @DeletedDataObjectGuids AS ddog
    ON ddog.Guid = dob.Guid
WHERE NOT EXISTS
(
    SELECT 1
    FROM SCore.WorkflowCleanupBackup_DataObjects AS b
    WHERE b.RunGuid = @CleanupRunGuid
      AND b.Guid = dob.Guid
);

DELETE dob
FROM SCore.DataObjects AS dob
JOIN @DeletedDataObjectGuids AS ddog
    ON ddog.Guid = dob.Guid
WHERE NOT EXISTS
(
    SELECT 1
    FROM SCore.DataObjectTransition AS dot
    WHERE dot.DataObjectGuid = dob.Guid
);

/* Final in-transaction validation. */
IF EXISTS
(
    SELECT 1
    FROM SCore.WorkflowStatus AS ws
    WHERE ws.ID IN (37,53,52,29,33,41)
)
BEGIN
    THROW 61009, N'Duplicate WorkflowStatus rows still exist after cleanup.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM SCore.Workflow AS wf
    WHERE wf.RowStatus = 254
)
BEGIN
    THROW 61010, N'Hidden Workflow rows still exist after cleanup.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM SCore.WorkflowTransition AS wt
    WHERE wt.RowStatus = 254
       OR wt.ID IN (395,349,439)
)
BEGIN
    THROW 61011, N'Hidden or duplicate WorkflowTransition rows still exist after cleanup.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM SCore.WorkflowStatusNotificationGroups AS ng
    WHERE ng.RowStatus = 254
      AND ng.ID <> -1
)
BEGIN
    THROW 61012, N'Hidden WorkflowStatusNotificationGroups rows still exist after cleanup.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM SCore.WorkflowStatusNotificationGroups AS ng
    LEFT JOIN SCore.WorkflowStatus AS ws
        ON ws.Guid = ng.WorkflowStatusGuid
    WHERE ng.ID <> -1
      AND ws.ID IS NULL
)
BEGIN
    THROW 61013, N'WorkflowStatusNotificationGroups contains orphan WorkflowStatusGuid values.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM
    (
        SELECT
            ws.Name,
            COUNT_BIG(1) AS ActiveCount
        FROM SCore.WorkflowStatus AS ws
        WHERE ws.RowStatus NOT IN (0,254)
        GROUP BY ws.Name
        HAVING COUNT_BIG(1) > 1
    ) AS ActiveStatusNameDupes
)
BEGIN
    THROW 61014, N'Active duplicate WorkflowStatus names still exist after cleanup.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM
    (
        SELECT
            wt.WorkflowID,
            wt.FromStatusID,
            wt.ToStatusID,
            COUNT_BIG(1) AS ActiveCount
        FROM SCore.WorkflowTransition AS wt
        WHERE wt.RowStatus NOT IN (0,254)
        GROUP BY wt.WorkflowID, wt.FromStatusID, wt.ToStatusID
        HAVING COUNT_BIG(1) > 1
    ) AS ActiveTransitionDupes
)
BEGIN
    THROW 61015, N'Active duplicate WorkflowTransition keys still exist after cleanup.', 1;
END;

UPDATE SCore.WorkflowCleanupRuns
SET CompletedOnUtc = SYSUTCDATETIME()
WHERE RunGuid = @CleanupRunGuid;

COMMIT TRANSACTION;

PRINT N'Workflow cleanup completed successfully.';
PRINT CONCAT(N'Rollback RunGuid: ', CONVERT(nvarchar(36), @CleanupRunGuid));

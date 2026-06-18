/*
    CymBuild Workflow Active State Validation
    Purpose:
      - Evidence the cleaned UAT workflow configuration.
      - Prove active statuses/transitions/notification groups are consistent.
      - Show latest/current runtime status distribution without mutating workflow history.
      - Identify anything that must be fixed before using UAT as the source for DEV workflow config replacement.

    Rules:
      - Read-only.
      - SQL Server only.
      - Explicit columns only.
      - Treat SCore.DataObjectTransition as audit/history. Do not delete or rewrite history here.
      - Active row convention: RowStatus NOT IN (0,254).
*/

SET NOCOUNT ON;

DECLARE @ReadyToSendGuid uniqueidentifier = CONVERT(uniqueidentifier, N'02A2237F-2AE7-4E05-926F-38E8B7D050A0');

PRINT N'============================================================';
PRINT N'01. Workflow cleanup summary counts';
PRINT N'============================================================';

SELECT
    N'SCore.Workflow' AS ObjectName,
    COUNT_BIG(1) AS TotalRows,
    SUM(CASE WHEN w.RowStatus NOT IN (0,254) THEN 1 ELSE 0 END) AS ActiveRows,
    SUM(CASE WHEN w.RowStatus = 254 THEN 1 ELSE 0 END) AS HiddenRows,
    SUM(CASE WHEN w.RowStatus = 0 THEN 1 ELSE 0 END) AS DeletedRows
FROM SCore.Workflow AS w
UNION ALL
SELECT
    N'SCore.WorkflowStatus' AS ObjectName,
    COUNT_BIG(1) AS TotalRows,
    SUM(CASE WHEN ws.RowStatus NOT IN (0,254) THEN 1 ELSE 0 END) AS ActiveRows,
    SUM(CASE WHEN ws.RowStatus = 254 THEN 1 ELSE 0 END) AS HiddenRows,
    SUM(CASE WHEN ws.RowStatus = 0 THEN 1 ELSE 0 END) AS DeletedRows
FROM SCore.WorkflowStatus AS ws
UNION ALL
SELECT
    N'SCore.WorkflowTransition' AS ObjectName,
    COUNT_BIG(1) AS TotalRows,
    SUM(CASE WHEN wt.RowStatus NOT IN (0,254) THEN 1 ELSE 0 END) AS ActiveRows,
    SUM(CASE WHEN wt.RowStatus = 254 THEN 1 ELSE 0 END) AS HiddenRows,
    SUM(CASE WHEN wt.RowStatus = 0 THEN 1 ELSE 0 END) AS DeletedRows
FROM SCore.WorkflowTransition AS wt
UNION ALL
SELECT
    N'SCore.WorkflowStatusNotificationGroups' AS ObjectName,
    COUNT_BIG(1) AS TotalRows,
    SUM(CASE WHEN wsng.RowStatus NOT IN (0,254) THEN 1 ELSE 0 END) AS ActiveRows,
    SUM(CASE WHEN wsng.RowStatus = 254 THEN 1 ELSE 0 END) AS HiddenRows,
    SUM(CASE WHEN wsng.RowStatus = 0 THEN 1 ELSE 0 END) AS DeletedRows
FROM SCore.WorkflowStatusNotificationGroups AS wsng
UNION ALL
SELECT
    N'SCore.DataObjectTransition' AS ObjectName,
    COUNT_BIG(1) AS TotalRows,
    SUM(CASE WHEN dot.RowStatus NOT IN (0,254) THEN 1 ELSE 0 END) AS ActiveRows,
    SUM(CASE WHEN dot.RowStatus = 254 THEN 1 ELSE 0 END) AS HiddenRows,
    SUM(CASE WHEN dot.RowStatus = 0 THEN 1 ELSE 0 END) AS DeletedRows
FROM SCore.DataObjectTransition AS dot;

PRINT N'============================================================';
PRINT N'02. Active workflow list';
PRINT N'============================================================';

SELECT
    w.ID AS WorkflowID,
    w.Guid AS WorkflowGuid,
    w.Name AS WorkflowName,
    w.OrganisationalUnitId,
    w.EntityTypeID,
    et.Name AS EntityTypeName,
    w.EntityHoBTID,
    w.Enabled,
    w.RowStatus,
    COUNT(wt.ID) AS ActiveTransitionCount
FROM SCore.Workflow AS w
LEFT JOIN SCore.EntityTypes AS et
    ON et.ID = w.EntityTypeID
LEFT JOIN SCore.WorkflowTransition AS wt
    ON wt.WorkflowID = w.ID
    AND wt.RowStatus NOT IN (0,254)
WHERE w.RowStatus NOT IN (0,254)
GROUP BY
    w.ID,
    w.Guid,
    w.Name,
    w.OrganisationalUnitId,
    w.EntityTypeID,
    et.Name,
    w.EntityHoBTID,
    w.Enabled,
    w.RowStatus
ORDER BY
    et.Name,
    w.Name,
    w.ID;

PRINT N'============================================================';
PRINT N'03. Active workflow statuses';
PRINT N'============================================================';

SELECT
    ws.ID AS WorkflowStatusID,
    ws.Guid AS WorkflowStatusGuid,
    ws.Name AS WorkflowStatusName,
    ws.Description,
    ws.SortOrder,
    ws.Enabled,
    ws.IsPredefined,
    ws.ShowInEnquiries,
    ws.ShowInQuotes,
    ws.ShowInJobs,
    ws.IsActiveStatus,
    ws.IsCompleteStatus,
    ws.RequiresUsersAction,
    ws.AuthorisationNeeded,
    ws.IsAuthStatus,
    ws.SendNotification,
    ws.RowStatus
FROM SCore.WorkflowStatus AS ws
WHERE ws.RowStatus NOT IN (0,254)
ORDER BY
    ws.SortOrder,
    ws.Name,
    ws.ID;

PRINT N'============================================================';
PRINT N'04. Active transition graph';
PRINT N'============================================================';

SELECT
    w.ID AS WorkflowID,
    w.Guid AS WorkflowGuid,
    w.Name AS WorkflowName,
    et.Name AS EntityTypeName,
    wt.ID AS WorkflowTransitionID,
    wt.Guid AS WorkflowTransitionGuid,
    wt.SortOrder,
    wt.Enabled,
    wt.IsFinal,
    wt.FromStatusID,
    fromWs.Guid AS FromStatusGuid,
    fromWs.Name AS FromStatusName,
    wt.ToStatusID,
    toWs.Guid AS ToStatusGuid,
    toWs.Name AS ToStatusName,
    wt.Description,
    wt.RowStatus
FROM SCore.WorkflowTransition AS wt
INNER JOIN SCore.Workflow AS w
    ON w.ID = wt.WorkflowID
INNER JOIN SCore.WorkflowStatus AS fromWs
    ON fromWs.ID = wt.FromStatusID
INNER JOIN SCore.WorkflowStatus AS toWs
    ON toWs.ID = wt.ToStatusID
LEFT JOIN SCore.EntityTypes AS et
    ON et.ID = w.EntityTypeID
WHERE wt.RowStatus NOT IN (0,254)
  AND w.RowStatus NOT IN (0,254)
  AND fromWs.RowStatus NOT IN (0,254)
  AND toWs.RowStatus NOT IN (0,254)
ORDER BY
    et.Name,
    w.Name,
    wt.SortOrder,
    wt.ID;

PRINT N'============================================================';
PRINT N'05. Active transition matrix / next-state view';
PRINT N'============================================================';

SELECT
    w.ID AS WorkflowID,
    w.Name AS WorkflowName,
    fromWs.ID AS FromStatusID,
    fromWs.Name AS FromStatusName,
    COUNT(wt.ID) AS ActiveNextTransitionCount,
    STRING_AGG(CONCAT(CONVERT(nvarchar(20), toWs.ID), N': ', toWs.Name), N' | ') WITHIN GROUP (ORDER BY wt.SortOrder, wt.ID) AS ActiveNextStatuses
FROM SCore.Workflow AS w
INNER JOIN SCore.WorkflowTransition AS wt
    ON wt.WorkflowID = w.ID
    AND wt.RowStatus NOT IN (0,254)
INNER JOIN SCore.WorkflowStatus AS fromWs
    ON fromWs.ID = wt.FromStatusID
    AND fromWs.RowStatus NOT IN (0,254)
INNER JOIN SCore.WorkflowStatus AS toWs
    ON toWs.ID = wt.ToStatusID
    AND toWs.RowStatus NOT IN (0,254)
WHERE w.RowStatus NOT IN (0,254)
GROUP BY
    w.ID,
    w.Name,
    fromWs.ID,
    fromWs.Name
ORDER BY
    w.Name,
    fromWs.Name;

PRINT N'============================================================';
PRINT N'06. Blocking validation checks - expected zero rows unless noted';
PRINT N'============================================================';

PRINT N'06a. Active duplicate WorkflowStatus names - expected zero rows';
SELECT
    LTRIM(RTRIM(LOWER(ws.Name))) AS NormalisedStatusName,
    COUNT_BIG(1) AS ActiveCount,
    STRING_AGG(CONCAT(CONVERT(nvarchar(20), ws.ID), N':', CONVERT(nvarchar(36), ws.Guid)), N', ') WITHIN GROUP (ORDER BY ws.ID) AS ActiveStatusIdsAndGuids
FROM SCore.WorkflowStatus AS ws
WHERE ws.RowStatus NOT IN (0,254)
GROUP BY LTRIM(RTRIM(LOWER(ws.Name)))
HAVING COUNT_BIG(1) > 1
ORDER BY LTRIM(RTRIM(LOWER(ws.Name)));

PRINT N'06b. Active duplicate WorkflowStatus GUIDs - expected zero rows';
SELECT
    ws.Guid AS WorkflowStatusGuid,
    COUNT_BIG(1) AS ActiveCount,
    STRING_AGG(CONVERT(nvarchar(20), ws.ID), N', ') WITHIN GROUP (ORDER BY ws.ID) AS WorkflowStatusIDs
FROM SCore.WorkflowStatus AS ws
WHERE ws.RowStatus NOT IN (0,254)
GROUP BY ws.Guid
HAVING COUNT_BIG(1) > 1
ORDER BY ws.Guid;

PRINT N'06c. Active duplicate WorkflowTransition keys - expected zero rows';
SELECT
    wt.WorkflowID,
    wt.FromStatusID,
    fromWs.Name AS FromStatusName,
    wt.ToStatusID,
    toWs.Name AS ToStatusName,
    COUNT_BIG(1) AS ActiveCount,
    STRING_AGG(CONVERT(nvarchar(20), wt.ID), N', ') WITHIN GROUP (ORDER BY wt.ID) AS WorkflowTransitionIDs
FROM SCore.WorkflowTransition AS wt
LEFT JOIN SCore.WorkflowStatus AS fromWs
    ON fromWs.ID = wt.FromStatusID
LEFT JOIN SCore.WorkflowStatus AS toWs
    ON toWs.ID = wt.ToStatusID
WHERE wt.RowStatus NOT IN (0,254)
GROUP BY
    wt.WorkflowID,
    wt.FromStatusID,
    fromWs.Name,
    wt.ToStatusID,
    toWs.Name
HAVING COUNT_BIG(1) > 1
ORDER BY
    wt.WorkflowID,
    wt.FromStatusID,
    wt.ToStatusID;

PRINT N'06d. Active transitions referencing inactive/missing workflow/status rows - expected zero rows';
SELECT
    wt.ID AS WorkflowTransitionID,
    wt.Guid AS WorkflowTransitionGuid,
    wt.WorkflowID,
    w.RowStatus AS WorkflowRowStatus,
    wt.FromStatusID,
    fromWs.RowStatus AS FromStatusRowStatus,
    wt.ToStatusID,
    toWs.RowStatus AS ToStatusRowStatus,
    CASE
        WHEN w.ID IS NULL THEN N'Missing workflow'
        WHEN w.RowStatus IN (0,254) THEN N'Inactive workflow'
        WHEN fromWs.ID IS NULL THEN N'Missing from status'
        WHEN fromWs.RowStatus IN (0,254) THEN N'Inactive from status'
        WHEN toWs.ID IS NULL THEN N'Missing to status'
        WHEN toWs.RowStatus IN (0,254) THEN N'Inactive to status'
        ELSE N'Unknown'
    END AS FailureReason
FROM SCore.WorkflowTransition AS wt
LEFT JOIN SCore.Workflow AS w
    ON w.ID = wt.WorkflowID
LEFT JOIN SCore.WorkflowStatus AS fromWs
    ON fromWs.ID = wt.FromStatusID
LEFT JOIN SCore.WorkflowStatus AS toWs
    ON toWs.ID = wt.ToStatusID
WHERE wt.RowStatus NOT IN (0,254)
  AND
  (
      w.ID IS NULL
      OR w.RowStatus IN (0,254)
      OR fromWs.ID IS NULL
      OR fromWs.RowStatus IN (0,254)
      OR toWs.ID IS NULL
      OR toWs.RowStatus IN (0,254)
  )
ORDER BY wt.ID;

PRINT N'06e. Active notification groups referencing inactive/missing workflow/status rows - expected zero rows except protected ID = -1 if present';
SELECT
    wsng.ID AS WorkflowStatusNotificationGroupID,
    wsng.Guid AS WorkflowStatusNotificationGroupGuid,
    wsng.WorkflowID,
    w.RowStatus AS WorkflowRowStatus,
    wsng.WorkflowStatusGuid,
    ws.ID AS WorkflowStatusID,
    ws.RowStatus AS WorkflowStatusRowStatus,
    wsng.GroupID,
    wsng.CanAction,
    CASE
        WHEN wsng.ID = -1 THEN N'Protected sentinel - review only'
        WHEN w.ID IS NULL THEN N'Missing workflow'
        WHEN w.RowStatus IN (0,254) THEN N'Inactive workflow'
        WHEN ws.ID IS NULL THEN N'Missing workflow status by GUID'
        WHEN ws.RowStatus IN (0,254) THEN N'Inactive workflow status by GUID'
        ELSE N'Unknown'
    END AS Finding
FROM SCore.WorkflowStatusNotificationGroups AS wsng
LEFT JOIN SCore.Workflow AS w
    ON w.ID = wsng.WorkflowID
LEFT JOIN SCore.WorkflowStatus AS ws
    ON ws.Guid = wsng.WorkflowStatusGuid
WHERE wsng.RowStatus NOT IN (0,254)
  AND
  (
      wsng.ID = -1
      OR w.ID IS NULL
      OR w.RowStatus IN (0,254)
      OR ws.ID IS NULL
      OR ws.RowStatus IN (0,254)
  )
ORDER BY wsng.ID;

PRINT N'06f. Hidden workflow config rows remaining - expected zero rows after complete cleanup, excluding audit/history tables';
SELECT
    N'SCore.Workflow' AS ObjectName,
    w.ID AS RecordID,
    w.Guid AS RecordGuid,
    w.Name AS RecordName,
    w.RowStatus
FROM SCore.Workflow AS w
WHERE w.RowStatus = 254
UNION ALL
SELECT
    N'SCore.WorkflowStatus' AS ObjectName,
    ws.ID AS RecordID,
    ws.Guid AS RecordGuid,
    ws.Name AS RecordName,
    ws.RowStatus
FROM SCore.WorkflowStatus AS ws
WHERE ws.RowStatus = 254
UNION ALL
SELECT
    N'SCore.WorkflowTransition' AS ObjectName,
    wt.ID AS RecordID,
    wt.Guid AS RecordGuid,
    CONCAT(CONVERT(nvarchar(20), wt.WorkflowID), N': ', CONVERT(nvarchar(20), wt.FromStatusID), N' -> ', CONVERT(nvarchar(20), wt.ToStatusID)) AS RecordName,
    wt.RowStatus
FROM SCore.WorkflowTransition AS wt
WHERE wt.RowStatus = 254
UNION ALL
SELECT
    N'SCore.WorkflowStatusNotificationGroups' AS ObjectName,
    wsng.ID AS RecordID,
    wsng.Guid AS RecordGuid,
    CONCAT(CONVERT(nvarchar(20), wsng.WorkflowID), N': ', CONVERT(nvarchar(36), wsng.WorkflowStatusGuid), N' / Group ', CONVERT(nvarchar(20), wsng.GroupID)) AS RecordName,
    wsng.RowStatus
FROM SCore.WorkflowStatusNotificationGroups AS wsng
WHERE wsng.RowStatus = 254
ORDER BY ObjectName, RecordID;

PRINT N'06g. Retired duplicate status references remaining - expected zero rows';
DECLARE @RetiredWorkflowStatus TABLE
(
    DuplicateID int NOT NULL PRIMARY KEY,
    DuplicateGuid uniqueidentifier NOT NULL,
    RetainedID int NOT NULL,
    RetainedGuid uniqueidentifier NOT NULL,
    Name nvarchar(100) NOT NULL
);

INSERT INTO @RetiredWorkflowStatus
(
    DuplicateID,
    DuplicateGuid,
    RetainedID,
    RetainedGuid,
    Name
)
VALUES
    (37, CONVERT(uniqueidentifier, N'b9ba4510-6358-4c0a-bba1-5feb33c54f84'), 3,  CONVERT(uniqueidentifier, N'708c00e6-f45f-4cb2-8e91-a80b8b8e802e'), N'Declined'),
    (53, CONVERT(uniqueidentifier, N'85b522aa-134c-4e6c-884a-ff7264d7dd2e'), 8,  CONVERT(uniqueidentifier, N'0a6a71f7-b39f-4213-997e-2b3a13b6144c'), N'Rejected'),
    (52, CONVERT(uniqueidentifier, N'5c9cd674-7520-44d2-9464-2a681f2f2ba4'), 14, CONVERT(uniqueidentifier, N'02a2237f-2ae7-4e05-926f-38e8b7d050a0'), N'Ready to Send'),
    (29, CONVERT(uniqueidentifier, N'b88f95c2-41c9-4cc6-ad9f-d9223c4e852a'), 50, CONVERT(uniqueidentifier, N'9a60f983-24ba-4733-907e-c5cce0b691cb'), N'Quoting'),
    (33, CONVERT(uniqueidentifier, N'9e0a10c7-94a0-4e25-afb1-14240d906c12'), 48, CONVERT(uniqueidentifier, N'3dab4339-a1c0-4abe-860a-4915a6cf94b6'), N'New'),
    (41, CONVERT(uniqueidentifier, N'6ed4279a-e299-4d33-8ed5-cb8b78b3f13d'), 14, CONVERT(uniqueidentifier, N'02a2237f-2ae7-4e05-926f-38e8b7d050a0'), N'Ready to Send');

SELECT
    r.Name AS RetiredStatusName,
    r.DuplicateID,
    r.DuplicateGuid,
    r.RetainedID,
    r.RetainedGuid,
    SourceTable.SourceTableName,
    SourceTable.ReferenceCount
FROM @RetiredWorkflowStatus AS r
CROSS APPLY
(
    SELECT
        N'SCore.WorkflowTransition.FromStatusID' AS SourceTableName,
        COUNT_BIG(1) AS ReferenceCount
    FROM SCore.WorkflowTransition AS wt
    WHERE wt.FromStatusID = r.DuplicateID
    UNION ALL
    SELECT
        N'SCore.WorkflowTransition.ToStatusID' AS SourceTableName,
        COUNT_BIG(1) AS ReferenceCount
    FROM SCore.WorkflowTransition AS wt
    WHERE wt.ToStatusID = r.DuplicateID
    UNION ALL
    SELECT
        N'SCore.DataObjectTransition.StatusID' AS SourceTableName,
        COUNT_BIG(1) AS ReferenceCount
    FROM SCore.DataObjectTransition AS dot
    WHERE dot.StatusID = r.DuplicateID
    UNION ALL
    SELECT
        N'SCore.DataObjectTransition.OldStatusID' AS SourceTableName,
        COUNT_BIG(1) AS ReferenceCount
    FROM SCore.DataObjectTransition AS dot
    WHERE dot.OldStatusID = r.DuplicateID
    UNION ALL
    SELECT
        N'SCore.WorkflowStatusNotificationGroups.WorkflowStatusGuid' AS SourceTableName,
        COUNT_BIG(1) AS ReferenceCount
    FROM SCore.WorkflowStatusNotificationGroups AS wsng
    WHERE wsng.WorkflowStatusGuid = r.DuplicateGuid
) AS SourceTable
WHERE SourceTable.ReferenceCount > 0
ORDER BY
    r.Name,
    r.DuplicateID,
    SourceTable.SourceTableName;

PRINT N'06h. Retired duplicate status rows still present - expected zero rows';
SELECT
    r.Name AS RetiredStatusName,
    r.DuplicateID,
    r.DuplicateGuid,
    ws.ID AS ExistingWorkflowStatusID,
    ws.Guid AS ExistingWorkflowStatusGuid,
    ws.RowStatus AS ExistingRowStatus
FROM @RetiredWorkflowStatus AS r
INNER JOIN SCore.WorkflowStatus AS ws
    ON ws.ID = r.DuplicateID
    OR ws.Guid = r.DuplicateGuid
ORDER BY r.DuplicateID;

PRINT N'06i. Ready to Send canonical GUID check - expected one active row, ID 14';
SELECT
    ws.ID AS WorkflowStatusID,
    ws.Guid AS WorkflowStatusGuid,
    ws.Name AS WorkflowStatusName,
    ws.RowStatus,
    ws.Enabled,
    ws.ShowInEnquiries,
    ws.ShowInQuotes,
    ws.ShowInJobs
FROM SCore.WorkflowStatus AS ws
WHERE ws.Guid = @ReadyToSendGuid
ORDER BY ws.ID;

PRINT N'06j. DataObjectTransition rows referencing missing WorkflowStatus rows - expected zero rows';
SELECT
    MissingRef.ReferenceColumn,
    MissingRef.MissingStatusID,
    COUNT_BIG(1) AS ReferenceCount
FROM
(
    SELECT
        N'StatusID' AS ReferenceColumn,
        dot.StatusID AS MissingStatusID
    FROM SCore.DataObjectTransition AS dot
    LEFT JOIN SCore.WorkflowStatus AS ws
        ON ws.ID = dot.StatusID
    WHERE dot.RowStatus NOT IN (0,254)
      AND ws.ID IS NULL
    UNION ALL
    SELECT
        N'OldStatusID' AS ReferenceColumn,
        dot.OldStatusID AS MissingStatusID
    FROM SCore.DataObjectTransition AS dot
    LEFT JOIN SCore.WorkflowStatus AS ws
        ON ws.ID = dot.OldStatusID
    WHERE dot.RowStatus NOT IN (0,254)
      AND dot.OldStatusID IS NOT NULL
      AND ws.ID IS NULL
) AS MissingRef
GROUP BY
    MissingRef.ReferenceColumn,
    MissingRef.MissingStatusID
ORDER BY
    MissingRef.ReferenceColumn,
    MissingRef.MissingStatusID;

PRINT N'============================================================';
PRINT N'07. Latest/current runtime status distribution';
PRINT N'============================================================';

;WITH LatestTransition AS
(
    SELECT
        dot.ID AS DataObjectTransitionID,
        dot.Guid AS DataObjectTransitionGuid,
        dot.DataObjectGuid,
        dot.StatusID,
        dot.OldStatusID,
        dot.DateTimeUTC,
        dot.CreatedByUserId,
        ROW_NUMBER() OVER
        (
            PARTITION BY dot.DataObjectGuid
            ORDER BY dot.DateTimeUTC DESC, dot.ID DESC
        ) AS LatestRank
    FROM SCore.DataObjectTransition AS dot
    WHERE dot.RowStatus NOT IN (0,254)
)
SELECT
    do.EntityTypeId,
    et.Name AS EntityTypeName,
    lt.StatusID AS CurrentWorkflowStatusID,
    ws.Guid AS CurrentWorkflowStatusGuid,
    ws.Name AS CurrentWorkflowStatusName,
    ws.RowStatus AS CurrentWorkflowStatusRowStatus,
    COUNT_BIG(1) AS CurrentObjectCount,
    MIN(lt.DateTimeUTC) AS EarliestLatestTransitionUtc,
    MAX(lt.DateTimeUTC) AS LatestLatestTransitionUtc
FROM LatestTransition AS lt
INNER JOIN SCore.DataObjects AS do
    ON do.Guid = lt.DataObjectGuid
LEFT JOIN SCore.EntityTypes AS et
    ON et.ID = do.EntityTypeId
LEFT JOIN SCore.WorkflowStatus AS ws
    ON ws.ID = lt.StatusID
WHERE lt.LatestRank = 1
GROUP BY
    do.EntityTypeId,
    et.Name,
    lt.StatusID,
    ws.Guid,
    ws.Name,
    ws.RowStatus
ORDER BY
    et.Name,
    ws.Name,
    lt.StatusID;

PRINT N'07b. Latest/current statuses not active - expected zero rows';
;WITH LatestTransition AS
(
    SELECT
        dot.ID AS DataObjectTransitionID,
        dot.DataObjectGuid,
        dot.StatusID,
        dot.DateTimeUTC,
        ROW_NUMBER() OVER
        (
            PARTITION BY dot.DataObjectGuid
            ORDER BY dot.DateTimeUTC DESC, dot.ID DESC
        ) AS LatestRank
    FROM SCore.DataObjectTransition AS dot
    WHERE dot.RowStatus NOT IN (0,254)
)
SELECT
    lt.DataObjectGuid,
    do.EntityTypeId,
    et.Name AS EntityTypeName,
    lt.DataObjectTransitionID,
    lt.StatusID AS CurrentWorkflowStatusID,
    ws.Guid AS CurrentWorkflowStatusGuid,
    ws.Name AS CurrentWorkflowStatusName,
    ws.RowStatus AS CurrentWorkflowStatusRowStatus,
    lt.DateTimeUTC AS CurrentStatusDateTimeUTC
FROM LatestTransition AS lt
INNER JOIN SCore.DataObjects AS do
    ON do.Guid = lt.DataObjectGuid
LEFT JOIN SCore.EntityTypes AS et
    ON et.ID = do.EntityTypeId
LEFT JOIN SCore.WorkflowStatus AS ws
    ON ws.ID = lt.StatusID
WHERE lt.LatestRank = 1
  AND
  (
      ws.ID IS NULL
      OR ws.RowStatus IN (0,254)
  )
ORDER BY
    et.Name,
    lt.StatusID,
    lt.DataObjectGuid;

PRINT N'07c. Latest/current statuses that do not appear in any active workflow graph for the DataObject EntityType - investigate, not always automatically blocking';
;WITH LatestTransition AS
(
    SELECT
        dot.ID AS DataObjectTransitionID,
        dot.DataObjectGuid,
        dot.StatusID,
        dot.DateTimeUTC,
        ROW_NUMBER() OVER
        (
            PARTITION BY dot.DataObjectGuid
            ORDER BY dot.DateTimeUTC DESC, dot.ID DESC
        ) AS LatestRank
    FROM SCore.DataObjectTransition AS dot
    WHERE dot.RowStatus NOT IN (0,254)
)
SELECT
    do.EntityTypeId,
    et.Name AS EntityTypeName,
    lt.StatusID AS CurrentWorkflowStatusID,
    ws.Guid AS CurrentWorkflowStatusGuid,
    ws.Name AS CurrentWorkflowStatusName,
    COUNT_BIG(1) AS CurrentObjectCount
FROM LatestTransition AS lt
INNER JOIN SCore.DataObjects AS do
    ON do.Guid = lt.DataObjectGuid
LEFT JOIN SCore.EntityTypes AS et
    ON et.ID = do.EntityTypeId
LEFT JOIN SCore.WorkflowStatus AS ws
    ON ws.ID = lt.StatusID
WHERE lt.LatestRank = 1
  AND ws.RowStatus NOT IN (0,254)
  AND NOT EXISTS
  (
      SELECT 1
      FROM SCore.Workflow AS w
      INNER JOIN SCore.WorkflowTransition AS wt
          ON wt.WorkflowID = w.ID
          AND wt.RowStatus NOT IN (0,254)
      WHERE w.RowStatus NOT IN (0,254)
        AND w.EntityTypeID = do.EntityTypeId
        AND
        (
            wt.FromStatusID = lt.StatusID
            OR wt.ToStatusID = lt.StatusID
        )
  )
GROUP BY
    do.EntityTypeId,
    et.Name,
    lt.StatusID,
    ws.Guid,
    ws.Name
ORDER BY
    et.Name,
    ws.Name;

PRINT N'============================================================';
PRINT N'08. Workflow status usage across active transitions and latest runtime state';
PRINT N'============================================================';

;WITH LatestTransition AS
(
    SELECT
        dot.DataObjectGuid,
        dot.StatusID,
        ROW_NUMBER() OVER
        (
            PARTITION BY dot.DataObjectGuid
            ORDER BY dot.DateTimeUTC DESC, dot.ID DESC
        ) AS LatestRank
    FROM SCore.DataObjectTransition AS dot
    WHERE dot.RowStatus NOT IN (0,254)
),
TransitionUsage AS
(
    SELECT
        ws.ID AS WorkflowStatusID,
        SUM(CASE WHEN wtFrom.ID IS NOT NULL THEN 1 ELSE 0 END) AS ActiveFromTransitionCount,
        SUM(CASE WHEN wtTo.ID IS NOT NULL THEN 1 ELSE 0 END) AS ActiveToTransitionCount
    FROM SCore.WorkflowStatus AS ws
    LEFT JOIN SCore.WorkflowTransition AS wtFrom
        ON wtFrom.FromStatusID = ws.ID
        AND wtFrom.RowStatus NOT IN (0,254)
    LEFT JOIN SCore.WorkflowTransition AS wtTo
        ON wtTo.ToStatusID = ws.ID
        AND wtTo.RowStatus NOT IN (0,254)
    WHERE ws.RowStatus NOT IN (0,254)
    GROUP BY ws.ID
),
CurrentUsage AS
(
    SELECT
        lt.StatusID AS WorkflowStatusID,
        COUNT_BIG(1) AS CurrentObjectCount
    FROM LatestTransition AS lt
    WHERE lt.LatestRank = 1
    GROUP BY lt.StatusID
)
SELECT
    ws.ID AS WorkflowStatusID,
    ws.Guid AS WorkflowStatusGuid,
    ws.Name AS WorkflowStatusName,
    ws.SortOrder,
    ws.Enabled,
    ws.ShowInEnquiries,
    ws.ShowInQuotes,
    ws.ShowInJobs,
    COALESCE(tu.ActiveFromTransitionCount, 0) AS ActiveFromTransitionCount,
    COALESCE(tu.ActiveToTransitionCount, 0) AS ActiveToTransitionCount,
    COALESCE(cu.CurrentObjectCount, 0) AS CurrentObjectCount
FROM SCore.WorkflowStatus AS ws
LEFT JOIN TransitionUsage AS tu
    ON tu.WorkflowStatusID = ws.ID
LEFT JOIN CurrentUsage AS cu
    ON cu.WorkflowStatusID = ws.ID
WHERE ws.RowStatus NOT IN (0,254)
ORDER BY
    ws.SortOrder,
    ws.Name,
    ws.ID;

PRINT N'============================================================';
PRINT N'09. Workflow configuration DataObjects check';
PRINT N'============================================================';

PRINT N'09a. EntityTypes likely representing workflow config tables';
SELECT
    et.ID AS EntityTypeID,
    et.Guid AS EntityTypeGuid,
    et.Name AS EntityTypeName,
    et.RowStatus,
    et.IsMetaData,
    et.IsRequiredSystemData
FROM SCore.EntityTypes AS et
WHERE et.Name IN
(
    N'Workflow',
    N'Workflows',
    N'Workflow Status',
    N'WorkflowStatus',
    N'Workflow Statuses',
    N'Workflow Transition',
    N'WorkflowTransition',
    N'Workflow Transitions',
    N'Workflow Status Notification Groups',
    N'WorkflowStatusNotificationGroups'
)
OR et.Name LIKE N'%Workflow%'
ORDER BY
    et.Name,
    et.ID;

PRINT N'09b. Config rows missing SCore.DataObjects by Guid - expected zero if these tables are registered entities';
SELECT
    N'SCore.Workflow' AS SourceTableName,
    w.ID AS SourceRecordID,
    w.Guid AS SourceRecordGuid,
    w.Name AS SourceRecordName,
    w.RowStatus AS SourceRecordRowStatus
FROM SCore.Workflow AS w
LEFT JOIN SCore.DataObjects AS do
    ON do.Guid = w.Guid
WHERE w.RowStatus NOT IN (0,254)
  AND do.Guid IS NULL
UNION ALL
SELECT
    N'SCore.WorkflowStatus' AS SourceTableName,
    ws.ID AS SourceRecordID,
    ws.Guid AS SourceRecordGuid,
    ws.Name AS SourceRecordName,
    ws.RowStatus AS SourceRecordRowStatus
FROM SCore.WorkflowStatus AS ws
LEFT JOIN SCore.DataObjects AS do
    ON do.Guid = ws.Guid
WHERE ws.RowStatus NOT IN (0,254)
  AND do.Guid IS NULL
UNION ALL
SELECT
    N'SCore.WorkflowTransition' AS SourceTableName,
    wt.ID AS SourceRecordID,
    wt.Guid AS SourceRecordGuid,
    CONCAT(CONVERT(nvarchar(20), wt.WorkflowID), N': ', CONVERT(nvarchar(20), wt.FromStatusID), N' -> ', CONVERT(nvarchar(20), wt.ToStatusID)) AS SourceRecordName,
    wt.RowStatus AS SourceRecordRowStatus
FROM SCore.WorkflowTransition AS wt
LEFT JOIN SCore.DataObjects AS do
    ON do.Guid = wt.Guid
WHERE wt.RowStatus NOT IN (0,254)
  AND do.Guid IS NULL
UNION ALL
SELECT
    N'SCore.WorkflowStatusNotificationGroups' AS SourceTableName,
    wsng.ID AS SourceRecordID,
    wsng.Guid AS SourceRecordGuid,
    CONCAT(CONVERT(nvarchar(20), wsng.WorkflowID), N': ', CONVERT(nvarchar(36), wsng.WorkflowStatusGuid), N' / Group ', CONVERT(nvarchar(20), wsng.GroupID)) AS SourceRecordName,
    wsng.RowStatus AS SourceRecordRowStatus
FROM SCore.WorkflowStatusNotificationGroups AS wsng
LEFT JOIN SCore.DataObjects AS do
    ON do.Guid = wsng.Guid
WHERE wsng.RowStatus NOT IN (0,254)
  AND wsng.ID <> -1
  AND do.Guid IS NULL
ORDER BY
    SourceTableName,
    SourceRecordID;

PRINT N'============================================================';
PRINT N'10. UAT source-of-truth config snapshot for archive / DEV comparison';
PRINT N'============================================================';

IF OBJECT_ID(N'tempdb..#WorkflowConfigSnapshot') IS NOT NULL
BEGIN
    DROP TABLE #WorkflowConfigSnapshot;
END;

CREATE TABLE #WorkflowConfigSnapshot
(
    ObjectType nvarchar(100) NOT NULL,
    RecordID int NOT NULL,
    RecordGuid uniqueidentifier NOT NULL,
    ParentKey nvarchar(400) NULL,
    NaturalKey nvarchar(600) NOT NULL,
    DisplayName nvarchar(600) NOT NULL,
    RowStatus tinyint NOT NULL,
    ConfigHash varbinary(32) NOT NULL
);

INSERT INTO #WorkflowConfigSnapshot
(
    ObjectType,
    RecordID,
    RecordGuid,
    ParentKey,
    NaturalKey,
    DisplayName,
    RowStatus,
    ConfigHash
)
SELECT
    N'Workflow' AS ObjectType,
    w.ID AS RecordID,
    w.Guid AS RecordGuid,
    CONCAT(N'EntityTypeID=', CONVERT(nvarchar(20), w.EntityTypeID), N';OrganisationalUnitId=', CONVERT(nvarchar(20), w.OrganisationalUnitId)) AS ParentKey,
    CONCAT(N'Workflow:', w.Name, N':', CONVERT(nvarchar(20), w.EntityTypeID), N':', CONVERT(nvarchar(20), w.OrganisationalUnitId)) AS NaturalKey,
    w.Name AS DisplayName,
    w.RowStatus,
    HASHBYTES
    (
        N'SHA2_256',
        CONCAT
        (
            N'Workflow|',
            CONVERT(nvarchar(20), w.ID), N'|',
            CONVERT(nvarchar(36), w.Guid), N'|',
            CONVERT(nvarchar(20), w.RowStatus), N'|',
            CONVERT(nvarchar(20), w.OrganisationalUnitId), N'|',
            CONVERT(nvarchar(20), w.EntityTypeID), N'|',
            COALESCE(CONVERT(nvarchar(20), w.EntityHoBTID), N'<NULL>'), N'|',
            w.Name, N'|',
            COALESCE(w.Description, N'<NULL>'), N'|',
            CONVERT(nvarchar(1), w.Enabled)
        )
    ) AS ConfigHash
FROM SCore.Workflow AS w
WHERE w.RowStatus NOT IN (0,254)
UNION ALL
SELECT
    N'WorkflowStatus' AS ObjectType,
    ws.ID AS RecordID,
    ws.Guid AS RecordGuid,
    NULL AS ParentKey,
    CONCAT(N'WorkflowStatus:', ws.Name) AS NaturalKey,
    ws.Name AS DisplayName,
    ws.RowStatus,
    HASHBYTES
    (
        N'SHA2_256',
        CONCAT
        (
            N'WorkflowStatus|',
            CONVERT(nvarchar(20), ws.ID), N'|',
            CONVERT(nvarchar(36), ws.Guid), N'|',
            CONVERT(nvarchar(20), ws.RowStatus), N'|',
            CONVERT(nvarchar(20), ws.OrganisationalUnitId), N'|',
            ws.Name, N'|',
            ws.Description, N'|',
            CONVERT(nvarchar(1), ws.ShowInEnquiries), N'|',
            CONVERT(nvarchar(1), ws.ShowInQuotes), N'|',
            CONVERT(nvarchar(1), ws.ShowInJobs), N'|',
            CONVERT(nvarchar(1), ws.Enabled), N'|',
            CONVERT(nvarchar(1), ws.IsPredefined), N'|',
            CONVERT(nvarchar(20), ws.SortOrder), N'|',
            ws.Colour, N'|',
            COALESCE(ws.Icon, N'<NULL>'), N'|',
            CONVERT(nvarchar(1), ws.SendNotification), N'|',
            CONVERT(nvarchar(1), ws.IsCompleteStatus), N'|',
            CONVERT(nvarchar(1), ws.IsCustomerWaitingStatus), N'|',
            CONVERT(nvarchar(1), ws.RequiresUsersAction), N'|',
            CONVERT(nvarchar(1), ws.IsActiveStatus), N'|',
            CONVERT(nvarchar(1), ws.AuthorisationNeeded), N'|',
            CONVERT(nvarchar(1), ws.IsAuthStatus)
        )
    ) AS ConfigHash
FROM SCore.WorkflowStatus AS ws
WHERE ws.RowStatus NOT IN (0,254)
UNION ALL
SELECT
    N'WorkflowTransition' AS ObjectType,
    wt.ID AS RecordID,
    wt.Guid AS RecordGuid,
    CONCAT(N'WorkflowID=', CONVERT(nvarchar(20), wt.WorkflowID)) AS ParentKey,
    CONCAT(N'WorkflowTransition:', CONVERT(nvarchar(20), wt.WorkflowID), N':', CONVERT(nvarchar(20), wt.FromStatusID), N':', CONVERT(nvarchar(20), wt.ToStatusID)) AS NaturalKey,
    CONCAT(COALESCE(w.Name, N'<MissingWorkflow>'), N': ', COALESCE(fromWs.Name, N'<MissingFrom>'), N' -> ', COALESCE(toWs.Name, N'<MissingTo>')) AS DisplayName,
    wt.RowStatus,
    HASHBYTES
    (
        N'SHA2_256',
        CONCAT
        (
            N'WorkflowTransition|',
            CONVERT(nvarchar(20), wt.ID), N'|',
            CONVERT(nvarchar(36), wt.Guid), N'|',
            CONVERT(nvarchar(20), wt.RowStatus), N'|',
            CONVERT(nvarchar(20), wt.WorkflowID), N'|',
            CONVERT(nvarchar(20), wt.FromStatusID), N'|',
            CONVERT(nvarchar(20), wt.ToStatusID), N'|',
            CONVERT(nvarchar(1), wt.IsFinal), N'|',
            CONVERT(nvarchar(1), wt.Enabled), N'|',
            CONVERT(nvarchar(20), wt.SortOrder), N'|',
            wt.Description
        )
    ) AS ConfigHash
FROM SCore.WorkflowTransition AS wt
LEFT JOIN SCore.Workflow AS w
    ON w.ID = wt.WorkflowID
LEFT JOIN SCore.WorkflowStatus AS fromWs
    ON fromWs.ID = wt.FromStatusID
LEFT JOIN SCore.WorkflowStatus AS toWs
    ON toWs.ID = wt.ToStatusID
WHERE wt.RowStatus NOT IN (0,254)
UNION ALL
SELECT
    N'WorkflowStatusNotificationGroups' AS ObjectType,
    wsng.ID AS RecordID,
    wsng.Guid AS RecordGuid,
    CONCAT(N'WorkflowID=', CONVERT(nvarchar(20), wsng.WorkflowID), N';WorkflowStatusGuid=', CONVERT(nvarchar(36), wsng.WorkflowStatusGuid)) AS ParentKey,
    CONCAT(N'WorkflowStatusNotificationGroups:', CONVERT(nvarchar(20), wsng.WorkflowID), N':', CONVERT(nvarchar(36), wsng.WorkflowStatusGuid), N':', CONVERT(nvarchar(20), wsng.GroupID)) AS NaturalKey,
    CONCAT(COALESCE(w.Name, N'<MissingWorkflow>'), N': ', COALESCE(ws.Name, N'<MissingStatus>'), N' / Group ', CONVERT(nvarchar(20), wsng.GroupID)) AS DisplayName,
    wsng.RowStatus,
    HASHBYTES
    (
        N'SHA2_256',
        CONCAT
        (
            N'WorkflowStatusNotificationGroups|',
            CONVERT(nvarchar(20), wsng.ID), N'|',
            CONVERT(nvarchar(36), wsng.Guid), N'|',
            CONVERT(nvarchar(20), wsng.RowStatus), N'|',
            CONVERT(nvarchar(20), wsng.WorkflowID), N'|',
            CONVERT(nvarchar(36), wsng.WorkflowStatusGuid), N'|',
            CONVERT(nvarchar(20), wsng.GroupID), N'|',
            CONVERT(nvarchar(1), wsng.CanAction)
        )
    ) AS ConfigHash
FROM SCore.WorkflowStatusNotificationGroups AS wsng
LEFT JOIN SCore.Workflow AS w
    ON w.ID = wsng.WorkflowID
LEFT JOIN SCore.WorkflowStatus AS ws
    ON ws.Guid = wsng.WorkflowStatusGuid
WHERE wsng.RowStatus NOT IN (0,254)
  AND wsng.ID <> -1;

SELECT
    s.ObjectType,
    s.RecordID,
    s.RecordGuid,
    s.ParentKey,
    s.NaturalKey,
    s.DisplayName,
    s.RowStatus,
    CONVERT(varchar(64), s.ConfigHash, 2) AS ConfigHashHex
FROM #WorkflowConfigSnapshot AS s
ORDER BY
    s.ObjectType,
    s.RecordID;

PRINT N'============================================================';
PRINT N'11. One-line blocking status';
PRINT N'============================================================';

DECLARE @BlockingIssues TABLE
(
    CheckName nvarchar(200) NOT NULL,
    IssueCount bigint NOT NULL
);

INSERT INTO @BlockingIssues
(
    CheckName,
    IssueCount
)
SELECT
    N'Active duplicate WorkflowStatus names' AS CheckName,
    COUNT_BIG(1) AS IssueCount
FROM
(
    SELECT
        LTRIM(RTRIM(LOWER(ws.Name))) AS NormalisedStatusName
    FROM SCore.WorkflowStatus AS ws
    WHERE ws.RowStatus NOT IN (0,254)
    GROUP BY LTRIM(RTRIM(LOWER(ws.Name)))
    HAVING COUNT_BIG(1) > 1
) AS d
UNION ALL
SELECT
    N'Active duplicate WorkflowTransition keys' AS CheckName,
    COUNT_BIG(1) AS IssueCount
FROM
(
    SELECT
        wt.WorkflowID,
        wt.FromStatusID,
        wt.ToStatusID
    FROM SCore.WorkflowTransition AS wt
    WHERE wt.RowStatus NOT IN (0,254)
    GROUP BY
        wt.WorkflowID,
        wt.FromStatusID,
        wt.ToStatusID
    HAVING COUNT_BIG(1) > 1
) AS d
UNION ALL
SELECT
    N'Active transitions with inactive/missing references' AS CheckName,
    COUNT_BIG(1) AS IssueCount
FROM SCore.WorkflowTransition AS wt
LEFT JOIN SCore.Workflow AS w
    ON w.ID = wt.WorkflowID
LEFT JOIN SCore.WorkflowStatus AS fromWs
    ON fromWs.ID = wt.FromStatusID
LEFT JOIN SCore.WorkflowStatus AS toWs
    ON toWs.ID = wt.ToStatusID
WHERE wt.RowStatus NOT IN (0,254)
  AND
  (
      w.ID IS NULL
      OR w.RowStatus IN (0,254)
      OR fromWs.ID IS NULL
      OR fromWs.RowStatus IN (0,254)
      OR toWs.ID IS NULL
      OR toWs.RowStatus IN (0,254)
  )
UNION ALL
SELECT
    N'Active notification groups with inactive/missing references excluding sentinel' AS CheckName,
    COUNT_BIG(1) AS IssueCount
FROM SCore.WorkflowStatusNotificationGroups AS wsng
LEFT JOIN SCore.Workflow AS w
    ON w.ID = wsng.WorkflowID
LEFT JOIN SCore.WorkflowStatus AS ws
    ON ws.Guid = wsng.WorkflowStatusGuid
WHERE wsng.RowStatus NOT IN (0,254)
  AND wsng.ID <> -1
  AND
  (
      w.ID IS NULL
      OR w.RowStatus IN (0,254)
      OR ws.ID IS NULL
      OR ws.RowStatus IN (0,254)
  )
UNION ALL
SELECT
    N'Retired duplicate status references remaining' AS CheckName,
    SUM(ReferenceCount) AS IssueCount
FROM
(
    SELECT COUNT_BIG(1) AS ReferenceCount
    FROM SCore.WorkflowTransition AS wt
    WHERE wt.FromStatusID IN (37, 53, 52, 29, 33, 41)
    UNION ALL
    SELECT COUNT_BIG(1) AS ReferenceCount
    FROM SCore.WorkflowTransition AS wt
    WHERE wt.ToStatusID IN (37, 53, 52, 29, 33, 41)
    UNION ALL
    SELECT COUNT_BIG(1) AS ReferenceCount
    FROM SCore.DataObjectTransition AS dot
    WHERE dot.StatusID IN (37, 53, 52, 29, 33, 41)
    UNION ALL
    SELECT COUNT_BIG(1) AS ReferenceCount
    FROM SCore.DataObjectTransition AS dot
    WHERE dot.OldStatusID IN (37, 53, 52, 29, 33, 41)
    UNION ALL
    SELECT COUNT_BIG(1) AS ReferenceCount
    FROM SCore.WorkflowStatusNotificationGroups AS wsng
    WHERE wsng.WorkflowStatusGuid IN
    (
        CONVERT(uniqueidentifier, N'b9ba4510-6358-4c0a-bba1-5feb33c54f84'),
        CONVERT(uniqueidentifier, N'85b522aa-134c-4e6c-884a-ff7264d7dd2e'),
        CONVERT(uniqueidentifier, N'5c9cd674-7520-44d2-9464-2a681f2f2ba4'),
        CONVERT(uniqueidentifier, N'b88f95c2-41c9-4cc6-ad9f-d9223c4e852a'),
        CONVERT(uniqueidentifier, N'9e0a10c7-94a0-4e25-afb1-14240d906c12'),
        CONVERT(uniqueidentifier, N'6ed4279a-e299-4d33-8ed5-cb8b78b3f13d')
    )
) AS retiredRefs
UNION ALL
SELECT
    N'Hidden workflow config rows remaining' AS CheckName,
    SUM(HiddenCount) AS IssueCount
FROM
(
    SELECT COUNT_BIG(1) AS HiddenCount FROM SCore.Workflow AS w WHERE w.RowStatus = 254
    UNION ALL
    SELECT COUNT_BIG(1) AS HiddenCount FROM SCore.WorkflowStatus AS ws WHERE ws.RowStatus = 254
    UNION ALL
    SELECT COUNT_BIG(1) AS HiddenCount FROM SCore.WorkflowTransition AS wt WHERE wt.RowStatus = 254
    UNION ALL
    SELECT COUNT_BIG(1) AS HiddenCount FROM SCore.WorkflowStatusNotificationGroups AS wsng WHERE wsng.RowStatus = 254
) AS hiddenRows;

SELECT
    bi.CheckName,
    bi.IssueCount,
    CASE WHEN bi.IssueCount = 0 THEN N'PASS' ELSE N'REVIEW / BLOCK DEV REPLACEMENT' END AS Result
FROM @BlockingIssues AS bi
ORDER BY bi.CheckName;

SELECT
    CASE WHEN EXISTS (SELECT 1 FROM @BlockingIssues AS bi WHERE bi.IssueCount > 0)
         THEN N'NOT READY - review blocking issue result sets above before migrating workflow config to DEV.'
         ELSE N'READY - active workflow config has no blocking issues from this validation script.'
    END AS WorkflowConfigReadinessResult;

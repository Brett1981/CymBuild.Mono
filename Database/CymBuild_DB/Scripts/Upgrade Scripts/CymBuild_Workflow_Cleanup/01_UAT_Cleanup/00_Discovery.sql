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

PRINT N'Workflow cleanup discovery - run and review before applying cleanup';

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

SELECT
    N'SCore.Workflow' AS ObjectName,
    w.RowStatus,
    COUNT_BIG(1) AS RowCount
FROM SCore.Workflow AS w
GROUP BY w.RowStatus
ORDER BY w.RowStatus;

SELECT
    N'SCore.WorkflowStatus' AS ObjectName,
    ws.RowStatus,
    COUNT_BIG(1) AS RowCount
FROM SCore.WorkflowStatus AS ws
GROUP BY ws.RowStatus
ORDER BY ws.RowStatus;

SELECT
    N'SCore.WorkflowTransition' AS ObjectName,
    wt.RowStatus,
    COUNT_BIG(1) AS RowCount
FROM SCore.WorkflowTransition AS wt
GROUP BY wt.RowStatus
ORDER BY wt.RowStatus;

SELECT
    N'SCore.WorkflowStatusNotificationGroups' AS ObjectName,
    ng.RowStatus,
    COUNT_BIG(1) AS RowCount
FROM SCore.WorkflowStatusNotificationGroups AS ng
GROUP BY ng.RowStatus
ORDER BY ng.RowStatus;

SELECT
    ws.ID,
    ws.Guid,
    ws.Name,
    ws.RowStatus,
    ws.ShowInEnquiries,
    ws.ShowInQuotes,
    ws.ShowInJobs,
    ws.Enabled,
    ws.IsPredefined,
    ws.SortOrder,
    COUNT(dotStatus.ID) AS DataObjectTransitionStatusCount,
    COUNT(dotOld.ID) AS DataObjectTransitionOldStatusCount,
    COUNT(wtFrom.ID) AS WorkflowTransitionFromCount,
    COUNT(wtTo.ID) AS WorkflowTransitionToCount
FROM SCore.WorkflowStatus AS ws
LEFT JOIN SCore.DataObjectTransition AS dotStatus
    ON dotStatus.StatusID = ws.ID
LEFT JOIN SCore.DataObjectTransition AS dotOld
    ON dotOld.OldStatusID = ws.ID
LEFT JOIN SCore.WorkflowTransition AS wtFrom
    ON wtFrom.FromStatusID = ws.ID
LEFT JOIN SCore.WorkflowTransition AS wtTo
    ON wtTo.ToStatusID = ws.ID
WHERE ws.ID IN (37, 3, 53, 8, 52, 14, 29, 50, 33, 48, 41)
GROUP BY
    ws.ID,
    ws.Guid,
    ws.Name,
    ws.RowStatus,
    ws.ShowInEnquiries,
    ws.ShowInQuotes,
    ws.ShowInJobs,
    ws.Enabled,
    ws.IsPredefined,
    ws.SortOrder
ORDER BY ws.Name, ws.ID;

SELECT
    ws.Name,
    COUNT_BIG(1) AS ActiveStatusCount,
    STRING_AGG(CONVERT(nvarchar(20), ws.ID), N', ') WITHIN GROUP (ORDER BY ws.ID) AS ActiveStatusIDs
FROM SCore.WorkflowStatus AS ws
WHERE ws.RowStatus NOT IN (0,254)
GROUP BY ws.Name
HAVING COUNT_BIG(1) > 1
ORDER BY ws.Name;

SELECT
    wt.WorkflowID,
    wf.Name AS WorkflowName,
    wt.FromStatusID,
    fromStatus.Name AS FromStatusName,
    wt.ToStatusID,
    toStatus.Name AS ToStatusName,
    COUNT_BIG(1) AS ActiveTransitionCount,
    STRING_AGG(CONVERT(nvarchar(20), wt.ID), N', ') WITHIN GROUP (ORDER BY wt.ID) AS ActiveTransitionIDs
FROM SCore.WorkflowTransition AS wt
JOIN SCore.Workflow AS wf
    ON wf.ID = wt.WorkflowID
JOIN SCore.WorkflowStatus AS fromStatus
    ON fromStatus.ID = wt.FromStatusID
JOIN SCore.WorkflowStatus AS toStatus
    ON toStatus.ID = wt.ToStatusID
WHERE wt.RowStatus NOT IN (0,254)
GROUP BY
    wt.WorkflowID,
    wf.Name,
    wt.FromStatusID,
    fromStatus.Name,
    wt.ToStatusID,
    toStatus.Name
HAVING COUNT_BIG(1) > 1
ORDER BY wf.Name, fromStatus.Name, toStatus.Name;

SELECT
    ng.ID,
    ng.RowStatus,
    ng.Guid,
    ng.WorkflowID,
    wf.Name AS WorkflowName,
    ng.WorkflowStatusGuid,
    ws.ID AS WorkflowStatusID,
    ws.Name AS WorkflowStatusName,
    ng.GroupID,
    ng.CanAction
FROM SCore.WorkflowStatusNotificationGroups AS ng
LEFT JOIN SCore.Workflow AS wf
    ON wf.ID = ng.WorkflowID
LEFT JOIN SCore.WorkflowStatus AS ws
    ON ws.Guid = ng.WorkflowStatusGuid
WHERE ws.ID IS NULL
   OR ng.RowStatus IN (0,254)
   OR wf.RowStatus IN (0,254)
ORDER BY ng.ID;

SELECT
    fk.name AS ForeignKeyName,
    OBJECT_SCHEMA_NAME(fk.parent_object_id) AS ParentSchemaName,
    OBJECT_NAME(fk.parent_object_id) AS ParentTableName,
    parentColumn.name AS ParentColumnName,
    OBJECT_SCHEMA_NAME(fk.referenced_object_id) AS ReferencedSchemaName,
    OBJECT_NAME(fk.referenced_object_id) AS ReferencedTableName,
    referencedColumn.name AS ReferencedColumnName
FROM sys.foreign_keys AS fk
JOIN sys.foreign_key_columns AS fkc
    ON fkc.constraint_object_id = fk.object_id
JOIN sys.columns AS parentColumn
    ON parentColumn.object_id = fkc.parent_object_id
   AND parentColumn.column_id = fkc.parent_column_id
JOIN sys.columns AS referencedColumn
    ON referencedColumn.object_id = fkc.referenced_object_id
   AND referencedColumn.column_id = fkc.referenced_column_id
WHERE fk.referenced_object_id IN
(
    OBJECT_ID(N'SCore.Workflow'),
    OBJECT_ID(N'SCore.WorkflowStatus'),
    OBJECT_ID(N'SCore.WorkflowTransition'),
    OBJECT_ID(N'SCore.WorkflowStatusNotificationGroups'),
    OBJECT_ID(N'SCore.DataObjects')
)
ORDER BY ReferencedSchemaName, ReferencedTableName, ParentSchemaName, ParentTableName, ParentColumnName;

SELECT
    OBJECT_SCHEMA_NAME(sm.object_id) AS SchemaName,
    OBJECT_NAME(sm.object_id) AS ObjectName,
    o.type_desc AS ObjectType,
    CASE WHEN sm.definition LIKE N'%02A2237F-2AE7-4E05-926F-38E8B7D050A0%' THEN 1 ELSE 0 END AS ContainsReadyToSendGuid,
    CASE WHEN sm.definition LIKE N'%WorkflowStatus%' THEN 1 ELSE 0 END AS ContainsWorkflowStatus,
    CASE WHEN sm.definition LIKE N'%WorkflowTransition%' THEN 1 ELSE 0 END AS ContainsWorkflowTransition,
    CASE WHEN sm.definition LIKE N'%DataObjectTransition%' THEN 1 ELSE 0 END AS ContainsDataObjectTransition
FROM sys.sql_modules AS sm
JOIN sys.objects AS o
    ON o.object_id = sm.object_id
WHERE sm.definition LIKE N'%WorkflowStatus%'
   OR sm.definition LIKE N'%WorkflowTransition%'
   OR sm.definition LIKE N'%DataObjectTransition%'
   OR sm.definition LIKE N'%02A2237F-2AE7-4E05-926F-38E8B7D050A0%'
ORDER BY SchemaName, ObjectName;

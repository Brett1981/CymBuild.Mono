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

PRINT N'Workflow cleanup post-validation';

SELECT
    N'DuplicateStatusRowsRemaining' AS CheckName,
    COUNT_BIG(1) AS FailureCount
FROM SCore.WorkflowStatus AS ws
WHERE ws.ID IN (37,53,52,29,33,41);

SELECT
    N'HiddenWorkflowRowsRemaining' AS CheckName,
    COUNT_BIG(1) AS FailureCount
FROM SCore.Workflow AS wf
WHERE wf.RowStatus = 254;

SELECT
    N'HiddenWorkflowStatusRowsRemaining' AS CheckName,
    COUNT_BIG(1) AS FailureCount
FROM SCore.WorkflowStatus AS ws
WHERE ws.RowStatus = 254;

SELECT
    N'HiddenOrRetiredWorkflowTransitionsRemaining' AS CheckName,
    COUNT_BIG(1) AS FailureCount
FROM SCore.WorkflowTransition AS wt
WHERE wt.RowStatus = 254
   OR wt.ID IN (395,349,439);

SELECT
    N'HiddenWorkflowStatusNotificationGroupsRemaining' AS CheckName,
    COUNT_BIG(1) AS FailureCount
FROM SCore.WorkflowStatusNotificationGroups AS ng
WHERE ng.RowStatus = 254
  AND ng.ID <> -1;

SELECT
    N'DataObjectTransitionDuplicateStatusReferences' AS CheckName,
    COUNT_BIG(1) AS FailureCount
FROM SCore.DataObjectTransition AS dot
WHERE dot.StatusID IN (37,53,52,29,33,41)
   OR dot.OldStatusID IN (37,53,52,29,33,41);

SELECT
    N'WorkflowTransitionDuplicateStatusReferences' AS CheckName,
    COUNT_BIG(1) AS FailureCount
FROM SCore.WorkflowTransition AS wt
WHERE wt.FromStatusID IN (37,53,52,29,33,41)
   OR wt.ToStatusID IN (37,53,52,29,33,41);

SELECT
    N'WorkflowNotificationQueueDuplicateStatusReferences' AS CheckName,
    COUNT_BIG(1) AS FailureCount
FROM SCore.WorkflowNotificationQueue AS q
WHERE q.StatusId IN (37,53,52,29,33,41);

SELECT
    N'WorkflowNotificationQueueErrorLogDuplicateStatusReferences' AS CheckName,
    COUNT_BIG(1) AS FailureCount
FROM SCore.WorkflowNotificationQueueErrorLog AS el
WHERE el.StatusId IN (37,53,52,29,33,41);

SELECT
    N'OrphanNotificationStatusGuids' AS CheckName,
    COUNT_BIG(1) AS FailureCount
FROM SCore.WorkflowStatusNotificationGroups AS ng
LEFT JOIN SCore.WorkflowStatus AS ws
    ON ws.Guid = ng.WorkflowStatusGuid
WHERE ng.ID <> -1
  AND ws.ID IS NULL;

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
    ws.ID,
    ws.Guid,
    ws.Name,
    ws.ShowInEnquiries,
    ws.ShowInQuotes,
    ws.ShowInJobs,
    ws.Enabled,
    ws.SortOrder,
    COUNT(dotStatus.ID) AS DataObjectTransitionStatusCount,
    COUNT(dotOld.ID) AS DataObjectTransitionOldStatusCount
FROM SCore.WorkflowStatus AS ws
LEFT JOIN SCore.DataObjectTransition AS dotStatus
    ON dotStatus.StatusID = ws.ID
LEFT JOIN SCore.DataObjectTransition AS dotOld
    ON dotOld.OldStatusID = ws.ID
WHERE ws.ID IN (3,8,14,48,50)
GROUP BY
    ws.ID,
    ws.Guid,
    ws.Name,
    ws.ShowInEnquiries,
    ws.ShowInQuotes,
    ws.ShowInJobs,
    ws.Enabled,
    ws.SortOrder
ORDER BY ws.ID;

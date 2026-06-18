
/*
    CymBuild Workflow Config Final Target Validation v14
    Run against DEV after applying OrganisationalUnits, Groups and Workflow config.
    Read-only.
*/
SET NOCOUNT ON;

PRINT N'============================================================';
PRINT N'01. Active target counts including sentinel rows';
PRINT N'============================================================';

SELECT N'SCore.OrganisationalUnits required by workflows' AS ObjectName, COUNT_BIG(1) AS TotalActiveRows, SUM(CASE WHEN ou.ID = -1 THEN 1 ELSE 0 END) AS SentinelRows, SUM(CASE WHEN ou.ID <> -1 THEN 1 ELSE 0 END) AS RealRows
FROM SCore.OrganisationalUnits AS ou
WHERE ou.RowStatus NOT IN (0,254)
  AND ou.ID IN (SELECT DISTINCT w.OrganisationalUnitId FROM SCore.Workflow AS w WHERE w.RowStatus NOT IN (0,254))
UNION ALL
SELECT N'SCore.Workflow', COUNT_BIG(1), SUM(CASE WHEN w.ID = -1 THEN 1 ELSE 0 END), SUM(CASE WHEN w.ID <> -1 THEN 1 ELSE 0 END)
FROM SCore.Workflow AS w WHERE w.RowStatus NOT IN (0,254)
UNION ALL
SELECT N'SCore.WorkflowStatus', COUNT_BIG(1), SUM(CASE WHEN ws.ID = -1 THEN 1 ELSE 0 END), SUM(CASE WHEN ws.ID <> -1 THEN 1 ELSE 0 END)
FROM SCore.WorkflowStatus AS ws WHERE ws.RowStatus NOT IN (0,254)
UNION ALL
SELECT N'SCore.WorkflowTransition', COUNT_BIG(1), SUM(CASE WHEN wt.ID = -1 THEN 1 ELSE 0 END), SUM(CASE WHEN wt.ID <> -1 THEN 1 ELSE 0 END)
FROM SCore.WorkflowTransition AS wt WHERE wt.RowStatus NOT IN (0,254)
UNION ALL
SELECT N'SCore.WorkflowStatusNotificationGroups', COUNT_BIG(1), SUM(CASE WHEN ng.ID = -1 THEN 1 ELSE 0 END), SUM(CASE WHEN ng.ID <> -1 THEN 1 ELSE 0 END)
FROM SCore.WorkflowStatusNotificationGroups AS ng WHERE ng.RowStatus NOT IN (0,254);

PRINT N'============================================================';
PRINT N'02. Workflows blocked by missing OrganisationalUnit';
PRINT N'============================================================';

SELECT
    w.ID AS WorkflowID,
    w.Guid AS WorkflowGuid,
    w.Name AS WorkflowName,
    w.Enabled AS WorkflowEnabled,
    w.OrganisationalUnitId,
    ou.ID AS MatchedOrganisationalUnitID,
    ou.Guid AS MatchedOrganisationalUnitGuid,
    ou.Name AS MatchedOrganisationalUnitName,
    ou.RowStatus AS MatchedOrganisationalUnitRowStatus
FROM SCore.Workflow AS w
LEFT JOIN SCore.OrganisationalUnits AS ou
    ON ou.ID = w.OrganisationalUnitId
   AND ou.RowStatus NOT IN (0,254)
WHERE w.RowStatus NOT IN (0,254)
  AND w.ID <> -1
  AND ou.ID IS NULL
ORDER BY w.ID;

PRINT N'============================================================';
PRINT N'03. Transition graph orphan check';
PRINT N'============================================================';

SELECT
    wt.ID AS WorkflowTransitionID,
    wt.Guid AS WorkflowTransitionGuid,
    wt.WorkflowID,
    w.ID AS MatchedWorkflowID,
    wt.FromStatusID,
    fromStatus.ID AS MatchedFromStatusID,
    wt.ToStatusID,
    toStatus.ID AS MatchedToStatusID
FROM SCore.WorkflowTransition AS wt
LEFT JOIN SCore.Workflow AS w
    ON w.ID = wt.WorkflowID
   AND w.RowStatus NOT IN (0,254)
LEFT JOIN SCore.WorkflowStatus AS fromStatus
    ON fromStatus.ID = wt.FromStatusID
   AND fromStatus.RowStatus NOT IN (0,254)
LEFT JOIN SCore.WorkflowStatus AS toStatus
    ON toStatus.ID = wt.ToStatusID
   AND toStatus.RowStatus NOT IN (0,254)
WHERE wt.RowStatus NOT IN (0,254)
  AND wt.ID <> -1
  AND (w.ID IS NULL OR fromStatus.ID IS NULL OR toStatus.ID IS NULL);

PRINT N'============================================================';
PRINT N'04. Notification group orphan check, excluding protected sentinel ID=-1';
PRINT N'============================================================';

SELECT
    ng.ID AS WorkflowStatusNotificationGroupID,
    ng.Guid AS WorkflowStatusNotificationGroupGuid,
    ng.WorkflowID,
    w.ID AS MatchedWorkflowID,
    ng.WorkflowStatusGuid,
    ws.ID AS MatchedWorkflowStatusID,
    ng.GroupID,
    g.ID AS MatchedGroupID
FROM SCore.WorkflowStatusNotificationGroups AS ng
LEFT JOIN SCore.Workflow AS w
    ON w.ID = ng.WorkflowID
   AND w.RowStatus NOT IN (0,254)
LEFT JOIN SCore.WorkflowStatus AS ws
    ON ws.Guid = ng.WorkflowStatusGuid
   AND ws.RowStatus NOT IN (0,254)
LEFT JOIN SCore.Groups AS g
    ON g.ID = ng.GroupID
   AND g.RowStatus NOT IN (0,254)
WHERE ng.RowStatus NOT IN (0,254)
  AND ng.ID <> -1
  AND (w.ID IS NULL OR ws.ID IS NULL OR g.ID IS NULL);

PRINT N'============================================================';
PRINT N'05. Focus workflow visibility/readiness check';
PRINT N'============================================================';

SELECT
    w.ID AS WorkflowID,
    w.Guid AS WorkflowGuid,
    w.Name AS WorkflowName,
    w.RowStatus AS WorkflowRowStatus,
    w.Enabled AS WorkflowEnabled,
    w.OrganisationalUnitId,
    ou.ID AS MatchedOrganisationalUnitID,
    ou.Guid AS MatchedOrganisationalUnitGuid,
    ou.Name AS MatchedOrganisationalUnitName,
    ou.RowStatus AS MatchedOrganisationalUnitRowStatus,
    w.EntityTypeID,
    et.Name AS EntityTypeName,
    COUNT(wt.ID) AS ActiveTransitionCount,
    SUM(CASE WHEN wt.Enabled = 1 THEN 1 ELSE 0 END) AS EnabledTransitionCount,
    CASE
        WHEN w.RowStatus IN (0,254) THEN N'BLOCKED - workflow hidden/deleted'
        WHEN w.Enabled = 0 THEN N'CHECK - workflow is active but disabled'
        WHEN ou.ID IS NULL THEN N'BLOCKED - Workflow.OrganisationalUnitId does not exist'
        WHEN ou.RowStatus IN (0,254) THEN N'BLOCKED - matched OrganisationalUnit is hidden/deleted'
        WHEN et.ID IS NULL THEN N'BLOCKED - Workflow.EntityTypeID does not exist'
        WHEN et.RowStatus IN (0,254) THEN N'BLOCKED - matched EntityType is hidden/deleted'
        WHEN COUNT(wt.ID) = 0 THEN N'CHECK - workflow has no active transitions'
        WHEN SUM(CASE WHEN wt.Enabled = 1 THEN 1 ELSE 0 END) = 0 THEN N'CHECK - workflow has transitions but none enabled'
        ELSE N'OK'
    END AS WorkflowGridReadiness
FROM SCore.Workflow AS w
LEFT JOIN SCore.OrganisationalUnits AS ou
    ON ou.ID = w.OrganisationalUnitId
LEFT JOIN SCore.EntityTypes AS et
    ON et.ID = w.EntityTypeID
LEFT JOIN SCore.WorkflowTransition AS wt
    ON wt.WorkflowID = w.ID
   AND wt.RowStatus NOT IN (0,254)
WHERE w.RowStatus NOT IN (0,254)
  AND (w.Name LIKE N'%Building Safety%' OR w.Name LIKE N'%Sustainability%' OR w.OrganisationalUnitId IN (22,25))
GROUP BY w.ID,w.Guid,w.Name,w.RowStatus,w.Enabled,w.OrganisationalUnitId,ou.ID,ou.Guid,ou.Name,ou.RowStatus,w.EntityTypeID,et.Name,et.ID,et.RowStatus
ORDER BY w.Name,w.ID;

PRINT N'Expected: no rows in sections 02, 03 and 04. Section 05 should show OK for enabled BSC workflows; Sustainability may be disabled if UAT source is disabled.';

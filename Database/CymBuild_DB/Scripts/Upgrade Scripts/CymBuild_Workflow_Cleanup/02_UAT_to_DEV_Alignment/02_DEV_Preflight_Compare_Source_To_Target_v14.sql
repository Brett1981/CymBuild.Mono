
/*
    CymBuild Workflow/Group/OrganisationalUnit Source-to-Target Compare v14

    Run against: DEV target database.
    Paste the generated v14 source snapshot from cleaned UAT into the marker below.

    This is read-only. It compares:
      - SCore.OrganisationalUnits required by workflows
      - SCore.Groups active source rows
      - SCore.Workflow
      - SCore.WorkflowStatus
      - SCore.WorkflowTransition
      - SCore.WorkflowStatusNotificationGroups
      - SCore.DataObjects presence for aligned config rows
      - runtime SCore.DataObjectTransition status references
*/

/* ===== SOURCE SNAPSHOT START - paste generated v14 SqlText lines below this comment ===== */

/* ===== SOURCE SNAPSHOT END ===== */

SET NOCOUNT ON;

PRINT N'============================================================';
PRINT N'01. Source/target active counts';
PRINT N'============================================================';

;WITH SourceCounts AS
(
    SELECT N'SCore.OrganisationalUnits' AS ObjectType, COUNT_BIG(1) AS SourceRows, SUM(CASE WHEN ID = -1 THEN 1 ELSE 0 END) AS SourceSentinelRows FROM @SourceOrganisationalUnits
    UNION ALL SELECT N'SCore.Groups', COUNT_BIG(1), SUM(CASE WHEN ID = -1 THEN 1 ELSE 0 END) FROM @SourceGroups
    UNION ALL SELECT N'SCore.Workflow', COUNT_BIG(1), SUM(CASE WHEN ID = -1 THEN 1 ELSE 0 END) FROM @SourceWorkflow
    UNION ALL SELECT N'SCore.WorkflowStatus', COUNT_BIG(1), SUM(CASE WHEN ID = -1 THEN 1 ELSE 0 END) FROM @SourceWorkflowStatus
    UNION ALL SELECT N'SCore.WorkflowTransition', COUNT_BIG(1), SUM(CASE WHEN ID = -1 THEN 1 ELSE 0 END) FROM @SourceWorkflowTransition
    UNION ALL SELECT N'SCore.WorkflowStatusNotificationGroups', COUNT_BIG(1), SUM(CASE WHEN ID = -1 THEN 1 ELSE 0 END) FROM @SourceWorkflowStatusNotificationGroups
),
TargetCounts AS
(
    SELECT N'SCore.OrganisationalUnits' AS ObjectType, COUNT_BIG(1) AS TargetRows, SUM(CASE WHEN ID = -1 THEN 1 ELSE 0 END) AS TargetSentinelRows FROM SCore.OrganisationalUnits WHERE ID IN (SELECT ID FROM @SourceOrganisationalUnits) AND RowStatus NOT IN (0,254)
    UNION ALL SELECT N'SCore.Groups', COUNT_BIG(1), SUM(CASE WHEN ID = -1 THEN 1 ELSE 0 END) FROM SCore.Groups WHERE ID IN (SELECT ID FROM @SourceGroups) AND RowStatus NOT IN (0,254)
    UNION ALL SELECT N'SCore.Workflow', COUNT_BIG(1), SUM(CASE WHEN ID = -1 THEN 1 ELSE 0 END) FROM SCore.Workflow WHERE RowStatus NOT IN (0,254)
    UNION ALL SELECT N'SCore.WorkflowStatus', COUNT_BIG(1), SUM(CASE WHEN ID = -1 THEN 1 ELSE 0 END) FROM SCore.WorkflowStatus WHERE RowStatus NOT IN (0,254)
    UNION ALL SELECT N'SCore.WorkflowTransition', COUNT_BIG(1), SUM(CASE WHEN ID = -1 THEN 1 ELSE 0 END) FROM SCore.WorkflowTransition WHERE RowStatus NOT IN (0,254)
    UNION ALL SELECT N'SCore.WorkflowStatusNotificationGroups', COUNT_BIG(1), SUM(CASE WHEN ID = -1 THEN 1 ELSE 0 END) FROM SCore.WorkflowStatusNotificationGroups WHERE RowStatus NOT IN (0,254)
)
SELECT
    sc.ObjectType,
    sc.SourceRows,
    tc.TargetRows,
    sc.SourceSentinelRows,
    tc.TargetSentinelRows,
    sc.SourceRows - sc.SourceSentinelRows AS SourceRealRows,
    tc.TargetRows - tc.TargetSentinelRows AS TargetRealRows
FROM SourceCounts AS sc
LEFT JOIN TargetCounts AS tc
    ON tc.ObjectType = sc.ObjectType
ORDER BY sc.ObjectType;

PRINT N'============================================================';
PRINT N'02. Blocking config differences by ID/GUID/config';
PRINT N'============================================================';

DECLARE @SourceComparable TABLE
(
    ObjectType nvarchar(120) NOT NULL,
    RecordID int NOT NULL,
    RecordGuid uniqueidentifier NULL,
    NaturalKey nvarchar(500) NOT NULL,
    ConfigText nvarchar(max) NOT NULL
);

DECLARE @TargetComparable TABLE
(
    ObjectType nvarchar(120) NOT NULL,
    RecordID int NOT NULL,
    RecordGuid uniqueidentifier NULL,
    NaturalKey nvarchar(500) NOT NULL,
    ConfigText nvarchar(max) NOT NULL
);

INSERT INTO @SourceComparable (ObjectType, RecordID, RecordGuid, NaturalKey, ConfigText)
SELECT N'SCore.OrganisationalUnits', sou.ID, sou.Guid, N'Name=' + COALESCE(sou.Name,N'<NULL>'),
       N'ID=' + CONVERT(nvarchar(20),sou.ID) + N'|RowStatus=' + CONVERT(nvarchar(10),sou.RowStatus) + N'|Guid=' + COALESCE(CONVERT(nvarchar(36),sou.Guid),N'<NULL>') + N'|Name=' + COALESCE(sou.Name,N'<NULL>')
FROM @SourceOrganisationalUnits AS sou
UNION ALL
SELECT N'SCore.Groups', sg.ID, sg.Guid, N'Name=' + COALESCE(sg.Name,N'<NULL>'),
       N'ID=' + CONVERT(nvarchar(20),sg.ID) + N'|RowStatus=' + CONVERT(nvarchar(10),sg.RowStatus) + N'|Guid=' + COALESCE(CONVERT(nvarchar(36),sg.Guid),N'<NULL>') + N'|DirectoryID=' + COALESCE(NULLIF(LTRIM(RTRIM(sg.DirectoryID)),N''),N'<NULL>') + N'|Code=' + COALESCE(NULLIF(LTRIM(RTRIM(sg.Code)),N''),N'<NULL>') + N'|Name=' + COALESCE(sg.Name,N'<NULL>')
FROM @SourceGroups AS sg
UNION ALL
SELECT N'SCore.Workflow', sw.ID, sw.Guid, N'Name=' + sw.Name + N'|EntityTypeID=' + CONVERT(nvarchar(20),sw.EntityTypeID) + N'|OrganisationalUnitId=' + CONVERT(nvarchar(20),sw.OrganisationalUnitId),
       N'ID=' + CONVERT(nvarchar(20),sw.ID) + N'|RowStatus=' + CONVERT(nvarchar(10),sw.RowStatus) + N'|Guid=' + COALESCE(CONVERT(nvarchar(36),sw.Guid),N'<NULL>') + N'|OrganisationalUnitId=' + CONVERT(nvarchar(20),sw.OrganisationalUnitId) + N'|EntityTypeID=' + CONVERT(nvarchar(20),sw.EntityTypeID) + N'|EntityHoBTID=' + COALESCE(CONVERT(nvarchar(20),sw.EntityHoBTID),N'<NULL>') + N'|Name=' + sw.Name + N'|Description=' + COALESCE(sw.Description,N'<NULL>') + N'|Enabled=' + CONVERT(nvarchar(1),CONVERT(int,sw.Enabled))
FROM @SourceWorkflow AS sw
UNION ALL
SELECT N'SCore.WorkflowStatus', ss.ID, ss.Guid, N'Name=' + ss.Name,
       N'ID=' + CONVERT(nvarchar(20),ss.ID) + N'|RowStatus=' + CONVERT(nvarchar(10),ss.RowStatus) + N'|Guid=' + COALESCE(CONVERT(nvarchar(36),ss.Guid),N'<NULL>') + N'|OrganisationalUnitId=' + CONVERT(nvarchar(20),ss.OrganisationalUnitId) + N'|Name=' + ss.Name + N'|Description=' + COALESCE(ss.Description,N'<NULL>') + N'|ShowInEnquiries=' + CONVERT(nvarchar(1),CONVERT(int,ss.ShowInEnquiries)) + N'|ShowInQuotes=' + CONVERT(nvarchar(1),CONVERT(int,ss.ShowInQuotes)) + N'|ShowInJobs=' + CONVERT(nvarchar(1),CONVERT(int,ss.ShowInJobs)) + N'|Enabled=' + CONVERT(nvarchar(1),CONVERT(int,ss.Enabled)) + N'|IsPredefined=' + CONVERT(nvarchar(1),CONVERT(int,ss.IsPredefined)) + N'|SortOrder=' + CONVERT(nvarchar(20),ss.SortOrder) + N'|Colour=' + COALESCE(ss.Colour,N'<NULL>') + N'|Icon=' + COALESCE(ss.Icon,N'<NULL>') + N'|SendNotification=' + CONVERT(nvarchar(1),CONVERT(int,ss.SendNotification)) + N'|IsCompleteStatus=' + CONVERT(nvarchar(1),CONVERT(int,ss.IsCompleteStatus)) + N'|IsCustomerWaitingStatus=' + CONVERT(nvarchar(1),CONVERT(int,ss.IsCustomerWaitingStatus)) + N'|RequiresUsersAction=' + CONVERT(nvarchar(1),CONVERT(int,ss.RequiresUsersAction)) + N'|IsActiveStatus=' + CONVERT(nvarchar(1),CONVERT(int,ss.IsActiveStatus)) + N'|AuthorisationNeeded=' + CONVERT(nvarchar(1),CONVERT(int,ss.AuthorisationNeeded)) + N'|IsAuthStatus=' + CONVERT(nvarchar(1),CONVERT(int,ss.IsAuthStatus))
FROM @SourceWorkflowStatus AS ss
UNION ALL
SELECT N'SCore.WorkflowTransition', st.ID, st.Guid, N'WorkflowID=' + CONVERT(nvarchar(20),st.WorkflowID) + N'|FromStatusID=' + CONVERT(nvarchar(20),st.FromStatusID) + N'|ToStatusID=' + CONVERT(nvarchar(20),st.ToStatusID) + N'|SortOrder=' + CONVERT(nvarchar(20),st.SortOrder),
       N'ID=' + CONVERT(nvarchar(20),st.ID) + N'|RowStatus=' + CONVERT(nvarchar(10),st.RowStatus) + N'|Guid=' + COALESCE(CONVERT(nvarchar(36),st.Guid),N'<NULL>') + N'|WorkflowID=' + CONVERT(nvarchar(20),st.WorkflowID) + N'|FromStatusID=' + CONVERT(nvarchar(20),st.FromStatusID) + N'|ToStatusID=' + CONVERT(nvarchar(20),st.ToStatusID) + N'|IsFinal=' + CONVERT(nvarchar(1),CONVERT(int,st.IsFinal)) + N'|Enabled=' + CONVERT(nvarchar(1),CONVERT(int,st.Enabled)) + N'|SortOrder=' + CONVERT(nvarchar(20),st.SortOrder) + N'|Description=' + COALESCE(st.Description,N'<NULL>')
FROM @SourceWorkflowTransition AS st
UNION ALL
SELECT N'SCore.WorkflowStatusNotificationGroups', sn.ID, sn.Guid, N'WorkflowID=' + CONVERT(nvarchar(20),sn.WorkflowID) + N'|WorkflowStatusGuid=' + CONVERT(nvarchar(36),sn.WorkflowStatusGuid) + N'|SourceGroupGuid=' + COALESCE(CONVERT(nvarchar(36),sn.SourceGroupGuid),N'<NULL>'),
       N'ID=' + CONVERT(nvarchar(20),sn.ID) + N'|RowStatus=' + CONVERT(nvarchar(10),sn.RowStatus) + N'|Guid=' + COALESCE(CONVERT(nvarchar(36),sn.Guid),N'<NULL>') + N'|WorkflowID=' + CONVERT(nvarchar(20),sn.WorkflowID) + N'|WorkflowStatusGuid=' + CONVERT(nvarchar(36),sn.WorkflowStatusGuid) + N'|SourceGroupID=' + CONVERT(nvarchar(20),sn.SourceGroupID) + N'|SourceGroupGuid=' + COALESCE(CONVERT(nvarchar(36),sn.SourceGroupGuid),N'<NULL>') + N'|SourceGroupName=' + COALESCE(sn.SourceGroupName,N'<NULL>') + N'|CanAction=' + CONVERT(nvarchar(1),CONVERT(int,sn.CanAction))
FROM @SourceWorkflowStatusNotificationGroups AS sn;

INSERT INTO @TargetComparable (ObjectType, RecordID, RecordGuid, NaturalKey, ConfigText)
SELECT N'SCore.OrganisationalUnits', ou.ID, ou.Guid, N'Name=' + COALESCE(ou.Name,N'<NULL>'),
       N'ID=' + CONVERT(nvarchar(20),ou.ID) + N'|RowStatus=' + CONVERT(nvarchar(10),ou.RowStatus) + N'|Guid=' + COALESCE(CONVERT(nvarchar(36),ou.Guid),N'<NULL>') + N'|Name=' + COALESCE(ou.Name,N'<NULL>')
FROM SCore.OrganisationalUnits AS ou
WHERE ou.ID IN (SELECT ID FROM @SourceOrganisationalUnits)
UNION ALL
SELECT N'SCore.Groups', g.ID, g.Guid, N'Name=' + COALESCE(g.Name,N'<NULL>'),
       N'ID=' + CONVERT(nvarchar(20),g.ID) + N'|RowStatus=' + CONVERT(nvarchar(10),g.RowStatus) + N'|Guid=' + COALESCE(CONVERT(nvarchar(36),g.Guid),N'<NULL>') + N'|DirectoryID=' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(200),g.DirectoryID))),N''),N'<NULL>') + N'|Code=' + COALESCE(NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(200),g.Code))),N''),N'<NULL>') + N'|Name=' + COALESCE(g.Name,N'<NULL>')
FROM SCore.Groups AS g
WHERE g.ID IN (SELECT ID FROM @SourceGroups)
UNION ALL
SELECT N'SCore.Workflow', w.ID, w.Guid, N'Name=' + w.Name + N'|EntityTypeID=' + CONVERT(nvarchar(20),w.EntityTypeID) + N'|OrganisationalUnitId=' + CONVERT(nvarchar(20),w.OrganisationalUnitId),
       N'ID=' + CONVERT(nvarchar(20),w.ID) + N'|RowStatus=' + CONVERT(nvarchar(10),w.RowStatus) + N'|Guid=' + COALESCE(CONVERT(nvarchar(36),w.Guid),N'<NULL>') + N'|OrganisationalUnitId=' + CONVERT(nvarchar(20),w.OrganisationalUnitId) + N'|EntityTypeID=' + CONVERT(nvarchar(20),w.EntityTypeID) + N'|EntityHoBTID=' + COALESCE(CONVERT(nvarchar(20),w.EntityHoBTID),N'<NULL>') + N'|Name=' + w.Name + N'|Description=' + COALESCE(w.Description,N'<NULL>') + N'|Enabled=' + CONVERT(nvarchar(1),CONVERT(int,w.Enabled))
FROM SCore.Workflow AS w
WHERE w.RowStatus NOT IN (0,254)
UNION ALL
SELECT N'SCore.WorkflowStatus', ws.ID, ws.Guid, N'Name=' + ws.Name,
       N'ID=' + CONVERT(nvarchar(20),ws.ID) + N'|RowStatus=' + CONVERT(nvarchar(10),ws.RowStatus) + N'|Guid=' + COALESCE(CONVERT(nvarchar(36),ws.Guid),N'<NULL>') + N'|OrganisationalUnitId=' + CONVERT(nvarchar(20),ws.OrganisationalUnitId) + N'|Name=' + ws.Name + N'|Description=' + COALESCE(ws.Description,N'<NULL>') + N'|ShowInEnquiries=' + CONVERT(nvarchar(1),CONVERT(int,ws.ShowInEnquiries)) + N'|ShowInQuotes=' + CONVERT(nvarchar(1),CONVERT(int,ws.ShowInQuotes)) + N'|ShowInJobs=' + CONVERT(nvarchar(1),CONVERT(int,ws.ShowInJobs)) + N'|Enabled=' + CONVERT(nvarchar(1),CONVERT(int,ws.Enabled)) + N'|IsPredefined=' + CONVERT(nvarchar(1),CONVERT(int,ws.IsPredefined)) + N'|SortOrder=' + CONVERT(nvarchar(20),ws.SortOrder) + N'|Colour=' + COALESCE(ws.Colour,N'<NULL>') + N'|Icon=' + COALESCE(ws.Icon,N'<NULL>') + N'|SendNotification=' + CONVERT(nvarchar(1),CONVERT(int,ws.SendNotification)) + N'|IsCompleteStatus=' + CONVERT(nvarchar(1),CONVERT(int,ws.IsCompleteStatus)) + N'|IsCustomerWaitingStatus=' + CONVERT(nvarchar(1),CONVERT(int,ws.IsCustomerWaitingStatus)) + N'|RequiresUsersAction=' + CONVERT(nvarchar(1),CONVERT(int,ws.RequiresUsersAction)) + N'|IsActiveStatus=' + CONVERT(nvarchar(1),CONVERT(int,ws.IsActiveStatus)) + N'|AuthorisationNeeded=' + CONVERT(nvarchar(1),CONVERT(int,ws.AuthorisationNeeded)) + N'|IsAuthStatus=' + CONVERT(nvarchar(1),CONVERT(int,ws.IsAuthStatus))
FROM SCore.WorkflowStatus AS ws
WHERE ws.RowStatus NOT IN (0,254)
UNION ALL
SELECT N'SCore.WorkflowTransition', wt.ID, wt.Guid, N'WorkflowID=' + CONVERT(nvarchar(20),wt.WorkflowID) + N'|FromStatusID=' + CONVERT(nvarchar(20),wt.FromStatusID) + N'|ToStatusID=' + CONVERT(nvarchar(20),wt.ToStatusID) + N'|SortOrder=' + CONVERT(nvarchar(20),wt.SortOrder),
       N'ID=' + CONVERT(nvarchar(20),wt.ID) + N'|RowStatus=' + CONVERT(nvarchar(10),wt.RowStatus) + N'|Guid=' + COALESCE(CONVERT(nvarchar(36),wt.Guid),N'<NULL>') + N'|WorkflowID=' + CONVERT(nvarchar(20),wt.WorkflowID) + N'|FromStatusID=' + CONVERT(nvarchar(20),wt.FromStatusID) + N'|ToStatusID=' + CONVERT(nvarchar(20),wt.ToStatusID) + N'|IsFinal=' + CONVERT(nvarchar(1),CONVERT(int,wt.IsFinal)) + N'|Enabled=' + CONVERT(nvarchar(1),CONVERT(int,wt.Enabled)) + N'|SortOrder=' + CONVERT(nvarchar(20),wt.SortOrder) + N'|Description=' + COALESCE(wt.Description,N'<NULL>')
FROM SCore.WorkflowTransition AS wt
WHERE wt.RowStatus NOT IN (0,254)
UNION ALL
SELECT N'SCore.WorkflowStatusNotificationGroups', ng.ID, ng.Guid, N'WorkflowID=' + CONVERT(nvarchar(20),ng.WorkflowID) + N'|WorkflowStatusGuid=' + CONVERT(nvarchar(36),ng.WorkflowStatusGuid) + N'|SourceGroupGuid=' + COALESCE(CONVERT(nvarchar(36),g.Guid),N'<NULL>'),
       N'ID=' + CONVERT(nvarchar(20),ng.ID) + N'|RowStatus=' + CONVERT(nvarchar(10),ng.RowStatus) + N'|Guid=' + COALESCE(CONVERT(nvarchar(36),ng.Guid),N'<NULL>') + N'|WorkflowID=' + CONVERT(nvarchar(20),ng.WorkflowID) + N'|WorkflowStatusGuid=' + CONVERT(nvarchar(36),ng.WorkflowStatusGuid) + N'|SourceGroupID=' + CONVERT(nvarchar(20),ng.GroupID) + N'|SourceGroupGuid=' + COALESCE(CONVERT(nvarchar(36),g.Guid),N'<NULL>') + N'|SourceGroupName=' + COALESCE(g.Name,N'<NULL>') + N'|CanAction=' + CONVERT(nvarchar(1),CONVERT(int,ng.CanAction))
FROM SCore.WorkflowStatusNotificationGroups AS ng
LEFT JOIN SCore.Groups AS g
    ON g.ID = ng.GroupID
WHERE ng.RowStatus NOT IN (0,254);

SELECT
    CASE
        WHEN s.RecordID IS NULL THEN N'Extra in target by ID'
        WHEN t.RecordID IS NULL THEN N'Missing in target by ID'
        WHEN ISNULL(CONVERT(nvarchar(36),s.RecordGuid),N'<NULL>') <> ISNULL(CONVERT(nvarchar(36),t.RecordGuid),N'<NULL>') THEN N'Same ID different GUID'
        WHEN s.ConfigText <> t.ConfigText THEN N'Same ID/GUID different config'
        ELSE N'Match'
    END AS IssueType,
    COALESCE(s.ObjectType,t.ObjectType) AS ObjectType,
    s.RecordID AS SourceRecordID,
    t.RecordID AS TargetRecordID,
    s.RecordGuid AS SourceGuid,
    t.RecordGuid AS TargetGuid,
    s.NaturalKey AS SourceNaturalKey,
    t.NaturalKey AS TargetNaturalKey,
    s.ConfigText AS SourceConfigText,
    t.ConfigText AS TargetConfigText
FROM @SourceComparable AS s
FULL OUTER JOIN @TargetComparable AS t
    ON t.ObjectType = s.ObjectType
   AND t.RecordID = s.RecordID
WHERE s.RecordID IS NULL
   OR t.RecordID IS NULL
   OR ISNULL(CONVERT(nvarchar(36),s.RecordGuid),N'<NULL>') <> ISNULL(CONVERT(nvarchar(36),t.RecordGuid),N'<NULL>')
   OR s.ConfigText <> t.ConfigText
ORDER BY
    ObjectType,
    IssueType,
    COALESCE(s.RecordID,t.RecordID);

PRINT N'============================================================';
PRINT N'03. Dependency/orphan checks';
PRINT N'============================================================';

SELECT
    w.ID AS WorkflowID,
    w.Guid AS WorkflowGuid,
    w.Name AS WorkflowName,
    w.OrganisationalUnitId,
    ou.ID AS MatchedOrganisationalUnitID
FROM SCore.Workflow AS w
LEFT JOIN SCore.OrganisationalUnits AS ou
    ON ou.ID = w.OrganisationalUnitId
   AND ou.RowStatus NOT IN (0,254)
WHERE w.RowStatus NOT IN (0,254)
  AND w.ID <> -1
  AND ou.ID IS NULL;

SELECT
    wt.ID AS WorkflowTransitionID,
    wt.Guid AS WorkflowTransitionGuid,
    wt.WorkflowID,
    w.ID AS MatchedWorkflowID,
    wt.FromStatusID,
    fromWs.ID AS MatchedFromStatusID,
    wt.ToStatusID,
    toWs.ID AS MatchedToStatusID
FROM SCore.WorkflowTransition AS wt
LEFT JOIN SCore.Workflow AS w
    ON w.ID = wt.WorkflowID
   AND w.RowStatus NOT IN (0,254)
LEFT JOIN SCore.WorkflowStatus AS fromWs
    ON fromWs.ID = wt.FromStatusID
   AND fromWs.RowStatus NOT IN (0,254)
LEFT JOIN SCore.WorkflowStatus AS toWs
    ON toWs.ID = wt.ToStatusID
   AND toWs.RowStatus NOT IN (0,254)
WHERE wt.RowStatus NOT IN (0,254)
  AND wt.ID <> -1
  AND (w.ID IS NULL OR fromWs.ID IS NULL OR toWs.ID IS NULL);

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
PRINT N'04. Missing DataObjects for aligned config rows';
PRINT N'============================================================';

SELECT N'SCore.OrganisationalUnits' AS ObjectType, sou.ID, sou.Guid, sou.Name AS NaturalKey
FROM @SourceOrganisationalUnits AS sou
LEFT JOIN SCore.DataObjects AS dob ON dob.Guid = sou.Guid AND dob.RowStatus NOT IN (0,254)
WHERE sou.ID <> -1 AND dob.Guid IS NULL
UNION ALL
SELECT N'SCore.Groups', sg.ID, sg.Guid, sg.Name
FROM @SourceGroups AS sg
LEFT JOIN SCore.DataObjects AS dob ON dob.Guid = sg.Guid AND dob.RowStatus NOT IN (0,254)
WHERE sg.ID <> -1 AND dob.Guid IS NULL
UNION ALL
SELECT N'SCore.Workflow', sw.ID, sw.Guid, sw.Name
FROM @SourceWorkflow AS sw
LEFT JOIN SCore.DataObjects AS dob ON dob.Guid = sw.Guid AND dob.RowStatus NOT IN (0,254)
WHERE sw.ID <> -1 AND dob.Guid IS NULL
UNION ALL
SELECT N'SCore.WorkflowStatus', ss.ID, ss.Guid, ss.Name
FROM @SourceWorkflowStatus AS ss
LEFT JOIN SCore.DataObjects AS dob ON dob.Guid = ss.Guid AND dob.RowStatus NOT IN (0,254)
WHERE ss.ID <> -1 AND dob.Guid IS NULL
UNION ALL
SELECT N'SCore.WorkflowTransition', st.ID, st.Guid, st.Description
FROM @SourceWorkflowTransition AS st
LEFT JOIN SCore.DataObjects AS dob ON dob.Guid = st.Guid AND dob.RowStatus NOT IN (0,254)
WHERE st.ID <> -1 AND dob.Guid IS NULL
UNION ALL
SELECT N'SCore.WorkflowStatusNotificationGroups', sn.ID, sn.Guid, CONVERT(nvarchar(200),sn.WorkflowID)
FROM @SourceWorkflowStatusNotificationGroups AS sn
LEFT JOIN SCore.DataObjects AS dob ON dob.Guid = sn.Guid AND dob.RowStatus NOT IN (0,254)
WHERE sn.ID <> -1 AND dob.Guid IS NULL
ORDER BY ObjectType, ID;

PRINT N'============================================================';
PRINT N'05. Runtime DataObjectTransition references to inactive/missing statuses';
PRINT N'============================================================';

SELECT
    N'StatusID' AS RefType,
    dot.StatusID AS ReferencedStatusID,
    COUNT_BIG(1) AS ReferenceCount
FROM SCore.DataObjectTransition AS dot
LEFT JOIN SCore.WorkflowStatus AS ws
    ON ws.ID = dot.StatusID
   AND ws.RowStatus NOT IN (0,254)
WHERE dot.RowStatus NOT IN (0,254)
  AND dot.ID <> -1
  AND dot.StatusID IS NOT NULL
  AND ws.ID IS NULL
GROUP BY dot.StatusID
UNION ALL
SELECT
    N'OldStatusID' AS RefType,
    dot.OldStatusID AS ReferencedStatusID,
    COUNT_BIG(1) AS ReferenceCount
FROM SCore.DataObjectTransition AS dot
LEFT JOIN SCore.WorkflowStatus AS ws
    ON ws.ID = dot.OldStatusID
   AND ws.RowStatus NOT IN (0,254)
WHERE dot.RowStatus NOT IN (0,254)
  AND dot.ID <> -1
  AND dot.OldStatusID IS NOT NULL
  AND ws.ID IS NULL
GROUP BY dot.OldStatusID;

/*
    CymBuild Workflow OU Conflict Diagnostic v14

    Purpose
    -------
    Diagnoses why strict OrganisationalUnit alignment blocks with error 73305/73306.

    Usage
    -----
    1. Run 01_UAT_Generate_Workflow_Config_Source_Block_v14.sql against cleaned UAT.
    2. Paste the generated full source snapshot below.
    3. Run this diagnostic against DEV.

    Interpretation
    --------------
    - If ID/GUID conflicts include direct workflow OrganisationalUnit IDs, use onboarding/security master alignment.
    - If conflicts are only ancestor rows, you may use the leaf-only dependency script in this pack for DEV testing,
      but the proper long-term fix remains onboarding/security master alignment.
*/

/* ===== SOURCE SNAPSHOT START - paste generated v14 SqlText lines below this comment ===== */
/* ===== SOURCE SNAPSHOT END ===== */

SET NOCOUNT ON;

PRINT N'============================================================';
PRINT N'01. Direct workflow OrganisationalUnit requirements';
PRINT N'============================================================';

;WITH DirectWorkflowOUs AS
(
    SELECT DISTINCT
        sw.OrganisationalUnitId AS OrganisationalUnitID
    FROM @SourceWorkflow AS sw
    WHERE sw.ID <> -1
      AND sw.RowStatus NOT IN (0,254)
      AND sw.OrganisationalUnitId <> -1
), WorkflowNames AS
(
    SELECT
        sw.OrganisationalUnitId,
        STRING_AGG(CONVERT(nvarchar(max), sw.Name), N' | ') AS WorkflowNames
    FROM @SourceWorkflow AS sw
    WHERE sw.ID <> -1
      AND sw.RowStatus NOT IN (0,254)
      AND sw.OrganisationalUnitId <> -1
    GROUP BY sw.OrganisationalUnitId
)
SELECT
    dwo.OrganisationalUnitID,
    sou.Guid AS SourceGuid,
    sou.Name AS SourceName,
    sou.ParentID AS SourceParentID,
    sou.DefaultSecurityGroupId AS SourceDefaultSecurityGroupId,
    targetOu.ID AS TargetID,
    targetOu.Guid AS TargetGuid,
    targetOu.Name AS TargetName,
    targetOu.RowStatus AS TargetRowStatus,
    wn.WorkflowNames,
    CASE
        WHEN targetOu.ID IS NULL THEN N'MISSING IN TARGET'
        WHEN targetOu.Guid <> sou.Guid THEN N'ID EXISTS WITH DIFFERENT GUID'
        WHEN targetOu.RowStatus IN (0,254) THEN N'TARGET HIDDEN/DELETED'
        ELSE N'OK'
    END AS TargetStatus
FROM DirectWorkflowOUs AS dwo
LEFT JOIN @SourceOrganisationalUnits AS sou ON sou.ID = dwo.OrganisationalUnitID
LEFT JOIN SCore.OrganisationalUnits AS targetOu ON targetOu.ID = dwo.OrganisationalUnitID
LEFT JOIN WorkflowNames AS wn ON wn.OrganisationalUnitId = dwo.OrganisationalUnitID
ORDER BY dwo.OrganisationalUnitID;

PRINT N'============================================================';
PRINT N'02. Source OU ID conflicts in target';
PRINT N'============================================================';

;WITH DirectWorkflowOUs AS
(
    SELECT DISTINCT sw.OrganisationalUnitId AS OrganisationalUnitID
    FROM @SourceWorkflow AS sw
    WHERE sw.ID <> -1
      AND sw.RowStatus NOT IN (0,254)
      AND sw.OrganisationalUnitId <> -1
)
SELECT
    sou.ID AS SourceOrganisationalUnitID,
    sou.Guid AS SourceOrganisationalUnitGuid,
    sou.Name AS SourceOrganisationalUnitName,
    sou.ParentID AS SourceParentID,
    sou.DefaultSecurityGroupId AS SourceDefaultSecurityGroupId,
    targetOu.ID AS TargetOrganisationalUnitID,
    targetOu.Guid AS TargetOrganisationalUnitGuid,
    targetOu.Name AS TargetOrganisationalUnitName,
    targetOu.ParentID AS TargetParentID,
    targetOu.DefaultSecurityGroupId AS TargetDefaultSecurityGroupId,
    targetOu.RowStatus AS TargetRowStatus,
    CASE WHEN dwo.OrganisationalUnitID IS NULL THEN CONVERT(bit,0) ELSE CONVERT(bit,1) END AS IsDirectWorkflowOrganisationalUnit,
    CASE
        WHEN dwo.OrganisationalUnitID IS NOT NULL THEN N'BLOCKING - direct workflow OU ID conflict'
        ELSE N'ANCESTOR/DEPENDENCY conflict'
    END AS ConflictSeverity
FROM @SourceOrganisationalUnits AS sou
INNER JOIN SCore.OrganisationalUnits AS targetOu
    ON targetOu.ID = sou.ID
LEFT JOIN DirectWorkflowOUs AS dwo
    ON dwo.OrganisationalUnitID = sou.ID
WHERE sou.ID <> -1
  AND targetOu.Guid <> sou.Guid
ORDER BY
    CASE WHEN dwo.OrganisationalUnitID IS NULL THEN 1 ELSE 0 END,
    sou.ID;

PRINT N'============================================================';
PRINT N'03. Source OU GUID exists under different target ID';
PRINT N'============================================================';

;WITH DirectWorkflowOUs AS
(
    SELECT DISTINCT sw.OrganisationalUnitId AS OrganisationalUnitID
    FROM @SourceWorkflow AS sw
    WHERE sw.ID <> -1
      AND sw.RowStatus NOT IN (0,254)
      AND sw.OrganisationalUnitId <> -1
)
SELECT
    sou.ID AS SourceOrganisationalUnitID,
    sou.Guid AS SourceOrganisationalUnitGuid,
    sou.Name AS SourceOrganisationalUnitName,
    targetOu.ID AS TargetOrganisationalUnitID,
    targetOu.Guid AS TargetOrganisationalUnitGuid,
    targetOu.Name AS TargetOrganisationalUnitName,
    targetOu.RowStatus AS TargetRowStatus,
    CASE WHEN dwo.OrganisationalUnitID IS NULL THEN CONVERT(bit,0) ELSE CONVERT(bit,1) END AS IsDirectWorkflowOrganisationalUnit
FROM @SourceOrganisationalUnits AS sou
INNER JOIN SCore.OrganisationalUnits AS targetOu
    ON targetOu.Guid = sou.Guid
LEFT JOIN DirectWorkflowOUs AS dwo
    ON dwo.OrganisationalUnitID = sou.ID
WHERE sou.ID <> -1
  AND targetOu.ID <> sou.ID
ORDER BY sou.ID;

PRINT N'============================================================';
PRINT N'04. Same-name OU matches in target';
PRINT N'============================================================';

SELECT
    sou.ID AS SourceOrganisationalUnitID,
    sou.Guid AS SourceOrganisationalUnitGuid,
    sou.Name AS SourceOrganisationalUnitName,
    targetOu.ID AS TargetOrganisationalUnitID,
    targetOu.Guid AS TargetOrganisationalUnitGuid,
    targetOu.Name AS TargetOrganisationalUnitName,
    targetOu.RowStatus AS TargetRowStatus
FROM @SourceOrganisationalUnits AS sou
INNER JOIN SCore.OrganisationalUnits AS targetOu
    ON targetOu.Name = sou.Name
WHERE sou.ID <> -1
  AND targetOu.ID <> sou.ID
ORDER BY sou.ID, targetOu.ID;

PRINT N'============================================================';
PRINT N'05. Parent/default group readiness for direct workflow OUs';
PRINT N'============================================================';

;WITH DirectWorkflowOUs AS
(
    SELECT DISTINCT sw.OrganisationalUnitId AS OrganisationalUnitID
    FROM @SourceWorkflow AS sw
    WHERE sw.ID <> -1
      AND sw.RowStatus NOT IN (0,254)
      AND sw.OrganisationalUnitId <> -1
)
SELECT
    sou.ID AS SourceOrganisationalUnitID,
    sou.Name AS SourceOrganisationalUnitName,
    sou.ParentID,
    parentTarget.Guid AS TargetParentGuid,
    parentTarget.Name AS TargetParentName,
    parentTarget.RowStatus AS TargetParentRowStatus,
    sou.DefaultSecurityGroupId,
    grp.Guid AS TargetDefaultSecurityGroupGuid,
    grp.Name AS TargetDefaultSecurityGroupName,
    grp.RowStatus AS TargetDefaultSecurityGroupRowStatus,
    CASE
        WHEN parentTarget.ID IS NULL THEN N'BLOCKED - parent missing in target'
        WHEN grp.ID IS NULL THEN N'BLOCKED - default security group missing in target'
        ELSE N'OK'
    END AS DependencyReadiness
FROM DirectWorkflowOUs AS dwo
INNER JOIN @SourceOrganisationalUnits AS sou ON sou.ID = dwo.OrganisationalUnitID
LEFT JOIN SCore.OrganisationalUnits AS parentTarget ON parentTarget.ID = sou.ParentID
LEFT JOIN SCore.Groups AS grp ON grp.ID = sou.DefaultSecurityGroupId
ORDER BY sou.ID;

PRINT N'============================================================';
PRINT N'06. Reference counts for conflicting target OU IDs';
PRINT N'============================================================';

IF OBJECT_ID(N'tempdb..#ConflictingOuIDs') IS NOT NULL DROP TABLE #ConflictingOuIDs;
CREATE TABLE #ConflictingOuIDs
(
    OrganisationalUnitID int NOT NULL PRIMARY KEY
);

INSERT INTO #ConflictingOuIDs (OrganisationalUnitID)
SELECT DISTINCT sou.ID
FROM @SourceOrganisationalUnits AS sou
INNER JOIN SCore.OrganisationalUnits AS targetOu
    ON targetOu.ID = sou.ID
WHERE sou.ID <> -1
  AND targetOu.Guid <> sou.Guid;

IF OBJECT_ID(N'tempdb..#OuReferenceSummary') IS NOT NULL DROP TABLE #OuReferenceSummary;
CREATE TABLE #OuReferenceSummary
(
    ReferencingSchema sysname NOT NULL,
    ReferencingTable sysname NOT NULL,
    ReferencingColumn sysname NOT NULL,
    OrganisationalUnitID int NOT NULL,
    ReferenceCount bigint NOT NULL
);

DECLARE @Sql nvarchar(max) = N'';

SELECT @Sql = @Sql + N'
INSERT INTO #OuReferenceSummary (ReferencingSchema, ReferencingTable, ReferencingColumn, OrganisationalUnitID, ReferenceCount)
SELECT N''' + REPLACE(SCHEMA_NAME(t.schema_id),'''','''''') + N''', N''' + REPLACE(t.name,'''','''''') + N''', N''' + REPLACE(c.name,'''','''''') + N''', ref.OrganisationalUnitID, COUNT_BIG(1)
FROM ' + QUOTENAME(SCHEMA_NAME(t.schema_id)) + N'.' + QUOTENAME(t.name) + N' AS x
INNER JOIN #ConflictingOuIDs AS ref ON ref.OrganisationalUnitID = x.' + QUOTENAME(c.name) + N'
GROUP BY ref.OrganisationalUnitID;
'
FROM sys.tables AS t
INNER JOIN sys.columns AS c
    ON c.object_id = t.object_id
WHERE c.name IN (N'OrganisationalUnitId', N'OrganisationalUnitID', N'OrgUnitId', N'OrgUnitID')
  AND t.is_ms_shipped = 0;

EXEC sys.sp_executesql @Sql;

SELECT
    ReferencingSchema,
    ReferencingTable,
    ReferencingColumn,
    OrganisationalUnitID,
    ReferenceCount
FROM #OuReferenceSummary
WHERE ReferenceCount > 0
ORDER BY OrganisationalUnitID, ReferencingSchema, ReferencingTable, ReferencingColumn;

PRINT N'============================================================';
PRINT N'07. Recommended next action';
PRINT N'============================================================';

;WITH DirectWorkflowOUs AS
(
    SELECT DISTINCT sw.OrganisationalUnitId AS OrganisationalUnitID
    FROM @SourceWorkflow AS sw
    WHERE sw.ID <> -1
      AND sw.RowStatus NOT IN (0,254)
      AND sw.OrganisationalUnitId <> -1
), DirectConflict AS
(
    SELECT TOP (1) 1 AS HasDirectConflict
    FROM @SourceOrganisationalUnits AS sou
    INNER JOIN DirectWorkflowOUs AS dwo ON dwo.OrganisationalUnitID = sou.ID
    INNER JOIN SCore.OrganisationalUnits AS targetOu ON targetOu.ID = sou.ID
    WHERE targetOu.Guid <> sou.Guid
), MissingDirect AS
(
    SELECT COUNT_BIG(1) AS MissingDirectCount
    FROM @SourceOrganisationalUnits AS sou
    INNER JOIN DirectWorkflowOUs AS dwo ON dwo.OrganisationalUnitID = sou.ID
    LEFT JOIN SCore.OrganisationalUnits AS targetOu ON targetOu.ID = sou.ID
    WHERE targetOu.ID IS NULL
), AncestorConflict AS
(
    SELECT TOP (1) 1 AS HasAncestorConflict
    FROM @SourceOrganisationalUnits AS sou
    LEFT JOIN DirectWorkflowOUs AS dwo ON dwo.OrganisationalUnitID = sou.ID
    INNER JOIN SCore.OrganisationalUnits AS targetOu ON targetOu.ID = sou.ID
    WHERE sou.ID <> -1
      AND dwo.OrganisationalUnitID IS NULL
      AND targetOu.Guid <> sou.Guid
)
SELECT
    CASE
        WHEN EXISTS (SELECT 1 FROM DirectConflict) THEN N'STOP - direct workflow OU ID conflict. Use onboarding/security master alignment.'
        WHEN EXISTS (SELECT 1 FROM AncestorConflict) THEN N'Ancestor-only conflict detected. For DEV testing you may use 04B leaf-only apply; for proper environment alignment use onboarding/security master alignment.'
        WHEN (SELECT MissingDirectCount FROM MissingDirect) > 0 THEN N'Direct workflow OUs are missing and no direct ID conflict was detected. Strict OU apply should be possible if parents/default groups are valid.'
        ELSE N'No direct OU blockers detected.'
    END AS RecommendedAction;

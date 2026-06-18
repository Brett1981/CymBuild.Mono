/*
    CymBuild Workflow Config Source Block Generator v14

    Run this against CLEANED UAT only. This is the single source snapshot for all DEV scripts in this pack.

    v14 includes all current fixes:
      - @SourceOrganisationalUnits required by active workflows, including full required columns
      - @SourceGroups with DirectoryID and Code
      - workflow/status/transition/notification-group config

    Runtime/history tables such as SCore.DataObjectTransition are not exported.
*/
SET NOCOUNT ON;

IF OBJECT_ID(N'SCore.OrganisationalUnits', N'U') IS NULL
BEGIN
    THROW 73300, N'SCore.OrganisationalUnits table was not found. The v14 generator requires workflow OrganisationalUnit dependencies.', 1;
END;

IF COL_LENGTH(N'SCore.Groups', N'DirectoryID') IS NULL
   OR COL_LENGTH(N'SCore.Groups', N'Code') IS NULL
BEGIN
    THROW 73300, N'SCore.Groups must expose DirectoryID and Code for the v14 group alignment generator.', 1;
END;

IF COL_LENGTH(N'SCore.OrganisationalUnits', N'ParentID') IS NULL
   OR COL_LENGTH(N'SCore.OrganisationalUnits', N'AddressId') IS NULL
   OR COL_LENGTH(N'SCore.OrganisationalUnits', N'ContactId') IS NULL
   OR COL_LENGTH(N'SCore.OrganisationalUnits', N'OfficialAddressId') IS NULL
   OR COL_LENGTH(N'SCore.OrganisationalUnits', N'OfficialContactId') IS NULL
   OR COL_LENGTH(N'SCore.OrganisationalUnits', N'OrgNode') IS NULL
   OR COL_LENGTH(N'SCore.OrganisationalUnits', N'DepartmentPrefix') IS NULL
   OR COL_LENGTH(N'SCore.OrganisationalUnits', N'CostCentreCode') IS NULL
   OR COL_LENGTH(N'SCore.OrganisationalUnits', N'DefaultSecurityGroupId') IS NULL
   OR COL_LENGTH(N'SCore.OrganisationalUnits', N'QuoteThreshold') IS NULL
BEGIN
    THROW 73300, N'SCore.OrganisationalUnits does not expose the expected v14 dependency columns.', 1;
END;

DECLARE @Lines TABLE
(
    [LineNo] int IDENTITY(1,1) NOT NULL,
    SqlText nvarchar(max) NOT NULL
);

INSERT INTO @Lines (SqlText) VALUES (N'/* Source snapshot generated from database: ' + DB_NAME() + N' at ' + CONVERT(nvarchar(33), SYSUTCDATETIME(), 126) + N' UTC */');
INSERT INTO @Lines (SqlText) VALUES (N'');
INSERT INTO @Lines (SqlText) VALUES (N'DECLARE @SourceOrganisationalUnits TABLE');
INSERT INTO @Lines (SqlText) VALUES (N'(');
INSERT INTO @Lines (SqlText) VALUES (N'    ID int NOT NULL PRIMARY KEY,');
INSERT INTO @Lines (SqlText) VALUES (N'    RowStatus tinyint NOT NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    Guid uniqueidentifier NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    Name nvarchar(250) NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    ParentID int NOT NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    AddressId int NOT NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    ContactId int NOT NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    OfficialAddressId int NOT NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    OfficialContactId int NOT NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    OrgNodePath nvarchar(4000) NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    DepartmentPrefix nvarchar(10) NOT NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    CostCentreCode nvarchar(50) NOT NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    DefaultSecurityGroupId int NOT NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    QuoteThreshold decimal(19,2) NULL');
INSERT INTO @Lines (SqlText) VALUES (N');');
INSERT INTO @Lines (SqlText) VALUES (N'');

;WITH RequiredOuSeed AS
(
    SELECT DISTINCT
        wf.OrganisationalUnitId AS ID
    FROM SCore.Workflow AS wf
    WHERE wf.RowStatus NOT IN (0,254)

    UNION

    SELECT CONVERT(int, -1) AS ID
),
OuTree AS
(
    SELECT
        ou.ID,
        ou.RowStatus,
        ou.Guid,
        ou.Name,
        ou.ParentID,
        ou.AddressId,
        ou.ContactId,
        ou.OfficialAddressId,
        ou.OfficialContactId,
        CASE WHEN ou.OrgNode IS NULL THEN NULL ELSE CONVERT(nvarchar(4000), ou.OrgNode.ToString()) END AS OrgNodePath,
        ou.DepartmentPrefix,
        ou.CostCentreCode,
        ou.DefaultSecurityGroupId,
        ou.QuoteThreshold,
        CONVERT(nvarchar(max), N'|' + CONVERT(nvarchar(20), ou.ID) + N'|') AS PathIds
    FROM SCore.OrganisationalUnits AS ou
    INNER JOIN RequiredOuSeed AS seed
        ON seed.ID = ou.ID

    UNION ALL

    SELECT
        parentOu.ID,
        parentOu.RowStatus,
        parentOu.Guid,
        parentOu.Name,
        parentOu.ParentID,
        parentOu.AddressId,
        parentOu.ContactId,
        parentOu.OfficialAddressId,
        parentOu.OfficialContactId,
        CASE WHEN parentOu.OrgNode IS NULL THEN NULL ELSE CONVERT(nvarchar(4000), parentOu.OrgNode.ToString()) END AS OrgNodePath,
        parentOu.DepartmentPrefix,
        parentOu.CostCentreCode,
        parentOu.DefaultSecurityGroupId,
        parentOu.QuoteThreshold,
        CONVERT(nvarchar(max), childOu.PathIds + CONVERT(nvarchar(20), parentOu.ID) + N'|') AS PathIds
    FROM OuTree AS childOu
    INNER JOIN SCore.OrganisationalUnits AS parentOu
        ON parentOu.ID = childOu.ParentID
    WHERE childOu.ParentID <> childOu.ID
      AND childOu.ParentID IS NOT NULL
      AND childOu.PathIds NOT LIKE N'%|' + CONVERT(nvarchar(20), childOu.ParentID) + N'|%'
),
DistinctOu AS
(
    SELECT
        ot.ID,
        ot.RowStatus,
        ot.Guid,
        ot.Name,
        ot.ParentID,
        ot.AddressId,
        ot.ContactId,
        ot.OfficialAddressId,
        ot.OfficialContactId,
        ot.OrgNodePath,
        ot.DepartmentPrefix,
        ot.CostCentreCode,
        ot.DefaultSecurityGroupId,
        ot.QuoteThreshold,
        ROW_NUMBER() OVER (PARTITION BY ot.ID ORDER BY ot.ID) AS rn
    FROM OuTree AS ot
)
INSERT INTO @Lines (SqlText)
SELECT
    N'INSERT INTO @SourceOrganisationalUnits (ID, RowStatus, Guid, Name, ParentID, AddressId, ContactId, OfficialAddressId, OfficialContactId, OrgNodePath, DepartmentPrefix, CostCentreCode, DefaultSecurityGroupId, QuoteThreshold) VALUES ('
    + CONVERT(nvarchar(20), ou.ID) + N', '
    + CONVERT(nvarchar(20), ou.RowStatus) + N', '
    + CASE WHEN ou.Guid IS NULL THEN N'NULL' ELSE N'CONVERT(uniqueidentifier,N''' + CONVERT(nvarchar(36), ou.Guid) + N''')' END + N', '
    + CASE WHEN ou.Name IS NULL THEN N'NULL' ELSE N'N''' + REPLACE(CONVERT(nvarchar(250), ou.Name), N'''', N'''''') + N'''' END + N', '
    + CONVERT(nvarchar(20), ou.ParentID) + N', '
    + CONVERT(nvarchar(20), ou.AddressId) + N', '
    + CONVERT(nvarchar(20), ou.ContactId) + N', '
    + CONVERT(nvarchar(20), ou.OfficialAddressId) + N', '
    + CONVERT(nvarchar(20), ou.OfficialContactId) + N', '
    + CASE WHEN ou.OrgNodePath IS NULL THEN N'NULL' ELSE N'N''' + REPLACE(CONVERT(nvarchar(4000), ou.OrgNodePath), N'''', N'''''') + N'''' END + N', '
    + N'N''' + REPLACE(CONVERT(nvarchar(10), ou.DepartmentPrefix), N'''', N'''''') + N''', '
    + N'N''' + REPLACE(CONVERT(nvarchar(50), ou.CostCentreCode), N'''', N'''''') + N''', '
    + CONVERT(nvarchar(20), ou.DefaultSecurityGroupId) + N', '
    + CASE WHEN ou.QuoteThreshold IS NULL THEN N'NULL' ELSE CONVERT(nvarchar(100), ou.QuoteThreshold) END
    + N');'
FROM DistinctOu AS ou
WHERE ou.rn = 1
ORDER BY
    ou.ID
OPTION (MAXRECURSION 100);

INSERT INTO @Lines (SqlText) VALUES (N'');
INSERT INTO @Lines (SqlText) VALUES (N'DECLARE @SourceGroups TABLE');
INSERT INTO @Lines (SqlText) VALUES (N'(');
INSERT INTO @Lines (SqlText) VALUES (N'    ID int NOT NULL PRIMARY KEY,');
INSERT INTO @Lines (SqlText) VALUES (N'    RowStatus tinyint NOT NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    Guid uniqueidentifier NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    DirectoryID nvarchar(200) NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    Code nvarchar(200) NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    Name nvarchar(200) NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    RequiredByWorkflowNotification bit NOT NULL');
INSERT INTO @Lines (SqlText) VALUES (N');');
INSERT INTO @Lines (SqlText) VALUES (N'');

INSERT INTO @Lines (SqlText)
SELECT
    N'INSERT INTO @SourceGroups (ID, RowStatus, Guid, DirectoryID, Code, Name, RequiredByWorkflowNotification) VALUES ('
    + CONVERT(nvarchar(20), grp.ID) + N', '
    + CONVERT(nvarchar(20), grp.RowStatus) + N', '
    + CASE WHEN grp.Guid IS NULL THEN N'NULL' ELSE N'CONVERT(uniqueidentifier,N''' + CONVERT(nvarchar(36), grp.Guid) + N''')' END + N', '
    + CASE WHEN NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(200), grp.DirectoryID))), N'') IS NULL THEN N'NULL' ELSE N'N''' + REPLACE(CONVERT(nvarchar(200), grp.DirectoryID), N'''', N'''''') + N'''' END + N', '
    + CASE WHEN NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(200), grp.Code))), N'') IS NULL THEN N'NULL' ELSE N'N''' + REPLACE(CONVERT(nvarchar(200), grp.Code), N'''', N'''''') + N'''' END + N', '
    + CASE WHEN grp.Name IS NULL THEN N'NULL' ELSE N'N''' + REPLACE(CONVERT(nvarchar(200), grp.Name), N'''', N'''''') + N'''' END + N', '
    + CONVERT(nvarchar(1), CONVERT(int,
        CASE
            WHEN EXISTS
            (
                SELECT 1
                FROM SCore.WorkflowStatusNotificationGroups AS ng
                WHERE ng.GroupID = grp.ID
                  AND ng.RowStatus NOT IN (0,254)
            )
            THEN CONVERT(bit, 1)
            ELSE CONVERT(bit, 0)
        END))
    + N');'
FROM SCore.Groups AS grp
WHERE grp.RowStatus NOT IN (0,254)
ORDER BY grp.ID;

INSERT INTO @Lines (SqlText) VALUES (N'');
INSERT INTO @Lines (SqlText) VALUES (N'DECLARE @SourceWorkflow TABLE');
INSERT INTO @Lines (SqlText) VALUES (N'(');
INSERT INTO @Lines (SqlText) VALUES (N'    ID int NOT NULL PRIMARY KEY,');
INSERT INTO @Lines (SqlText) VALUES (N'    RowStatus tinyint NOT NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    Guid uniqueidentifier NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    OrganisationalUnitId int NOT NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    EntityTypeID int NOT NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    EntityHoBTID int NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    Name nvarchar(100) NOT NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    Description nvarchar(400) NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    Enabled bit NOT NULL');
INSERT INTO @Lines (SqlText) VALUES (N');');
INSERT INTO @Lines (SqlText) VALUES (N'');

INSERT INTO @Lines (SqlText)
SELECT
    N'INSERT INTO @SourceWorkflow (ID, RowStatus, Guid, OrganisationalUnitId, EntityTypeID, EntityHoBTID, Name, Description, Enabled) VALUES ('
    + CONVERT(nvarchar(20), wf.ID) + N', '
    + CONVERT(nvarchar(20), wf.RowStatus) + N', '
    + CASE WHEN wf.Guid IS NULL THEN N'NULL' ELSE N'CONVERT(uniqueidentifier,N''' + CONVERT(nvarchar(36), wf.Guid) + N''')' END + N', '
    + CONVERT(nvarchar(20), wf.OrganisationalUnitId) + N', '
    + CONVERT(nvarchar(20), wf.EntityTypeID) + N', '
    + CASE WHEN wf.EntityHoBTID IS NULL THEN N'NULL' ELSE CONVERT(nvarchar(20), wf.EntityHoBTID) END + N', '
    + N'N''' + REPLACE(wf.Name, N'''', N'''''') + N''', '
    + CASE WHEN wf.Description IS NULL THEN N'NULL' ELSE N'N''' + REPLACE(wf.Description, N'''', N'''''') + N'''' END + N', '
    + CONVERT(nvarchar(1), CONVERT(int, wf.Enabled))
    + N');'
FROM SCore.Workflow AS wf
WHERE wf.RowStatus NOT IN (0,254)
ORDER BY wf.ID;

INSERT INTO @Lines (SqlText) VALUES (N'');
INSERT INTO @Lines (SqlText) VALUES (N'DECLARE @SourceWorkflowStatus TABLE');
INSERT INTO @Lines (SqlText) VALUES (N'(');
INSERT INTO @Lines (SqlText) VALUES (N'    ID int NOT NULL PRIMARY KEY,');
INSERT INTO @Lines (SqlText) VALUES (N'    RowStatus tinyint NOT NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    Guid uniqueidentifier NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    OrganisationalUnitId int NOT NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    Name nvarchar(100) NOT NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    Description nvarchar(400) NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    ShowInEnquiries bit NOT NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    ShowInQuotes bit NOT NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    ShowInJobs bit NOT NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    Enabled bit NOT NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    IsPredefined bit NOT NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    SortOrder int NOT NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    Colour nvarchar(7) NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    Icon nvarchar(50) NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    SendNotification bit NOT NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    IsCompleteStatus bit NOT NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    IsCustomerWaitingStatus bit NOT NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    RequiresUsersAction bit NOT NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    IsActiveStatus bit NOT NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    AuthorisationNeeded bit NOT NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    IsAuthStatus bit NOT NULL');
INSERT INTO @Lines (SqlText) VALUES (N');');
INSERT INTO @Lines (SqlText) VALUES (N'');

INSERT INTO @Lines (SqlText)
SELECT
    N'INSERT INTO @SourceWorkflowStatus (ID, RowStatus, Guid, OrganisationalUnitId, Name, Description, ShowInEnquiries, ShowInQuotes, ShowInJobs, Enabled, IsPredefined, SortOrder, Colour, Icon, SendNotification, IsCompleteStatus, IsCustomerWaitingStatus, RequiresUsersAction, IsActiveStatus, AuthorisationNeeded, IsAuthStatus) VALUES ('
    + CONVERT(nvarchar(20), ws.ID) + N', '
    + CONVERT(nvarchar(20), ws.RowStatus) + N', '
    + CASE WHEN ws.Guid IS NULL THEN N'NULL' ELSE N'CONVERT(uniqueidentifier,N''' + CONVERT(nvarchar(36), ws.Guid) + N''')' END + N', '
    + CONVERT(nvarchar(20), ws.OrganisationalUnitId) + N', '
    + N'N''' + REPLACE(ws.Name, N'''', N'''''') + N''', '
    + CASE WHEN ws.Description IS NULL THEN N'NULL' ELSE N'N''' + REPLACE(ws.Description, N'''', N'''''') + N'''' END + N', '
    + CONVERT(nvarchar(1), CONVERT(int, ws.ShowInEnquiries)) + N', '
    + CONVERT(nvarchar(1), CONVERT(int, ws.ShowInQuotes)) + N', '
    + CONVERT(nvarchar(1), CONVERT(int, ws.ShowInJobs)) + N', '
    + CONVERT(nvarchar(1), CONVERT(int, ws.Enabled)) + N', '
    + CONVERT(nvarchar(1), CONVERT(int, ws.IsPredefined)) + N', '
    + CONVERT(nvarchar(20), ws.SortOrder) + N', '
    + CASE WHEN ws.Colour IS NULL THEN N'NULL' ELSE N'N''' + REPLACE(ws.Colour, N'''', N'''''') + N'''' END + N', '
    + CASE WHEN ws.Icon IS NULL THEN N'NULL' ELSE N'N''' + REPLACE(ws.Icon, N'''', N'''''') + N'''' END + N', '
    + CONVERT(nvarchar(1), CONVERT(int, ws.SendNotification)) + N', '
    + CONVERT(nvarchar(1), CONVERT(int, ws.IsCompleteStatus)) + N', '
    + CONVERT(nvarchar(1), CONVERT(int, ws.IsCustomerWaitingStatus)) + N', '
    + CONVERT(nvarchar(1), CONVERT(int, ws.RequiresUsersAction)) + N', '
    + CONVERT(nvarchar(1), CONVERT(int, ws.IsActiveStatus)) + N', '
    + CONVERT(nvarchar(1), CONVERT(int, ws.AuthorisationNeeded)) + N', '
    + CONVERT(nvarchar(1), CONVERT(int, ws.IsAuthStatus))
    + N');'
FROM SCore.WorkflowStatus AS ws
WHERE ws.RowStatus NOT IN (0,254)
ORDER BY ws.ID;

INSERT INTO @Lines (SqlText) VALUES (N'');
INSERT INTO @Lines (SqlText) VALUES (N'DECLARE @SourceWorkflowTransition TABLE');
INSERT INTO @Lines (SqlText) VALUES (N'(');
INSERT INTO @Lines (SqlText) VALUES (N'    ID int NOT NULL PRIMARY KEY,');
INSERT INTO @Lines (SqlText) VALUES (N'    RowStatus tinyint NOT NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    Guid uniqueidentifier NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    WorkflowID int NOT NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    FromStatusID int NOT NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    ToStatusID int NOT NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    IsFinal bit NOT NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    Enabled bit NOT NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    SortOrder int NOT NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    Description nvarchar(400) NULL');
INSERT INTO @Lines (SqlText) VALUES (N');');
INSERT INTO @Lines (SqlText) VALUES (N'');

INSERT INTO @Lines (SqlText)
SELECT
    N'INSERT INTO @SourceWorkflowTransition (ID, RowStatus, Guid, WorkflowID, FromStatusID, ToStatusID, IsFinal, Enabled, SortOrder, Description) VALUES ('
    + CONVERT(nvarchar(20), wt.ID) + N', '
    + CONVERT(nvarchar(20), wt.RowStatus) + N', '
    + CASE WHEN wt.Guid IS NULL THEN N'NULL' ELSE N'CONVERT(uniqueidentifier,N''' + CONVERT(nvarchar(36), wt.Guid) + N''')' END + N', '
    + CONVERT(nvarchar(20), wt.WorkflowID) + N', '
    + CONVERT(nvarchar(20), wt.FromStatusID) + N', '
    + CONVERT(nvarchar(20), wt.ToStatusID) + N', '
    + CONVERT(nvarchar(1), CONVERT(int, wt.IsFinal)) + N', '
    + CONVERT(nvarchar(1), CONVERT(int, wt.Enabled)) + N', '
    + CONVERT(nvarchar(20), wt.SortOrder) + N', '
    + CASE WHEN wt.Description IS NULL THEN N'NULL' ELSE N'N''' + REPLACE(wt.Description, N'''', N'''''') + N'''' END
    + N');'
FROM SCore.WorkflowTransition AS wt
WHERE wt.RowStatus NOT IN (0,254)
ORDER BY wt.ID;

INSERT INTO @Lines (SqlText) VALUES (N'');
INSERT INTO @Lines (SqlText) VALUES (N'DECLARE @SourceWorkflowStatusNotificationGroups TABLE');
INSERT INTO @Lines (SqlText) VALUES (N'(');
INSERT INTO @Lines (SqlText) VALUES (N'    ID int NOT NULL PRIMARY KEY,');
INSERT INTO @Lines (SqlText) VALUES (N'    RowStatus tinyint NOT NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    Guid uniqueidentifier NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    WorkflowID int NOT NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    WorkflowStatusGuid uniqueidentifier NOT NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    SourceGroupID int NOT NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    SourceGroupGuid uniqueidentifier NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    SourceGroupName nvarchar(200) NULL,');
INSERT INTO @Lines (SqlText) VALUES (N'    CanAction bit NOT NULL');
INSERT INTO @Lines (SqlText) VALUES (N');');
INSERT INTO @Lines (SqlText) VALUES (N'');

INSERT INTO @Lines (SqlText)
SELECT
    N'INSERT INTO @SourceWorkflowStatusNotificationGroups (ID, RowStatus, Guid, WorkflowID, WorkflowStatusGuid, SourceGroupID, SourceGroupGuid, SourceGroupName, CanAction) VALUES ('
    + CONVERT(nvarchar(20), ng.ID) + N', '
    + CONVERT(nvarchar(20), ng.RowStatus) + N', '
    + CASE WHEN ng.Guid IS NULL THEN N'NULL' ELSE N'CONVERT(uniqueidentifier,N''' + CONVERT(nvarchar(36), ng.Guid) + N''')' END + N', '
    + CONVERT(nvarchar(20), ng.WorkflowID) + N', '
    + N'CONVERT(uniqueidentifier,N''' + CONVERT(nvarchar(36), ng.WorkflowStatusGuid) + N'''), '
    + CONVERT(nvarchar(20), ng.GroupID) + N', '
    + CASE WHEN grp.Guid IS NULL THEN N'NULL' ELSE N'CONVERT(uniqueidentifier,N''' + CONVERT(nvarchar(36), grp.Guid) + N''')' END + N', '
    + CASE WHEN grp.Name IS NULL THEN N'NULL' ELSE N'N''' + REPLACE(CONVERT(nvarchar(200), grp.Name), N'''', N'''''') + N'''' END + N', '
    + CONVERT(nvarchar(1), CONVERT(int, ng.CanAction))
    + N');'
FROM SCore.WorkflowStatusNotificationGroups AS ng
LEFT JOIN SCore.Groups AS grp
    ON grp.ID = ng.GroupID
WHERE ng.RowStatus NOT IN (0,254)
ORDER BY ng.ID;

SELECT
    l.[LineNo],
    l.SqlText
FROM @Lines AS l
ORDER BY l.[LineNo];

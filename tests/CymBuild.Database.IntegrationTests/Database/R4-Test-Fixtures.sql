SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() NOT LIKE N'CymBuild[_]Test[_]%'
   AND DB_NAME() <> TRY_CONVERT(nvarchar(128), SESSION_CONTEXT(N'CYMBUILD_SQL_TEST_ALLOWED_DATABASE'))
BEGIN
    THROW 62040, N'R4 fixture seeding is restricted to CymBuild_Test_* databases.', 1;
END;

DECLARE @EntityTypes TABLE
(
    Guid uniqueidentifier NOT NULL,
    Name nvarchar(250) NOT NULL
);

INSERT INTO @EntityTypes (Guid, Name)
VALUES
    ('D4D00001-0000-4000-8000-000000000001', N'EntityTypes'),
    ('D4D00001-0000-4000-8000-000000000002', N'EntityHobts'),
    ('D4D00001-0000-4000-8000-000000000003', N'Groups'),
    ('D4D00001-0000-4000-8000-000000000004', N'Identities'),
    ('D4D00001-0000-4000-8000-000000000005', N'WorkflowStatus'),
    ('D4D00001-0000-4000-8000-000000000006', N'NonActivityTypes'),
    ('D4D00001-0000-4000-8000-000000000007', N'NonActivityEvents'),
    ('D4D00001-0000-4000-8000-000000000008', N'DataObjectTransition');

IF EXISTS
(
    SELECT 1
    FROM SCore.EntityTypes AS existing
    JOIN @EntityTypes AS seed ON seed.Name = existing.Name
    WHERE existing.Guid <> seed.Guid
      AND existing.RowStatus NOT IN (0, 254)
)
BEGIN
    THROW 62041, N'An active EntityTypes fixture name already exists with an unexpected Guid.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM SCore.EntityTypes AS existing
    JOIN @EntityTypes AS seed ON seed.Guid = existing.Guid
    WHERE existing.RowStatus IN (0, 254)
)
BEGIN
    THROW 62042, N'An R4 EntityTypes fixture exists with an inactive RowStatus.', 1;
END;

UPDATE existing
SET
    existing.Name = seed.Name,
    existing.IsReadOnlyOffline = 0,
    existing.IsRequiredSystemData = 1,
    existing.HasDocuments = 0,
    existing.LanguageLabelID = -1,
    existing.DoNotTrackChanges = 1,
    existing.IsRootEntity = 0,
    existing.DetailPageUrl = N'',
    existing.IconId = -1,
    existing.IsMetaData = 1,
    existing.IsDeletable = 0,
    existing.IsOnBoarding = 0
FROM SCore.EntityTypes AS existing
JOIN @EntityTypes AS seed ON seed.Guid = existing.Guid;

INSERT INTO SCore.EntityTypes
(
    RowStatus,
    Guid,
    Name,
    IsReadOnlyOffline,
    IsRequiredSystemData,
    HasDocuments,
    LanguageLabelID,
    DoNotTrackChanges,
    IsRootEntity,
    DetailPageUrl,
    IconId,
    IsMetaData,
    IsDeletable,
    IsOnBoarding
)
SELECT
    1,
    seed.Guid,
    seed.Name,
    0,
    1,
    0,
    -1,
    1,
    0,
    N'',
    -1,
    1,
    0,
    0
FROM @EntityTypes AS seed
WHERE NOT EXISTS
(
    SELECT 1
    FROM SCore.EntityTypes AS existing
    WHERE existing.Guid = seed.Guid
);

DECLARE @EntityTypesEntityTypeId int =
(
    SELECT et.ID
    FROM SCore.EntityTypes AS et
    WHERE et.Guid = 'D4D00001-0000-4000-8000-000000000001'
);

IF @EntityTypesEntityTypeId IS NULL
BEGIN
    THROW 62043, N'Unable to resolve the R4 EntityTypes EntityTypeId.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM SCore.DataObjects AS dataObject
    JOIN @EntityTypes AS seed ON seed.Guid = dataObject.Guid
    WHERE dataObject.EntityTypeId <> @EntityTypesEntityTypeId
       OR dataObject.RowStatus IN (0, 254)
)
BEGIN
    THROW 62044, N'An R4 EntityTypes DataObject exists with an invalid identity or RowStatus.', 1;
END;

INSERT INTO SCore.DataObjects (Guid, RowStatus, EntityTypeId)
SELECT seed.Guid, 1, @EntityTypesEntityTypeId
FROM @EntityTypes AS seed
WHERE NOT EXISTS
(
    SELECT 1
    FROM SCore.DataObjects AS dataObject
    WHERE dataObject.Guid = seed.Guid
);

DECLARE @EntityHobts TABLE
(
    Guid uniqueidentifier NOT NULL,
    SchemaName nvarchar(250) NOT NULL,
    ObjectName nvarchar(250) NOT NULL,
    EntityTypeGuid uniqueidentifier NOT NULL
);

INSERT INTO @EntityHobts (Guid, SchemaName, ObjectName, EntityTypeGuid)
VALUES
    ('D4D00002-0000-4000-8000-000000000001', N'SCore', N'EntityTypes',          'D4D00001-0000-4000-8000-000000000001'),
    ('D4D00002-0000-4000-8000-000000000002', N'SCore', N'EntityHobts',          'D4D00001-0000-4000-8000-000000000002'),
    ('D4D00002-0000-4000-8000-000000000003', N'SCore', N'Groups',               'D4D00001-0000-4000-8000-000000000003'),
    ('D4D00002-0000-4000-8000-000000000004', N'SCore', N'Identities',           'D4D00001-0000-4000-8000-000000000004'),
    ('D4D00002-0000-4000-8000-000000000005', N'SCore', N'WorkflowStatus',       'D4D00001-0000-4000-8000-000000000005'),
    ('D4D00002-0000-4000-8000-000000000006', N'SCore', N'NonActivityTypes',     'D4D00001-0000-4000-8000-000000000006'),
    ('D4D00002-0000-4000-8000-000000000007', N'SCore', N'NonActivityEvents',    'D4D00001-0000-4000-8000-000000000007'),
    ('D4D00002-0000-4000-8000-000000000008', N'SCore', N'DataObjectTransition','D4D00001-0000-4000-8000-000000000008');

IF EXISTS
(
    SELECT 1
    FROM SCore.EntityHobts AS existing
    JOIN @EntityHobts AS seed
      ON seed.SchemaName = existing.SchemaName
     AND seed.ObjectName = existing.ObjectName
    WHERE existing.Guid <> seed.Guid
      AND existing.RowStatus NOT IN (0, 254)
)
BEGIN
    THROW 62045, N'An active EntityHobts fixture already exists with an unexpected Guid.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM SCore.EntityHobts AS existing
    JOIN @EntityHobts AS seed ON seed.Guid = existing.Guid
    WHERE existing.RowStatus IN (0, 254)
)
BEGIN
    THROW 62046, N'An R4 EntityHobts fixture exists with an inactive RowStatus.', 1;
END;

UPDATE existing
SET
    existing.SchemaName = seed.SchemaName,
    existing.ObjectName = seed.ObjectName,
    existing.EntityTypeID = entityType.ID,
    existing.ObjectType = N'U',
    existing.IsMainHoBT = 1,
    existing.IsReadOnlyOffline = 0
FROM SCore.EntityHobts AS existing
JOIN @EntityHobts AS seed ON seed.Guid = existing.Guid
JOIN SCore.EntityTypes AS entityType ON entityType.Guid = seed.EntityTypeGuid;

INSERT INTO SCore.EntityHobts
(
    RowStatus,
    Guid,
    SchemaName,
    ObjectName,
    EntityTypeID,
    ObjectType,
    IsMainHoBT,
    IsReadOnlyOffline
)
SELECT
    1,
    seed.Guid,
    seed.SchemaName,
    seed.ObjectName,
    entityType.ID,
    N'U',
    1,
    0
FROM @EntityHobts AS seed
JOIN SCore.EntityTypes AS entityType ON entityType.Guid = seed.EntityTypeGuid
WHERE NOT EXISTS
(
    SELECT 1
    FROM SCore.EntityHobts AS existing
    WHERE existing.Guid = seed.Guid
);

DECLARE @EntityHobtsEntityTypeId int =
(
    SELECT et.ID
    FROM SCore.EntityTypes AS et
    WHERE et.Guid = 'D4D00001-0000-4000-8000-000000000002'
);

IF EXISTS
(
    SELECT 1
    FROM SCore.DataObjects AS dataObject
    JOIN @EntityHobts AS seed ON seed.Guid = dataObject.Guid
    WHERE dataObject.EntityTypeId <> @EntityHobtsEntityTypeId
       OR dataObject.RowStatus IN (0, 254)
)
BEGIN
    THROW 62047, N'An R4 EntityHobts DataObject exists with an invalid identity or RowStatus.', 1;
END;

INSERT INTO SCore.DataObjects (Guid, RowStatus, EntityTypeId)
SELECT seed.Guid, 1, @EntityHobtsEntityTypeId
FROM @EntityHobts AS seed
WHERE NOT EXISTS
(
    SELECT 1
    FROM SCore.DataObjects AS dataObject
    WHERE dataObject.Guid = seed.Guid
);

DECLARE @GroupGuid uniqueidentifier = 'D4D00003-0000-4000-8000-000000000001';
DECLARE @IdentityGuid uniqueidentifier = 'D4D00004-0000-4000-8000-000000000001';
DECLARE @IdentityUserGuid uniqueidentifier = 'D4D00004-0000-4000-8000-000000000002';
DECLARE @FirstStatusGuid uniqueidentifier = 'D4D00005-0000-4000-8000-000000000001';
DECLARE @SecondStatusGuid uniqueidentifier = 'D4D00005-0000-4000-8000-000000000002';
DECLARE @NonActivityTypeGuid uniqueidentifier = 'D4D00006-0000-4000-8000-000000000001';

IF EXISTS
(
    SELECT 1
    FROM SCore.Groups
    WHERE (DirectoryId = N'CYMBUILD-R4-TEST' OR Name = N'CymBuild R4 Test Group')
      AND Guid <> @GroupGuid
)
BEGIN
    THROW 62048, N'The R4 group fixture conflicts with an existing group.', 1;
END;

IF EXISTS (SELECT 1 FROM SCore.Groups WHERE Guid = @GroupGuid AND RowStatus IN (0, 254))
BEGIN
    THROW 62049, N'The R4 group fixture exists with an inactive RowStatus.', 1;
END;

UPDATE SCore.Groups
SET
    DirectoryId = N'CYMBUILD-R4-TEST',
    Code = N'CYB-R4',
    Name = N'CymBuild R4 Test Group',
    Source = N'CYB_TEST_R4D'
WHERE Guid = @GroupGuid;

IF @@ROWCOUNT = 0
BEGIN
    INSERT INTO SCore.Groups
    (
        RowStatus,
        Guid,
        DirectoryId,
        Code,
        Name,
        Source
    )
    VALUES
    (
        1,
        @GroupGuid,
        N'CYMBUILD-R4-TEST',
        N'CYB-R4',
        N'CymBuild R4 Test Group',
        N'CYB_TEST_R4D'
    );
END;

IF EXISTS
(
    SELECT 1
    FROM SCore.Identities
    WHERE EmailAddress = N'cymbuild-r4-test@invalid.local'
      AND Guid <> @IdentityGuid
)
BEGIN
    THROW 62050, N'The R4 identity fixture conflicts with an existing identity.', 1;
END;

IF EXISTS (SELECT 1 FROM SCore.Identities WHERE Guid = @IdentityGuid AND RowStatus IN (0, 254))
BEGIN
    THROW 62051, N'The R4 identity fixture exists with an inactive RowStatus.', 1;
END;

UPDATE SCore.Identities
SET
    FullName = N'CymBuild R4 Test User',
    EmailAddress = N'cymbuild-r4-test@invalid.local',
    UserGuid = @IdentityUserGuid,
    JobTitle = N'Integration Test',
    OriganisationalUnitId = -1,
    IsActive = 1,
    ContactId = -1,
    BillableRate = 0,
    Signature = 0x
WHERE Guid = @IdentityGuid;

IF @@ROWCOUNT = 0
BEGIN
    INSERT INTO SCore.Identities
    (
        RowStatus,
        Guid,
        FullName,
        EmailAddress,
        UserGuid,
        JobTitle,
        OriganisationalUnitId,
        IsActive,
        ContactId,
        BillableRate,
        Signature
    )
    VALUES
    (
        1,
        @IdentityGuid,
        N'CymBuild R4 Test User',
        N'cymbuild-r4-test@invalid.local',
        @IdentityUserGuid,
        N'Integration Test',
        -1,
        1,
        -1,
        0,
        0x
    );
END;

DECLARE @WorkflowStatuses TABLE
(
    Guid uniqueidentifier NOT NULL,
    Name nvarchar(100) NOT NULL,
    SortOrder int NOT NULL
);

INSERT INTO @WorkflowStatuses (Guid, Name, SortOrder)
VALUES
    (@FirstStatusGuid, N'R4 Test State One', 1),
    (@SecondStatusGuid, N'R4 Test State Two', 2);

IF EXISTS
(
    SELECT 1
    FROM SCore.WorkflowStatus AS existing
    JOIN @WorkflowStatuses AS seed ON seed.Name = existing.Name
    WHERE existing.Guid <> seed.Guid
      AND existing.RowStatus NOT IN (0, 254)
)
BEGIN
    THROW 62052, N'The R4 workflow status fixture conflicts with an existing status.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM SCore.WorkflowStatus AS existing
    JOIN @WorkflowStatuses AS seed ON seed.Guid = existing.Guid
    WHERE existing.RowStatus IN (0, 254)
)
BEGIN
    THROW 62053, N'An R4 workflow status fixture exists with an inactive RowStatus.', 1;
END;

UPDATE existing
SET
    existing.OrganisationalUnitId = -1,
    existing.Name = seed.Name,
    existing.Description = N'Deterministic CymBuild R4 SQL integration status.',
    existing.ShowInEnquiries = 0,
    existing.ShowInQuotes = 0,
    existing.ShowInJobs = 0,
    existing.Enabled = 1,
    existing.IsPredefined = 1,
    existing.SortOrder = seed.SortOrder,
    existing.Colour = N'#FFFFFF',
    existing.Icon = NULL,
    existing.SendNotification = 0,
    existing.IsCompleteStatus = 0,
    existing.IsCustomerWaitingStatus = 0,
    existing.RequiresUsersAction = 0,
    existing.IsActiveStatus = 1,
    existing.AuthorisationNeeded = 0,
    existing.IsAuthStatus = 0
FROM SCore.WorkflowStatus AS existing
JOIN @WorkflowStatuses AS seed ON seed.Guid = existing.Guid;

INSERT INTO SCore.WorkflowStatus
(
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
    1,
    seed.Guid,
    -1,
    seed.Name,
    N'Deterministic CymBuild R4 SQL integration status.',
    0,
    0,
    0,
    1,
    1,
    seed.SortOrder,
    N'#FFFFFF',
    NULL,
    0,
    0,
    0,
    0,
    1,
    0,
    0
FROM @WorkflowStatuses AS seed
WHERE NOT EXISTS
(
    SELECT 1
    FROM SCore.WorkflowStatus AS existing
    WHERE existing.Guid = seed.Guid
);

IF EXISTS
(
    SELECT 1
    FROM SCore.NonActivityTypes
    WHERE Name = N'R4 Integration Test'
      AND Guid <> @NonActivityTypeGuid
      AND RowStatus NOT IN (0, 254)
)
BEGIN
    THROW 62054, N'The R4 NonActivityTypes fixture conflicts with an existing row.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM SCore.NonActivityTypes
    WHERE Guid = @NonActivityTypeGuid
      AND RowStatus IN (0, 254)
)
BEGIN
    THROW 62055, N'The R4 NonActivityTypes fixture exists with an inactive RowStatus.', 1;
END;

UPDATE SCore.NonActivityTypes
SET Name = N'R4 Integration Test'
WHERE Guid = @NonActivityTypeGuid;

IF @@ROWCOUNT = 0
BEGIN
    INSERT INTO SCore.NonActivityTypes
    (
        Guid,
        Name,
        RowStatus
    )
    VALUES
    (
        @NonActivityTypeGuid,
        N'R4 Integration Test',
        1
    );
END;

DECLARE @FixtureObjects TABLE
(
    Guid uniqueidentifier NOT NULL,
    EntityTypeGuid uniqueidentifier NOT NULL
);

INSERT INTO @FixtureObjects (Guid, EntityTypeGuid)
VALUES
    (@GroupGuid,           'D4D00001-0000-4000-8000-000000000003'),
    (@IdentityGuid,        'D4D00001-0000-4000-8000-000000000004'),
    (@FirstStatusGuid,     'D4D00001-0000-4000-8000-000000000005'),
    (@SecondStatusGuid,    'D4D00001-0000-4000-8000-000000000005'),
    (@NonActivityTypeGuid, 'D4D00001-0000-4000-8000-000000000006');

IF EXISTS
(
    SELECT 1
    FROM SCore.DataObjects AS dataObject
    JOIN @FixtureObjects AS fixture ON fixture.Guid = dataObject.Guid
    JOIN SCore.EntityTypes AS entityType ON entityType.Guid = fixture.EntityTypeGuid
    WHERE dataObject.EntityTypeId <> entityType.ID
       OR dataObject.RowStatus IN (0, 254)
)
BEGIN
    THROW 62056, N'An R4 fixture DataObject exists with an invalid identity or RowStatus.', 1;
END;

INSERT INTO SCore.DataObjects (Guid, RowStatus, EntityTypeId)
SELECT fixture.Guid, 1, entityType.ID
FROM @FixtureObjects AS fixture
JOIN SCore.EntityTypes AS entityType ON entityType.Guid = fixture.EntityTypeGuid
WHERE NOT EXISTS
(
    SELECT 1
    FROM SCore.DataObjects AS dataObject
    WHERE dataObject.Guid = fixture.Guid
);

IF
(
    SELECT COUNT_BIG(1)
    FROM SCore.EntityHobts
    WHERE Guid IN
    (
        'D4D00002-0000-4000-8000-000000000007',
        'D4D00002-0000-4000-8000-000000000008'
    )
      AND RowStatus NOT IN (0, 254)
) <> 2
BEGIN
    THROW 62057, N'The required NonActivityEvents and DataObjectTransition EntityHobts fixtures were not created.', 1;
END;


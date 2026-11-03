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
    ('D4D00001-0000-4000-8000-000000000008', N'DataObjectTransition'),
    -- R4-CYB-361-Outbox: real production EntityType Guid (from SCore.UpsertDataObject's
    -- OrgUnit-enforcement branch), required so DataObjectTransitionUpsert's Job-specific
    -- branches resolve correctly for the JobClosureDecision outbox-atomicity case.
    ('63542427-46AB-4078-ABD1-1D583C24315C', N'Jobs'),
    -- R4-CYB-501-Finance: test-only EntityType for SFin.Transactions. SCore.UpsertDataObject
    -- resolves EntityTypeId purely from SCore.EntityHobts by (SchemaName, ObjectName), with no
    -- Transaction-specific branch, so a deterministic test-only Guid is sufficient here.
    ('D4D00007-0000-4000-8000-000000000001', N'Transactions'),
    -- R4-CYB-543-Finance: test-only EntityTypes for the objects
    -- SFin.SageExternalTransaction_Upsert, SFin.TransactionDetailsUpsert and
    -- SFin.TransactionAllocationsUpsert each register via SCore.UpsertDataObject.
    ('D4D00007-0000-4000-8000-000000000002', N'SageExternalTransactions'),
    ('D4D00007-0000-4000-8000-000000000003', N'TransactionDetails'),
    ('D4D00007-0000-4000-8000-000000000004', N'TransactionAllocations'),
    -- R5 slice 2 (Enquiry authorisation-routing, real SSop.ProjectsUpsert/EnquiriesUpsert):
    -- test-only EntityType for SSop.Projects.
    ('D4D00007-0000-4000-8000-000000000005', N'Projects'),
    -- The Name here must be exactly 'Enquiries' - SCore.DataObjectTransitionUpsert resolves
    -- its Enquiry-specific status validation branch by a literal `Name = N'Enquiries'`
    -- lookup against SCore.EntityTypes, not by Guid.
    ('D4D00007-0000-4000-8000-000000000006', N'Enquiries'),
    -- SJob.AssetsUpsert calls SCore.UpsertDataObject with ObjectName='Assets', so
    -- SJob.Assets (which carries a disabled FK_Properties_DataObjects, the same
    -- tracked-entity pattern as SSop.Projects/SJob.Jobs) is a managed entity here too.
    ('D4D00007-0000-4000-8000-000000000007', N'Assets'),
    -- CYB-572: SFin.InvoiceRequestUpsert/InvoiceRequestItemsUpsert register their rows via
    -- SCore.UpsertDataObject, so SJob.ActivityCreateInvoiceRequest needs both HoBTs.
    ('D4D00572-0000-4000-8000-000000000001', N'InvoiceRequests'),
    ('D4D00572-0000-4000-8000-000000000002', N'InvoiceRequestItems'),
    -- CYB-576: SSop.QuotesUpsert/QuoteItemsUpsert register their rows via SCore.UpsertDataObject.
    -- Quotes reuses the Guid the R5 SQL-test branch (SB_SQL_TEST_EXPANSION_R5) assigns, so the two
    -- fixture sets agree when R5 merges; ticket-prefixed Guids (D4D00572/D4D00576) avoid R5's range.
    ('D4D00007-0000-4000-8000-000000000017', N'Quotes'),
    ('D4D00576-0000-4000-8000-000000000001', N'QuoteItems'),
    -- CYB-573: SJob.JobRibaStageFees_UpsertFromCreatedQuoteItems refuses to run without the
    -- JobRibaStageFees HoBT and registers its rows via SCore.DataObjectBulkUpsert.
    ('D4D00573-0000-4000-8000-000000000001', N'JobRibaStageFees'),
    -- CYB-237: SJob.FeeAmendmentsUpsert registers its row via SCore.UpsertDataObject.
    ('D4D00237-0000-4000-8000-000000000001', N'FeeAmendment'),
    -- CYB-333: SJob.ActivitiesUpsert and SJob.CustomFeeAmendmentUpsert register their rows via
    -- SCore.UpsertDataObject (SJob.ActivityFeeAmendmentEnsure raises custom-stage amendments).
    ('D4D00333-0000-4000-8000-000000000001', N'Activities'),
    ('D4D00333-0000-4000-8000-000000000002', N'CustomFeeAmendment');

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
    ('D4D00002-0000-4000-8000-000000000008', N'SCore', N'DataObjectTransition','D4D00001-0000-4000-8000-000000000008'),
    ('D4D00002-0000-4000-8000-000000000009', N'SJob',  N'Jobs',                '63542427-46AB-4078-ABD1-1D583C24315C'),
    ('D4D00002-0000-4000-8000-000000000010', N'SFin',  N'Transactions',        'D4D00007-0000-4000-8000-000000000001'),
    ('D4D00002-0000-4000-8000-000000000011', N'SFin',  N'SageExternalTransactions', 'D4D00007-0000-4000-8000-000000000002'),
    ('D4D00002-0000-4000-8000-000000000012', N'SFin',  N'TransactionDetails',  'D4D00007-0000-4000-8000-000000000003'),
    ('D4D00002-0000-4000-8000-000000000013', N'SFin',  N'TransactionAllocations', 'D4D00007-0000-4000-8000-000000000004'),
    ('D4D00002-0000-4000-8000-000000000014', N'SSop',  N'Projects',  'D4D00007-0000-4000-8000-000000000005'),
    ('D4D00002-0000-4000-8000-000000000015', N'SSop',  N'Enquiries', 'D4D00007-0000-4000-8000-000000000006'),
    ('D4D00002-0000-4000-8000-000000000016', N'SJob',  N'Assets', 'D4D00007-0000-4000-8000-000000000007'),
    ('D4D00572-0000-4000-8000-000000000003', N'SFin',  N'InvoiceRequests', 'D4D00572-0000-4000-8000-000000000001'),
    ('D4D00572-0000-4000-8000-000000000004', N'SFin',  N'InvoiceRequestItems', 'D4D00572-0000-4000-8000-000000000002'),
    ('D4D00002-0000-4000-8000-000000000026', N'SSop',  N'Quotes', 'D4D00007-0000-4000-8000-000000000017'),
    ('D4D00576-0000-4000-8000-000000000002', N'SSop',  N'QuoteItems', 'D4D00576-0000-4000-8000-000000000001'),
    ('D4D00573-0000-4000-8000-000000000002', N'SJob',  N'JobRibaStageFees', 'D4D00573-0000-4000-8000-000000000001'),
    ('D4D00237-0000-4000-8000-000000000002', N'SJob',  N'FeeAmendment', 'D4D00237-0000-4000-8000-000000000001'),
    ('D4D00333-0000-4000-8000-000000000003', N'SJob',  N'Activities', 'D4D00333-0000-4000-8000-000000000001'),
    ('D4D00333-0000-4000-8000-000000000004', N'SJob',  N'CustomFeeAmendment', 'D4D00333-0000-4000-8000-000000000002');

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

-- R4-CYB-361-Outbox: real production WorkflowStatus Guids hardcoded in
-- SJob.usp_JobClosureDecision. These must exist with ShowInJobs=1 for the
-- JobClosureDecision outbox-atomicity case to reach the procedure's transactional body.
DECLARE @JobStatus_Completed uniqueidentifier = '20D22623-283B-4088-9CEB-D944AC3E6516';
DECLARE @JobStatus_ClosureRequest uniqueidentifier = '5ED9C55A-4E14-44F6-A106-AE0F5C5EC38D';
DECLARE @JobStatus_ApproveClosure uniqueidentifier = 'E6776DB3-812F-4328-B81E-FEFD494EA049';
DECLARE @JobStatus_ClosureRejected uniqueidentifier = '48507119-2F28-490C-83A6-CE8F85E5AF7F';

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

/*
    R5 slice 2 (Enquiry authorisation-routing): SSop.EnquiriesUpsert stamps its initial
    "New" status transition with the literal all-zero Guid as @CreatedByUserGuid/
    @SurveyorUserGuid (Comment = 'System Imported.'), and SCore.DataObjectTransitionUpsert
    resolves those to Identities.ID with no NULL fallback before inserting into the
    NOT NULL SCore.DataObjectTransition.CreatedByUserId column - so a "system" Identity
    row keyed by that exact Guid must exist, matching what real environments carry.

    Side effect (reviewed, harmless as of this writing): SqlTestData.ExecuteTransitionUpsertAsync
    always passes Guid.Empty as @SurveyorUserGuid for every R4 test that calls it (Workflow,
    JobClosureDecision, IntegrationOutbox tests too), which previously resolved to no Identity
    (NULL SurveyorUserId). It now resolves to this system Identity's real ID instead. No
    existing R4 case asserts SurveyorUserId IS NULL, so nothing currently breaks, but a future
    case that does would need to account for this row rather than assume an unresolvable Guid.
*/
DECLARE @SystemIdentityGuid uniqueidentifier = '00000000-0000-0000-0000-000000000000';

IF EXISTS
(
    SELECT 1
    FROM SCore.Identities
    WHERE EmailAddress = N'cymbuild-r4-system@invalid.local'
      AND Guid <> @SystemIdentityGuid
)
BEGIN
    THROW 62072, N'The R4 system identity fixture conflicts with an existing identity.', 1;
END;

IF EXISTS (SELECT 1 FROM SCore.Identities WHERE Guid = @SystemIdentityGuid AND RowStatus IN (0, 254))
BEGIN
    THROW 62073, N'The R4 system identity fixture exists with an inactive RowStatus.', 1;
END;

UPDATE SCore.Identities
SET
    FullName = N'CymBuild R4 System User',
    EmailAddress = N'cymbuild-r4-system@invalid.local',
    JobTitle = N'System',
    OriganisationalUnitId = -1,
    IsActive = 1,
    ContactId = -1,
    BillableRate = 0,
    Signature = 0x
WHERE Guid = @SystemIdentityGuid;

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
        @SystemIdentityGuid,
        N'CymBuild R4 System User',
        N'cymbuild-r4-system@invalid.local',
        NEWID(),
        N'System',
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

DECLARE @JobClosureStatuses TABLE
(
    Guid uniqueidentifier NOT NULL,
    Name nvarchar(100) NOT NULL,
    SortOrder int NOT NULL
);

INSERT INTO @JobClosureStatuses (Guid, Name, SortOrder)
VALUES
    (@JobStatus_ClosureRequest, N'R4 Test Closure Request', 101),
    (@JobStatus_ApproveClosure, N'R4 Test Approve Closure', 102),
    (@JobStatus_Completed, N'R4 Test Completed', 103),
    (@JobStatus_ClosureRejected, N'R4 Test Closure Rejected', 104);

IF EXISTS
(
    SELECT 1
    FROM SCore.WorkflowStatus AS existing
    JOIN @JobClosureStatuses AS seed ON seed.Name = existing.Name
    WHERE existing.Guid <> seed.Guid
      AND existing.RowStatus NOT IN (0, 254)
)
BEGIN
    THROW 62058, N'A R4 job-closure workflow status fixture conflicts with an existing status.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM SCore.WorkflowStatus AS existing
    JOIN @JobClosureStatuses AS seed ON seed.Guid = existing.Guid
    WHERE existing.RowStatus IN (0, 254)
)
BEGIN
    THROW 62059, N'An R4 job-closure workflow status fixture exists with an inactive RowStatus.', 1;
END;

UPDATE existing
SET
    existing.OrganisationalUnitId = -1,
    existing.Name = seed.Name,
    existing.Description = N'Deterministic CymBuild R4 SQL integration Job closure status.',
    existing.ShowInEnquiries = 0,
    existing.ShowInQuotes = 0,
    existing.ShowInJobs = 1,
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
JOIN @JobClosureStatuses AS seed ON seed.Guid = existing.Guid;

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
    N'Deterministic CymBuild R4 SQL integration Job closure status.',
    0,
    0,
    1,
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
FROM @JobClosureStatuses AS seed
WHERE NOT EXISTS
(
    SELECT 1
    FROM SCore.WorkflowStatus AS existing
    WHERE existing.Guid = seed.Guid
);

-- R5 slice 2 (Enquiry authorisation-routing): SSop.EnquiriesUpsert itself requires a
-- ShowInEnquiries=1 status named exactly 'New' with this exact Description to stamp new
-- Enquiries; the second status is the test's own AuthorisationNeeded=1 status that
-- SCore.tvf_WF_AuthorisationQueue looks for.
DECLARE @EnquiryNewStatusGuid uniqueidentifier = 'D4D00005-0000-4000-8000-000000000003';
DECLARE @EnquiryAuthNeededStatusGuid uniqueidentifier = 'D4D00005-0000-4000-8000-000000000004';

DECLARE @EnquiryWorkflowStatuses TABLE
(
    Guid uniqueidentifier NOT NULL,
    Name nvarchar(100) NOT NULL,
    Description nvarchar(400) NOT NULL,
    AuthorisationNeeded bit NOT NULL,
    SortOrder int NOT NULL
);

INSERT INTO @EnquiryWorkflowStatuses (Guid, Name, Description, AuthorisationNeeded, SortOrder)
VALUES
    (@EnquiryNewStatusGuid, N'New', N'Automatically generated status', 0, 201),
    (@EnquiryAuthNeededStatusGuid, N'R4 Test Bid Team Review', N'Deterministic CymBuild R4 SQL integration Enquiry authorisation status.', 1, 202);

IF EXISTS
(
    SELECT 1
    FROM SCore.WorkflowStatus AS existing
    JOIN @EnquiryWorkflowStatuses AS seed ON seed.Name = existing.Name
    WHERE existing.Guid <> seed.Guid
      AND existing.RowStatus NOT IN (0, 254)
)
BEGIN
    THROW 62067, N'A R4 Enquiry workflow status fixture conflicts with an existing status.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM SCore.WorkflowStatus AS existing
    JOIN @EnquiryWorkflowStatuses AS seed ON seed.Guid = existing.Guid
    WHERE existing.RowStatus IN (0, 254)
)
BEGIN
    THROW 62068, N'An R4 Enquiry workflow status fixture exists with an inactive RowStatus.', 1;
END;

UPDATE existing
SET
    existing.OrganisationalUnitId = -1,
    existing.Name = seed.Name,
    existing.Description = seed.Description,
    existing.ShowInEnquiries = 1,
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
    existing.RequiresUsersAction = seed.AuthorisationNeeded,
    existing.IsActiveStatus = 1,
    existing.AuthorisationNeeded = seed.AuthorisationNeeded,
    existing.IsAuthStatus = 0
FROM SCore.WorkflowStatus AS existing
JOIN @EnquiryWorkflowStatuses AS seed ON seed.Guid = existing.Guid;

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
    seed.Description,
    1,
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
    seed.AuthorisationNeeded,
    1,
    seed.AuthorisationNeeded,
    0
FROM @EnquiryWorkflowStatuses AS seed
WHERE NOT EXISTS
(
    SELECT 1
    FROM SCore.WorkflowStatus AS existing
    WHERE existing.Guid = seed.Guid
);

-- R4-CYB-361-Outbox: minimal reference OrganisationalUnit for the JobClosureDecision
-- outbox-atomicity case. No stable Guid column exists on the compatibility stub table,
-- so this is idempotent by Name rather than by Guid like the fixtures above.
IF NOT EXISTS (SELECT 1 FROM SCore.OrganisationalUnits WHERE Name = N'CymBuild R4 Test OrgUnit')
BEGIN
    INSERT INTO SCore.OrganisationalUnits (RowStatus, Name)
    VALUES (1, N'CymBuild R4 Test OrgUnit');
END;

IF EXISTS (SELECT 1 FROM SCore.OrganisationalUnits WHERE Name = N'CymBuild R4 Test OrgUnit' AND RowStatus IN (0, 254))
BEGIN
    THROW 62060, N'The R4 OrganisationalUnit fixture exists with an inactive RowStatus.', 1;
END;

-- R4-CYB-501-Finance: one active account so SqlTestData.ReadActiveAccountIdAsync and
-- SFin.Transaction_InvoiceMergeInfo's INNER JOIN on SCrm.Accounts have a row to resolve.
-- No stable Guid column exists on the compatibility stub table, so this is idempotent
-- by Name rather than by Guid like the fixtures above.
IF NOT EXISTS (SELECT 1 FROM SCrm.Accounts WHERE Name = N'CymBuild R4 Finance Test Account')
BEGIN
    INSERT INTO SCrm.Accounts (RowStatus, Name, MainAccountAddressId)
    VALUES (1, N'CymBuild R4 Finance Test Account', -1);
END;

IF EXISTS (SELECT 1 FROM SCrm.Accounts WHERE Name = N'CymBuild R4 Finance Test Account' AND RowStatus IN (0, 254))
BEGIN
    THROW 62061, N'The R4 Finance test Account fixture exists with an inactive RowStatus.', 1;
END;

/*
    R5 slice 2 (Enquiry authorisation-routing): SSop.EnquiriesUpsert's SharePoint filing-name
    resolution INNER JOINs SJob.Assets on the Enquiry's PropertyId, so a real Property/Asset
    row is required (an empty @PropertyGuid resolves PropertyId=-1, which the INNER JOIN can
    never match). SJob.Assets is the real, fully-registered table, whose RowStatus column
    defaults to 0 (inactive) rather than 1 like most other tables here.

    SJob.AssetsUpsert calls SCore.UpsertDataObject with ObjectName='Assets' (SJob.Assets
    carries a disabled FK_Properties_DataObjects, same as SSop.Projects/SJob.Jobs), so this
    fixture needs a deterministic Guid - idempotent by Name for the natural-key conflict/
    inactive checks, then update-or-insert by that Guid so it flows through the
    @FixtureObjects atomic-insert-and-assert block below like Projects/Jobs do.
*/
DECLARE @AssetFixtureGuid uniqueidentifier = 'D4D00009-0000-4000-8000-000000000001';

IF EXISTS (SELECT 1 FROM SJob.Assets WHERE Name = N'CymBuild R4 Test Asset' AND Guid <> @AssetFixtureGuid)
BEGIN
    THROW 62074, N'The R4 Test Asset fixture conflicts with an existing asset.', 1;
END;

IF EXISTS (SELECT 1 FROM SJob.Assets WHERE Guid = @AssetFixtureGuid AND RowStatus IN (0, 254))
BEGIN
    THROW 62075, N'The R4 Test Asset fixture exists with an inactive RowStatus.', 1;
END;

UPDATE SJob.Assets
SET
    RowStatus = 1,
    Name = N'CymBuild R4 Test Asset'
WHERE Guid = @AssetFixtureGuid;

IF @@ROWCOUNT = 0
BEGIN
    INSERT INTO SJob.Assets (RowStatus, Guid, Name)
    VALUES (1, @AssetFixtureGuid, N'CymBuild R4 Test Asset');
END;

-- R4-CYB-543-Finance: one active Job so SageInboundReceiptMaterialisationFallbackTests'
-- invoice fixture can resolve a JobID for SFin.Transactions. Unlike the Account/OrgUnit
-- stubs above, SJob.Jobs is a DataObjects-tracked managed entity (registered in
-- SCore.EntityHobts above with the real production Jobs EntityType Guid), so it needs a
-- deterministic Guid - idempotent by Number for the natural-key conflict/inactive checks,
-- then update-or-insert by that Guid so it flows through the @FixtureObjects
-- atomic-insert-and-assert block below like every other tracked entity type in this file.
DECLARE @JobFixtureGuid uniqueidentifier = 'D4D00008-0000-4000-8000-000000000001';

IF EXISTS (SELECT 1 FROM SJob.Jobs WHERE Number = N'CYB543-R4-TEST-JOB' AND Guid <> @JobFixtureGuid)
BEGIN
    THROW 62062, N'The R4 Finance test Job fixture conflicts with an existing job.', 1;
END;

IF EXISTS (SELECT 1 FROM SJob.Jobs WHERE Guid = @JobFixtureGuid AND RowStatus IN (0, 254))
BEGIN
    THROW 62066, N'The R4 Finance test Job fixture exists with an inactive RowStatus.', 1;
END;

UPDATE SJob.Jobs
SET
    RowStatus = 1,
    Number = N'CYB543-R4-TEST-JOB',
    SurveyorID = -1,
    JobDescription = N'CymBuild R4 Finance test job'
WHERE Guid = @JobFixtureGuid;

IF @@ROWCOUNT = 0
BEGIN
    INSERT INTO SJob.Jobs (RowStatus, Guid, Number, SurveyorID, JobDescription)
    VALUES (1, @JobFixtureGuid, N'CYB543-R4-TEST-JOB', -1, N'CymBuild R4 Finance test job');
END;

-- R4-CYB-543-Finance: one active CreditTerms row so the same invoice fixture can
-- resolve a CreditTermsId. Idempotent by Name; no stable Guid column exists on the
-- compatibility stub table.
IF NOT EXISTS (SELECT 1 FROM SFin.CreditTerms WHERE Name = N'CymBuild R4 Finance Test Credit Terms')
BEGIN
    INSERT INTO SFin.CreditTerms (Name)
    VALUES (N'CymBuild R4 Finance Test Credit Terms');
END;

IF EXISTS (SELECT 1 FROM SFin.CreditTerms WHERE Name = N'CymBuild R4 Finance Test Credit Terms' AND RowStatus IN (0, 254))
BEGIN
    THROW 62063, N'The R4 Finance test CreditTerms fixture exists with an inactive RowStatus.', 1;
END;

-- R4-CYB-543-Finance: one active, active-flagged VatCodes row so the same invoice
-- fixture can resolve a VatCodeId. Idempotent by SageVatNo; no stable Guid column
-- exists on the compatibility stub table.
IF NOT EXISTS (SELECT 1 FROM SFin.VatCodes WHERE SageVatNo = N'R4TEST')
BEGIN
    INSERT INTO SFin.VatCodes (SageVatNo)
    VALUES (N'R4TEST');
END;

IF EXISTS (SELECT 1 FROM SFin.VatCodes WHERE SageVatNo = N'R4TEST' AND (RowStatus IN (0, 254) OR Active = 0))
BEGIN
    THROW 62064, N'The R4 Finance test VatCodes fixture exists with an inactive RowStatus or Active flag.', 1;
END;

-- R4-CYB-543-Finance: an active, bank-side Receipt TransactionType so
-- SFin.SageInboundReceiptAndAllocation_Materialise can resolve the finance
-- TransactionType it materialises Sage receipts/credit notes as.
IF NOT EXISTS (SELECT 1 FROM SFin.TransactionTypes WHERE Name = N'Receipt')
BEGIN
    INSERT INTO SFin.TransactionTypes (Name, IsActive, IsBank)
    VALUES (N'Receipt', 1, 1);
END;

IF EXISTS (SELECT 1 FROM SFin.TransactionTypes WHERE Name = N'Receipt' AND (RowStatus IN (0, 254) OR IsActive = 0))
BEGIN
    THROW 62065, N'The R4 Finance test Receipt TransactionType fixture exists with an inactive RowStatus or IsActive flag.', 1;
END;

-- R4-CYB-555-Finance: an active, non-bank, negated Credit Note TransactionType so Sage type 5
-- rows materialise as Credit Notes, not Receipts. IsNegated = 1 is the sign convention
-- SFin.SageInboundReceiptAndAllocation_Materialise relies on, and it keeps credit notes out of
-- SFin.TransactionDetailsUpsert's job fee-cap guard.
IF NOT EXISTS (SELECT 1 FROM SFin.TransactionTypes WHERE Name = N'Credit Note')
BEGIN
    INSERT INTO SFin.TransactionTypes (Name, IsActive, IsBank, IsNegated)
    VALUES (N'Credit Note', 1, 0, 1);
END;

IF EXISTS (SELECT 1 FROM SFin.TransactionTypes WHERE Name = N'Credit Note' AND (RowStatus IN (0, 254) OR IsActive = 0 OR IsNegated = 0))
BEGIN
    THROW 62076, N'The R4 Finance test Credit Note TransactionType fixture exists with an inactive RowStatus, IsActive or IsNegated flag.', 1;
END;

/*
    R5 slice 2 (Enquiry authorisation-routing): two OrganisationalUnits so the test can
    prove that only the org unit with its own SCore.Workflow row reaching the
    AuthorisationNeeded status (Fire Engineering) surfaces in
    SCore.tvf_WF_AuthorisationQueue, while an org unit with no such Workflow row at all
    (CDM) never can - matching the real production Fire-Engineering-vs-CDM Enquiries
    workflow config. No stable Guid column exists on the compatibility stub table, so
    these are idempotent by Name like the R4 Test OrgUnit fixture above.
*/
IF NOT EXISTS (SELECT 1 FROM SCore.OrganisationalUnits WHERE Name = N'R4 Test Fire Engineering OrgUnit')
BEGIN
    INSERT INTO SCore.OrganisationalUnits (RowStatus, Name)
    VALUES (1, N'R4 Test Fire Engineering OrgUnit');
END;

IF EXISTS (SELECT 1 FROM SCore.OrganisationalUnits WHERE Name = N'R4 Test Fire Engineering OrgUnit' AND RowStatus IN (0, 254))
BEGIN
    THROW 62069, N'The R4 Fire Engineering OrgUnit fixture exists with an inactive RowStatus.', 1;
END;

IF NOT EXISTS (SELECT 1 FROM SCore.OrganisationalUnits WHERE Name = N'R4 Test CDM OrgUnit')
BEGIN
    INSERT INTO SCore.OrganisationalUnits (RowStatus, Name)
    VALUES (1, N'R4 Test CDM OrgUnit');
END;

IF EXISTS (SELECT 1 FROM SCore.OrganisationalUnits WHERE Name = N'R4 Test CDM OrgUnit' AND RowStatus IN (0, 254))
BEGIN
    THROW 62070, N'The R4 CDM OrgUnit fixture exists with an inactive RowStatus.', 1;
END;

DECLARE @EnquiriesEntityTypeId int = (SELECT ID FROM SCore.EntityTypes WHERE Name = N'Enquiries');
DECLARE @FireEngineeringOrgUnitId int = (SELECT ID FROM SCore.OrganisationalUnits WHERE Name = N'R4 Test Fire Engineering OrgUnit');

-- No SCore.Workflow row is ever created for the CDM OrgUnit + Enquiries EntityType -
-- that absence is exactly what makes a CDM enquiry unable to reach the queue.
IF NOT EXISTS (SELECT 1 FROM SCore.Workflow WHERE Name = N'R4 Test Fire Engineering Enquiries Workflow')
BEGIN
    INSERT INTO SCore.Workflow (RowStatus, OrganisationalUnitId, EntityTypeID, Name, Enabled)
    VALUES (1, @FireEngineeringOrgUnitId, @EnquiriesEntityTypeId, N'R4 Test Fire Engineering Enquiries Workflow', 1);
END;

IF EXISTS (SELECT 1 FROM SCore.Workflow WHERE Name = N'R4 Test Fire Engineering Enquiries Workflow' AND RowStatus IN (0, 254))
BEGIN
    THROW 62071, N'The R4 Fire Engineering Enquiries Workflow fixture exists with an inactive RowStatus.', 1;
END;

DECLARE @FireEngineeringWorkflowId int = (SELECT ID FROM SCore.Workflow WHERE Name = N'R4 Test Fire Engineering Enquiries Workflow');

IF NOT EXISTS (SELECT 1 FROM SCore.WorkflowTransition WHERE WorkflowID = @FireEngineeringWorkflowId AND ToStatusID = (SELECT ID FROM SCore.WorkflowStatus WHERE Guid = @EnquiryAuthNeededStatusGuid))
BEGIN
    INSERT INTO SCore.WorkflowTransition (RowStatus, WorkflowID, ToStatusID, Enabled)
    VALUES (1, @FireEngineeringWorkflowId, (SELECT ID FROM SCore.WorkflowStatus WHERE Guid = @EnquiryAuthNeededStatusGuid), 1);
END;

-- SCore.tvf_WF_AuthorisationQueue's GroupMap CTE inner-joins WorkflowStatusNotificationGroups,
-- so at least one active mapping must exist for the Fire Engineering workflow/status pair -
-- reuse the existing R4 test Group; the test calls tvf_WF_AuthorisationQueue with a NULL
-- @UserId, so no SCore.UserGroups membership is required for the row to surface.
IF NOT EXISTS
(
    SELECT 1
    FROM SCore.WorkflowStatusNotificationGroups
    WHERE WorkflowID = @FireEngineeringWorkflowId
      AND WorkflowStatusGuid = @EnquiryAuthNeededStatusGuid
)
BEGIN
    INSERT INTO SCore.WorkflowStatusNotificationGroups (RowStatus, WorkflowID, WorkflowStatusGuid, GroupID, CanAction)
    VALUES (1, @FireEngineeringWorkflowId, @EnquiryAuthNeededStatusGuid, (SELECT ID FROM SCore.Groups WHERE Guid = @GroupGuid), 1);
END;

-- R5 slice 2: SOffice.TargetObjectUpsert resolves this real production EntityTypeGuid
-- (hardcoded in SSop.EnquiriesUpsert's SOffice.TargetObjectUpsert call) to a SOffice
-- EntityTypeId; TargetObjects.EntityTypeId is NOT NULL, so the row must exist.
IF NOT EXISTS (SELECT 1 FROM SOffice.EntityTypes WHERE Guid = '3B4F2DF9-B6CF-4A49-9EED-2206473867A1')
BEGIN
    INSERT INTO SOffice.EntityTypes (Guid, RowStatus, Name)
    VALUES ('3B4F2DF9-B6CF-4A49-9EED-2206473867A1', 1, N'Enquiries');
END;

-- CYB-576: SSop.QuotesUpsert files every new quote through SOffice.TargetObjectUpsert under the
-- real Quotes entity type Guid.
IF NOT EXISTS (SELECT 1 FROM SOffice.EntityTypes WHERE Guid = '1C4794C1-F956-4C32-B886-5500AC778A56')
BEGIN
    INSERT INTO SOffice.EntityTypes (Guid, RowStatus, Name)
    VALUES ('1C4794C1-F956-4C32-B886-5500AC778A56', 1, N'Quotes');
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
    (@SystemIdentityGuid,  'D4D00001-0000-4000-8000-000000000004'),
    (@FirstStatusGuid,     'D4D00001-0000-4000-8000-000000000005'),
    (@SecondStatusGuid,    'D4D00001-0000-4000-8000-000000000005'),
    (@NonActivityTypeGuid, 'D4D00001-0000-4000-8000-000000000006'),
    (@JobStatus_ClosureRequest, 'D4D00001-0000-4000-8000-000000000005'),
    (@JobStatus_ApproveClosure, 'D4D00001-0000-4000-8000-000000000005'),
    (@JobStatus_Completed,      'D4D00001-0000-4000-8000-000000000005'),
    (@JobStatus_ClosureRejected, 'D4D00001-0000-4000-8000-000000000005'),
    -- R4-CYB-543-Finance: real production Jobs EntityType Guid, matching the SJob.Jobs
    -- SCore.EntityHobts registration above.
    (@JobFixtureGuid, '63542427-46AB-4078-ABD1-1D583C24315C'),
    -- R5 slice 2 (Enquiry authorisation-routing): the two new Enquiry WorkflowStatus
    -- fixtures are DataObjects-tracked like every other WorkflowStatus row above.
    (@EnquiryNewStatusGuid, 'D4D00001-0000-4000-8000-000000000005'),
    (@EnquiryAuthNeededStatusGuid, 'D4D00001-0000-4000-8000-000000000005'),
    -- R5 slice 2: SJob.Assets is DataObjects-tracked via SJob.AssetsUpsert in production
    -- (see the SCore.EntityHobts registration above).
    (@AssetFixtureGuid, 'D4D00007-0000-4000-8000-000000000007');

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
        'D4D00002-0000-4000-8000-000000000008',
        'D4D00002-0000-4000-8000-000000000009'
    )
      AND RowStatus NOT IN (0, 254)
) <> 3
BEGIN
    THROW 62057, N'The required NonActivityEvents, DataObjectTransition and Jobs EntityHobts fixtures were not created.', 1;
END;


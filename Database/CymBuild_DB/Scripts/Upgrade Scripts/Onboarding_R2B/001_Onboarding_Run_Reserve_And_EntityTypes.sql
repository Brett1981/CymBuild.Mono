SET XACT_ABORT ON;
GO

IF COL_LENGTH(N'SCore.EntityTypes', N'IsOnBoarding') IS NULL
BEGIN
    ALTER TABLE SCore.EntityTypes
    ADD IsOnBoarding BIT NOT NULL
        CONSTRAINT DF_EntityTypes_IsOnBoarding DEFAULT (0);
END;
GO

IF COL_LENGTH(N'SMigration.Onboarding_Run', N'RowStatus') IS NULL
BEGIN
    ALTER TABLE SMigration.Onboarding_Run
    ADD RowStatus TINYINT NOT NULL
        CONSTRAINT DF_SMigration_Onboarding_Run_RowStatus DEFAULT (1);
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes AS i
    WHERE i.name = N'IX_SMigration_Onboarding_Run_Active'
      AND i.object_id = OBJECT_ID(N'SMigration.Onboarding_Run')
)
BEGIN
    CREATE INDEX IX_SMigration_Onboarding_Run_Active
        ON SMigration.Onboarding_Run (CreatedUtc DESC, SourceDatabase, TargetDatabaseName)
        WHERE RowStatus <> 0 AND RowStatus <> 254;
END;
GO

UPDATE et
SET IsOnBoarding = 1
FROM SCore.EntityTypes AS et
WHERE et.RowStatus NOT IN (0,254)
  AND et.Name IN
  (
      N'Groups',
      N'Addresses',
      N'Contacts',
      N'OrganisationalUnits',
      N'Identities',
      N'UserGroups',
      N'WorkflowStatusNotificationGroups',
      N'JobTypes',
      N'ActivityTypes',
      N'MilestoneTypes',
      N'JobTypeActivityTypes',
      N'JobTypeMilestoneTemplates',
      N'Products',
      N'ProductJobActivities'
  )
  AND ISNULL(et.IsOnBoarding, 0) <> 1;
GO

DECLARE @RunGuid UNIQUEIDENTIFIER;

DECLARE run_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT r.RunGuid
    FROM SMigration.Onboarding_Run AS r
    WHERE r.RowStatus NOT IN (0,254);

OPEN run_cursor;
FETCH NEXT FROM run_cursor INTO @RunGuid;

WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC SMigration.MetadataDataObject_Ensure
        @Guid = @RunGuid,
        @SchemeName = N'SMigration',
        @ObjectName = N'Onboarding_Run';

    FETCH NEXT FROM run_cursor INTO @RunGuid;
END;

CLOSE run_cursor;
DEALLOCATE run_cursor;
GO

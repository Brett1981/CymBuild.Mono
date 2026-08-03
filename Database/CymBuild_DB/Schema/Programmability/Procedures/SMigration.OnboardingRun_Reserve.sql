SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[OnboardingRun_Reserve]')
GO
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[OnboardingRun_Reserve]')
GO

CREATE PROCEDURE [SMigration].[OnboardingRun_Reserve]
(
    @RunGuid UNIQUEIDENTIFIER = NULL,
    @SourceDatabase SYSNAME,
    @BusinessUnitGroupGuid UNIQUEIDENTIFIER,
    @SourceServerName SYSNAME = N'',
    @TargetServerName SYSNAME = N'',
    @TargetDatabaseName SYSNAME = N'',
    @SourceBusinessUnitOrganisationalUnitGuid UNIQUEIDENTIFIER = NULL,
    @Notes NVARCHAR(1000) = N''
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @RunGuid IS NULL
        SET @RunGuid = NEWID();

    IF @RunGuid = '00000000-0000-0000-0000-000000000000'
        THROW 62220, 'RunGuid must not be the empty Guid.', 1;

    IF ISNULL(@SourceDatabase, N'') = N''
        THROW 62221, 'SourceDatabase is required to reserve an OnBoarding run.', 1;

    IF @BusinessUnitGroupGuid IS NULL OR @BusinessUnitGroupGuid = '00000000-0000-0000-0000-000000000000'
        THROW 62222, 'BusinessUnitGroupGuid is required to reserve an OnBoarding run.', 1;

    EXEC SMigration.MetadataDataObject_Ensure
        @Guid = @RunGuid,
        @SchemeName = N'SMigration',
        @ObjectName = N'Onboarding_Run';

    IF EXISTS
    (
        SELECT 1
        FROM SMigration.Onboarding_Run AS existing
        WHERE existing.RunGuid = @RunGuid
    )
    BEGIN
        UPDATE SMigration.Onboarding_Run
        SET
            RowStatus = CASE WHEN RowStatus IN (0,254) THEN 1 ELSE RowStatus END,
            SourceServerName = ISNULL(@SourceServerName, N''),
            SourceDatabase = @SourceDatabase,
            TargetServerName = ISNULL(@TargetServerName, N''),
            TargetDatabaseName = ISNULL(@TargetDatabaseName, N''),
            SourceBusinessUnitGroupGuid = @BusinessUnitGroupGuid,
            SourceBusinessUnitOrganisationalUnitGuid = @SourceBusinessUnitOrganisationalUnitGuid,
            Notes = ISNULL(@Notes, N'')
        WHERE RunGuid = @RunGuid;
    END
    ELSE
    BEGIN
        INSERT INTO SMigration.Onboarding_Run
        (
            RunGuid,
            RowStatus,
            SourceServerName,
            SourceDatabase,
            TargetServerName,
            TargetDatabaseName,
            SourceBusinessUnitGroupGuid,
            SourceBusinessUnitOrganisationalUnitGuid,
            Notes
        )
        VALUES
        (
            @RunGuid,
            1,
            ISNULL(@SourceServerName, N''),
            @SourceDatabase,
            ISNULL(@TargetServerName, N''),
            ISNULL(@TargetDatabaseName, N''),
            @BusinessUnitGroupGuid,
            @SourceBusinessUnitOrganisationalUnitGuid,
            ISNULL(@Notes, N'')
        );
    END;

    SELECT
        r.RunGuid,
        r.CreatedUtc,
        r.SourceServerName,
        r.SourceDatabase,
        r.TargetServerName,
        r.TargetDatabaseName,
        r.SourceBusinessUnitGroupGuid,
        r.SourceBusinessUnitOrganisationalUnitGuid,
        r.Notes,
        r.CreatedBy
    FROM SMigration.Onboarding_Run AS r
    WHERE r.RunGuid = @RunGuid
      AND r.RowStatus NOT IN (0,254);
END
GO
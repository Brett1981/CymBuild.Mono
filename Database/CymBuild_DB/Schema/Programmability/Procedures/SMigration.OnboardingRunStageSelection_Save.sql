SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[OnboardingRunStageSelection_Save]')
GO
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[OnboardingRunStageSelection_Save]')
GO

CREATE PROCEDURE [SMigration].[OnboardingRunStageSelection_Save]
(
    @RunGuid UNIQUEIDENTIFIER,
    @SelectionsJson NVARCHAR(MAX)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @RunGuid IS NULL
        THROW 62410, 'RunGuid is required to save OnBoarding row selections.', 1;

    IF ISNULL(@SelectionsJson, N'') = N'' OR ISJSON(@SelectionsJson) <> 1
        THROW 62411, 'SelectionsJson must be a valid JSON array.', 1;

    DECLARE @Requested TABLE
    (
        EntityName NVARCHAR(200) NOT NULL,
        RowGuid UNIQUEIDENTIFIER NOT NULL,
        PRIMARY KEY (EntityName, RowGuid)
    );

    INSERT INTO @Requested
    (
        EntityName,
        RowGuid
    )
    SELECT DISTINCT
        EntityName = LTRIM(RTRIM(JSON_VALUE(value, N'$.EntityName'))),
        RowGuid = TRY_CONVERT(UNIQUEIDENTIFIER, JSON_VALUE(value, N'$.RowGuid'))
    FROM OPENJSON(@SelectionsJson)
    WHERE ISNULL(LTRIM(RTRIM(JSON_VALUE(value, N'$.EntityName'))), N'') <> N''
      AND TRY_CONVERT(UNIQUEIDENTIFIER, JSON_VALUE(value, N'$.RowGuid')) IS NOT NULL;

    BEGIN TRANSACTION;

    UPDATE SMigration.Onboarding_RunStageSelections
    SET RowStatus = 254
    WHERE RunGuid = @RunGuid
      AND RowStatus NOT IN (0,254)
      AND NOT EXISTS
      (
          SELECT 1
          FROM @Requested AS requested
          WHERE requested.EntityName = SMigration.Onboarding_RunStageSelections.EntityName
            AND requested.RowGuid = SMigration.Onboarding_RunStageSelections.RowGuid
      );

    DECLARE
        @EntityName NVARCHAR(200),
        @RowGuid UNIQUEIDENTIFIER,
        @SelectionGuid UNIQUEIDENTIFIER;

    DECLARE selection_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT requested.EntityName, requested.RowGuid
        FROM @Requested AS requested
        ORDER BY requested.EntityName, requested.RowGuid;

    OPEN selection_cursor;
    FETCH NEXT FROM selection_cursor INTO @EntityName, @RowGuid;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT TOP (1)
            @SelectionGuid = existing.Guid
        FROM SMigration.Onboarding_RunStageSelections AS existing
        WHERE existing.RunGuid = @RunGuid
          AND existing.EntityName = @EntityName
          AND existing.RowGuid = @RowGuid;

        SET @SelectionGuid = ISNULL(@SelectionGuid, NEWID());

        EXEC SMigration.MetadataDataObject_Ensure
            @Guid = @SelectionGuid,
            @SchemeName = N'SMigration',
            @ObjectName = N'Onboarding_RunStageSelections';

        IF EXISTS
        (
            SELECT 1
            FROM SMigration.Onboarding_RunStageSelections AS existing
            WHERE existing.RunGuid = @RunGuid
              AND existing.EntityName = @EntityName
              AND existing.RowGuid = @RowGuid
        )
        BEGIN
            UPDATE SMigration.Onboarding_RunStageSelections
            SET
                RowStatus = 1,
                SelectedByUserId = ISNULL(SCore.GetCurrentUserId(), -1),
                SelectedOnUtc = SYSUTCDATETIME()
            WHERE RunGuid = @RunGuid
              AND EntityName = @EntityName
              AND RowGuid = @RowGuid;
        END
        ELSE
        BEGIN
            INSERT INTO SMigration.Onboarding_RunStageSelections
            (
                Guid,
                RowStatus,
                RunGuid,
                EntityName,
                RowGuid,
                SelectedByUserId,
                SelectedOnUtc
            )
            VALUES
            (
                @SelectionGuid,
                1,
                @RunGuid,
                @EntityName,
                @RowGuid,
                ISNULL(SCore.GetCurrentUserId(), -1),
                SYSUTCDATETIME()
            );
        END;

        SET @SelectionGuid = NULL;
        FETCH NEXT FROM selection_cursor INTO @EntityName, @RowGuid;
    END;

    CLOSE selection_cursor;
    DEALLOCATE selection_cursor;

    COMMIT TRANSACTION;

    EXEC SMigration.OnboardingRunStageSelection_List @RunGuid = @RunGuid;
END;
GO
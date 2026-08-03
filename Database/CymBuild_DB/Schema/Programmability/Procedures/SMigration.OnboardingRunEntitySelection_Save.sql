SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[OnboardingRunEntitySelection_Save]')
GO
PRINT (N'Create procedure [SMigration].[OnboardingRunEntitySelection_Save]')
GO

CREATE PROCEDURE [SMigration].[OnboardingRunEntitySelection_Save]
(
    @RunGuid UNIQUEIDENTIFIER,
    @SelectionsJson NVARCHAR(MAX)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @RunGuid IS NULL
        THROW 62220, 'RunGuid is required to save OnBoarding entity selections.', 1;

    IF ISNULL(@SelectionsJson, N'') = N'' OR ISJSON(@SelectionsJson) <> 1
        THROW 62221, 'SelectionsJson must be a valid JSON array.', 1;

    EXEC SMigration.OnboardingRunEntitySelection_Default @RunGuid = @RunGuid;

    DECLARE @Requested TABLE
    (
        EntityCode NVARCHAR(100) NOT NULL PRIMARY KEY,
        IsSelected BIT NOT NULL
    );

    INSERT INTO @Requested
    (
        EntityCode,
        IsSelected
    )
    SELECT
        LTRIM(RTRIM(JSON_VALUE(value, N'$.EntityCode'))) AS EntityCode,
        CONVERT(BIT,
            CASE
                WHEN LOWER(ISNULL(JSON_VALUE(value, N'$.IsSelected'), N'')) IN (N'true', N'1') THEN 1
                ELSE 0
            END) AS IsSelected
    FROM OPENJSON(@SelectionsJson)
    WHERE ISNULL(LTRIM(RTRIM(JSON_VALUE(value, N'$.EntityCode'))), N'') <> N'';

    IF NOT EXISTS (SELECT 1 FROM @Requested)
        THROW 62222, 'At least one OnBoarding entity selection is required.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM @Requested AS requested
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM SMigration.Onboarding_EntityScope AS scope
            WHERE scope.Code = requested.EntityCode
              AND scope.RowStatus NOT IN (0,254)
              AND scope.IsSupportData = 0
        )
    )
    BEGIN
        THROW 62223, 'One or more requested OnBoarding entity selections is not registered in SMigration.Onboarding_EntityScope.', 1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM @Requested AS requested
        INNER JOIN SMigration.Onboarding_EntityScope AS scope
            ON scope.Code = requested.EntityCode
           AND scope.RowStatus NOT IN (0,254)
           AND scope.IsSupportData = 0
        WHERE requested.IsSelected = 0
          AND (scope.CanDeselect = 0 OR scope.IsRequired = 1)
    )
    BEGIN
        THROW 62224, 'One or more required OnBoarding entity scopes cannot be deselected.', 1;
    END;

    DECLARE @Final TABLE
    (
        EntityScopeGuid UNIQUEIDENTIFIER NOT NULL,
        EntityCode NVARCHAR(100) NOT NULL PRIMARY KEY,
        EntityName NVARCHAR(200) NOT NULL,
        RequiredDependencyCodes NVARCHAR(1000) NOT NULL,
        IsSelected BIT NOT NULL
    );

    INSERT INTO @Final
    (
        EntityScopeGuid,
        EntityCode,
        EntityName,
        RequiredDependencyCodes,
        IsSelected
    )
    SELECT
        scope.Guid,
        scope.Code,
        scope.Name,
        scope.RequiredDependencyCodes,
        CONVERT(BIT, COALESCE(requested.IsSelected, currentSelection.IsSelected, scope.DefaultSelected)) AS IsSelected
    FROM SMigration.Onboarding_EntityScope AS scope
    LEFT JOIN SMigration.Onboarding_RunEntitySelections AS currentSelection
        ON currentSelection.RunGuid = @RunGuid
       AND currentSelection.EntityCode = scope.Code
       AND currentSelection.RowStatus NOT IN (0,254)
    LEFT JOIN @Requested AS requested
        ON requested.EntityCode = scope.Code
    WHERE scope.RowStatus NOT IN (0,254)
      AND scope.IsSupportData = 0;

    DECLARE @DependencyErrors NVARCHAR(MAX) = N'';

    ;WITH DependencyRows AS
    (
        SELECT
            selected.EntityCode,
            selected.EntityName,
            DependencyCode = LTRIM(RTRIM(split.value))
        FROM @Final AS selected
        CROSS APPLY STRING_SPLIT(selected.RequiredDependencyCodes, N',') AS split
        WHERE selected.IsSelected = 1
          AND ISNULL(LTRIM(RTRIM(split.value)), N'') <> N''
    ), MissingDependencies AS
    (
        SELECT
            dependency.EntityCode,
            dependency.EntityName,
            dependency.DependencyCode
        FROM DependencyRows AS dependency
        LEFT JOIN @Final AS requiredScope
            ON requiredScope.EntityCode = dependency.DependencyCode
           AND requiredScope.IsSelected = 1
        WHERE requiredScope.EntityCode IS NULL
    )
    SELECT
        @DependencyErrors = STRING_AGG(CONCAT(EntityCode, N' requires ', DependencyCode), N'; ')
    FROM MissingDependencies;

    IF ISNULL(@DependencyErrors, N'') <> N''
    BEGIN
        DECLARE @DependencyMessage NVARCHAR(2048) = LEFT(CONCAT(N'OnBoarding entity scope dependency validation failed: ', @DependencyErrors), 2048);
        THROW 62225, @DependencyMessage, 1;
    END;

    DECLARE
        @EntityScopeGuid UNIQUEIDENTIFIER,
        @EntityCode NVARCHAR(100),
        @IsSelected BIT,
        @SelectionGuid UNIQUEIDENTIFIER;

    DECLARE save_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            final.EntityScopeGuid,
            final.EntityCode,
            final.IsSelected,
            existing.Guid AS SelectionGuid
        FROM @Final AS final
        LEFT JOIN SMigration.Onboarding_RunEntitySelections AS existing
            ON existing.RunGuid = @RunGuid
           AND existing.EntityCode = final.EntityCode
        ORDER BY final.EntityCode;

    OPEN save_cursor;
    FETCH NEXT FROM save_cursor INTO @EntityScopeGuid, @EntityCode, @IsSelected, @SelectionGuid;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @SelectionGuid = ISNULL(@SelectionGuid, NEWID());

        EXEC SMigration.MetadataDataObject_Ensure
            @Guid = @SelectionGuid,
            @SchemeName = N'SMigration',
            @ObjectName = N'Onboarding_RunEntitySelections';

        IF EXISTS
        (
            SELECT 1
            FROM SMigration.Onboarding_RunEntitySelections AS existing
            WHERE existing.RunGuid = @RunGuid
              AND existing.EntityCode = @EntityCode
        )
        BEGIN
            UPDATE SMigration.Onboarding_RunEntitySelections
            SET
                RowStatus = 1,
                EntityScopeGuid = @EntityScopeGuid,
                IsSelected = @IsSelected,
                SelectionSource = N'Manual',
                SelectedByUserId = ISNULL(SCore.GetCurrentUserId(), -1),
                SelectedOnUtc = SYSUTCDATETIME()
            WHERE RunGuid = @RunGuid
              AND EntityCode = @EntityCode;
        END
        ELSE
        BEGIN
            INSERT INTO SMigration.Onboarding_RunEntitySelections
            (
                Guid,
                RowStatus,
                RunGuid,
                EntityScopeGuid,
                EntityCode,
                IsSelected,
                SelectionSource,
                SelectedByUserId,
                SelectedOnUtc
            )
            VALUES
            (
                @SelectionGuid,
                1,
                @RunGuid,
                @EntityScopeGuid,
                @EntityCode,
                @IsSelected,
                N'Manual',
                ISNULL(SCore.GetCurrentUserId(), -1),
                SYSUTCDATETIME()
            );
        END;

        FETCH NEXT FROM save_cursor INTO @EntityScopeGuid, @EntityCode, @IsSelected, @SelectionGuid;
    END;

    CLOSE save_cursor;
    DEALLOCATE save_cursor;

    EXEC SMigration.OnboardingRunEntitySelection_List @RunGuid = @RunGuid;
END;
GO
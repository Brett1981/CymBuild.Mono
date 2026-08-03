SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[OnboardingRunEntitySelection_Default]')
GO
PRINT (N'Create procedure [SMigration].[OnboardingRunEntitySelection_Default]')
GO

CREATE PROCEDURE [SMigration].[OnboardingRunEntitySelection_Default]
(
    @RunGuid UNIQUEIDENTIFIER
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @RunGuid IS NULL
        THROW 62200, 'RunGuid is required for OnBoarding entity selection defaults.', 1;

    EXEC SMigration.OnboardingEntityScope_Seed;

    DECLARE
        @SelectionGuid UNIQUEIDENTIFIER,
        @EntityScopeGuid UNIQUEIDENTIFIER,
        @EntityCode NVARCHAR(100),
        @DefaultSelected BIT;

    DECLARE selection_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            NEWID() AS SelectionGuid,
            es.Guid AS EntityScopeGuid,
            es.Code AS EntityCode,
            es.DefaultSelected
        FROM SMigration.Onboarding_EntityScope AS es
        WHERE es.RowStatus NOT IN (0,254)
          AND es.IsSupportData = 0
          AND NOT EXISTS
          (
              SELECT 1
              FROM SMigration.Onboarding_RunEntitySelections AS existing
              WHERE existing.RunGuid = @RunGuid
                AND existing.EntityCode = es.Code
          )
        ORDER BY es.DisplayOrder;

    OPEN selection_cursor;
    FETCH NEXT FROM selection_cursor INTO @SelectionGuid, @EntityScopeGuid, @EntityCode, @DefaultSelected;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC SMigration.MetadataDataObject_Ensure
            @Guid = @SelectionGuid,
            @SchemeName = N'SMigration',
            @ObjectName = N'Onboarding_RunEntitySelections';

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
            @DefaultSelected,
            N'Default',
            ISNULL(SCore.GetCurrentUserId(), -1),
            SYSUTCDATETIME()
        );

        FETCH NEXT FROM selection_cursor INTO @SelectionGuid, @EntityScopeGuid, @EntityCode, @DefaultSelected;
    END;

    CLOSE selection_cursor;
    DEALLOCATE selection_cursor;

    UPDATE sel
    SET
        RowStatus = CASE WHEN sel.RowStatus IN (0,254) THEN 1 ELSE sel.RowStatus END,
        EntityScopeGuid = es.Guid
    FROM SMigration.Onboarding_RunEntitySelections AS sel
    INNER JOIN SMigration.Onboarding_EntityScope AS es
        ON es.Code = sel.EntityCode
       AND es.RowStatus NOT IN (0,254)
       AND es.IsSupportData = 0
    WHERE sel.RunGuid = @RunGuid;
END;
GO
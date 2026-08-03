SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[OnboardingRunEntitySelection_List]')
GO
PRINT (N'Create procedure [SMigration].[OnboardingRunEntitySelection_List]')
GO

CREATE PROCEDURE [SMigration].[OnboardingRunEntitySelection_List]
(
    @RunGuid UNIQUEIDENTIFIER
)
AS
BEGIN
    SET NOCOUNT ON;

    IF @RunGuid IS NULL
        THROW 62210, 'RunGuid is required to list OnBoarding entity selections.', 1;

    EXEC SMigration.OnboardingEntityScope_Seed;

    SELECT
        es.Guid AS EntityScopeGuid,
        es.Code AS EntityCode,
        es.Name AS EntityName,
        es.Description,
        es.StageTableName,
        es.DisplayOrder,
        CONVERT(BIT, ISNULL(sel.IsSelected, es.DefaultSelected)) AS IsSelected,
        es.DefaultSelected,
        es.CanDeselect,
        es.IsRequired,
        es.RequiredDependencyCodes,
        sel.Guid AS SelectionGuid,
        ISNULL(sel.SelectionSource, N'Default') AS SelectionSource,
        ISNULL(CONVERT(NVARCHAR(30), sel.SelectedOnUtc, 126), N'') AS SelectedOnUtc,
        es.Category,
        es.ScopeType,
        es.IsImplemented,
        es.IsSupportData,
        es.HandlerKey,
        es.PrimaryEntityTypeGuid,
        es.SourceSchemaName,
        es.SourceTableName
    FROM SMigration.Onboarding_EntityScope AS es
    LEFT JOIN SMigration.Onboarding_RunEntitySelections AS sel
        ON sel.RunGuid = @RunGuid
       AND sel.EntityCode = es.Code
       AND sel.RowStatus NOT IN (0,254)
    WHERE es.RowStatus NOT IN (0,254)
      AND es.IsSupportData = 0
    ORDER BY
        CASE es.Category
            WHEN N'Access Foundation' THEN 10
            WHEN N'Operational Configuration' THEN 20
            WHEN N'Additional Eligible Record Types' THEN 30
            WHEN N'Internal / Support Data' THEN 90
            ELSE 80
        END,
        es.DisplayOrder,
        es.Code;
END;
GO
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[OnboardingEntityScope_List]')
GO
PRINT (N'Create procedure [SMigration].[OnboardingEntityScope_List]')
GO

CREATE PROCEDURE [SMigration].[OnboardingEntityScope_List]
(
    @SearchText NVARCHAR(250) = N'',
    @IncludeInactive BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;

    EXEC SMigration.OnboardingEntityScope_Seed;

    DECLARE @SearchPattern NVARCHAR(252) = N'%' + ISNULL(@SearchText, N'') + N'%';

    SELECT
        es.Guid AS EntityScopeGuid,
        es.Code,
        es.Name,
        es.StageTableName,
        es.DisplayOrder,
        es.DefaultSelected,
        es.CanDeselect,
        es.IsRequired,
        es.RequiredDependencyCodes,
        es.Description,
        es.Category,
        es.ScopeType,
        es.IsImplemented,
        es.IsSupportData,
        es.HandlerKey,
        es.PrimaryEntityTypeGuid,
        es.SourceSchemaName,
        es.SourceTableName,
        CONVERT(INT, es.RowStatus) AS RowStatus
    FROM SMigration.Onboarding_EntityScope AS es
    WHERE
    (
        ISNULL(@IncludeInactive, 0) = 1
        OR (es.RowStatus NOT IN (0,254) AND es.IsSupportData = 0)
    )
      AND
      (
          ISNULL(@SearchText, N'') = N''
          OR es.Code LIKE @SearchPattern
          OR es.Name LIKE @SearchPattern
          OR es.Description LIKE @SearchPattern
          OR es.StageTableName LIKE @SearchPattern
          OR es.Category LIKE @SearchPattern
          OR es.ScopeType LIKE @SearchPattern
      )
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
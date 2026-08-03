SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[SchemaDeploymentPlan_Get]')
GO
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[SchemaDeploymentPlan_Get]')
GO

CREATE PROCEDURE [SMigration].[SchemaDeploymentPlan_Get]
(
    @RunGuid UNIQUEIDENTIFIER
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @HasExplicitSelection BIT =
    (
        SELECT
            CASE
                WHEN EXISTS
                (
                    SELECT 1
                    FROM SMigration.Schema_RunSelections AS rs
                    WHERE rs.RunGuid = @RunGuid
                      AND rs.RowStatus <> 0
                      AND rs.RowStatus <> 254
                ) THEN CONVERT(BIT, 1)
                ELSE CONVERT(BIT, 0)
            END
    );

    SELECT
        c.Guid AS ComparisonGuid,
        c.ObjectType,
        c.SchemaName,
        c.ObjectName,
        c.ParentObjectName,
        c.DifferenceType,
        c.SourceHash,
        c.TargetHash,
        c.SourceDefinition,
        c.TargetDefinition,
        c.IsDeployable,
        c.IsDestructiveRisk,
        CASE WHEN @HasExplicitSelection = 0 THEN CONVERT(BIT, 1) ELSE ISNULL(sel.IsSelected, CONVERT(BIT, 0)) END AS IsSelected,
        @HasExplicitSelection AS HasExplicitSelection
    FROM SMigration.Schema_ObjectComparisons AS c
    OUTER APPLY
    (
        SELECT TOP (1)
            rs.IsSelected
        FROM SMigration.Schema_RunSelections AS rs
        WHERE rs.RunGuid = c.RunGuid
          AND rs.ObjectType = c.ObjectType
          AND rs.SchemaName = c.SchemaName
          AND rs.ObjectName = c.ObjectName
          AND rs.ParentObjectName = c.ParentObjectName
          AND rs.RowStatus <> 0
          AND rs.RowStatus <> 254
        ORDER BY rs.ID DESC
    ) AS sel
    WHERE c.RunGuid = @RunGuid
      AND c.RowStatus <> 0
      AND c.RowStatus <> 254
      AND c.IsDeployable = 1
      AND c.DifferenceType <> N'Equal'
      AND (@HasExplicitSelection = 0 OR ISNULL(sel.IsSelected, CONVERT(BIT, 0)) = 1)
    ORDER BY
        CASE c.ObjectType
            WHEN N'Schema' THEN 10
            WHEN N'TableType' THEN 20
            WHEN N'Table' THEN 30
            WHEN N'Sequence' THEN 40
            WHEN N'Constraint' THEN 50
            WHEN N'Index' THEN 60
            WHEN N'View' THEN 70
            WHEN N'Function' THEN 80
            WHEN N'StoredProcedure' THEN 90
            WHEN N'Trigger' THEN 100
            ELSE 900
        END,
        c.SchemaName,
        c.ObjectName;
END;
GO
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create or alter procedure [SMigration].[SchemaDeploymentPlan_Get]')
GO

CREATE OR ALTER PROCEDURE [SMigration].[SchemaDeploymentPlan_Get]
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
                    FROM [SMigration].[Schema_RunSelections] AS selection
                    WHERE selection.[RunGuid] = @RunGuid
                      AND selection.[RowStatus] <> 0
                      AND selection.[RowStatus] <> 254
                ) THEN CONVERT(BIT, 1)
                ELSE CONVERT(BIT, 0)
            END
    );

    SELECT
        comparison.[Guid] AS [ComparisonGuid],
        comparison.[ObjectType],
        comparison.[SchemaName],
        comparison.[ObjectName],
        comparison.[ParentObjectName],
        comparison.[DifferenceType],
        comparison.[SourceHash],
        comparison.[TargetHash],
        comparison.[SourceDefinition],
        comparison.[TargetDefinition],
        comparison.[IsDeployable],
        comparison.[IsDestructiveRisk],
        CASE
            WHEN @HasExplicitSelection = 0 THEN CONVERT(BIT, 1)
            ELSE ISNULL(selectionState.[IsSelected], CONVERT(BIT, 0))
        END AS [IsSelected],
        @HasExplicitSelection AS [HasExplicitSelection]
    FROM [SMigration].[Schema_ObjectComparisons] AS comparison
    OUTER APPLY
    (
        SELECT TOP (1)
            selection.[IsSelected]
        FROM [SMigration].[Schema_RunSelections] AS selection
        WHERE selection.[RunGuid] = comparison.[RunGuid]
          AND selection.[ObjectType] = comparison.[ObjectType]
          AND selection.[SchemaName] = comparison.[SchemaName]
          AND selection.[ObjectName] = comparison.[ObjectName]
          AND selection.[ParentObjectName] = comparison.[ParentObjectName]
          AND selection.[RowStatus] <> 0
          AND selection.[RowStatus] <> 254
        ORDER BY selection.[ID] DESC
    ) AS selectionState
    WHERE comparison.[RunGuid] = @RunGuid
      AND comparison.[RowStatus] <> 0
      AND comparison.[RowStatus] <> 254
      AND comparison.[IsDeployable] = 1
      AND comparison.[DifferenceType] <> N'Equal'
      AND
      (
          @HasExplicitSelection = 0
          OR ISNULL(selectionState.[IsSelected], CONVERT(BIT, 0)) = 1
      )
      AND NOT EXISTS
      (
          SELECT 1
          FROM [SMigration].[Schema_ExcludedObjects] AS excluded
          WHERE excluded.[ObjectType] = comparison.[ObjectType]
            AND excluded.[SchemaName] = comparison.[SchemaName]
            AND excluded.[ObjectName] = comparison.[ObjectName]
            AND excluded.[ParentObjectName] = comparison.[ParentObjectName]
            AND excluded.[RowStatus] <> 0
            AND excluded.[RowStatus] <> 254
      )
    ORDER BY
        CASE comparison.[ObjectType]
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
        comparison.[SchemaName],
        comparison.[ObjectName];
END;
GO

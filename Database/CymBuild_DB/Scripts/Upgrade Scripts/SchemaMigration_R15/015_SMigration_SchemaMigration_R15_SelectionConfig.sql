SET XACT_ABORT ON;
GO

IF SCHEMA_ID(N'SMigration') IS NULL
BEGIN
    EXEC(N'CREATE SCHEMA [SMigration];');
END;
GO

IF OBJECT_ID(N'[SMigration].[Schema_RunSelections]', N'U') IS NULL
BEGIN
    CREATE TABLE [SMigration].[Schema_RunSelections]
    (
        [ID] [bigint] IDENTITY(1, 1) NOT NULL,
        [Guid] [uniqueidentifier] NOT NULL,
        [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Schema_RunSelections_RowStatus] DEFAULT (1),
        [RunGuid] [uniqueidentifier] NOT NULL,
        [ComparisonGuid] [uniqueidentifier] NULL,
        [ObjectType] [nvarchar](50) NOT NULL,
        [SchemaName] [nvarchar](128) NOT NULL,
        [ObjectName] [nvarchar](512) NOT NULL,
        [ParentObjectName] [nvarchar](512) NOT NULL CONSTRAINT [DF_Schema_RunSelections_ParentObjectName] DEFAULT (N''),
        [IsSelected] [bit] NOT NULL,
        [SelectionNote] [nvarchar](2000) NOT NULL CONSTRAINT [DF_Schema_RunSelections_SelectionNote] DEFAULT (N''),
        [SelectedByUserId] [int] NOT NULL CONSTRAINT [DF_Schema_RunSelections_SelectedByUserId] DEFAULT (-1),
        [SelectedOnUtc] [datetime2](7) NOT NULL CONSTRAINT [DF_Schema_RunSelections_SelectedOnUtc] DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT [PK_Schema_RunSelections] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80),
        CONSTRAINT [UQ_Schema_RunSelections_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
    );
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes AS i
    WHERE i.name = N'IX_Schema_RunSelections_Run_Active'
      AND i.object_id = OBJECT_ID(N'[SMigration].[Schema_RunSelections]', N'U')
)
BEGIN
    CREATE INDEX [IX_Schema_RunSelections_Run_Active]
        ON [SMigration].[Schema_RunSelections] ([RunGuid], [ObjectType], [SchemaName], [ObjectName], [ParentObjectName])
        WHERE [RowStatus] <> 0 AND [RowStatus] <> 254
        WITH (FILLFACTOR = 80);
END;
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

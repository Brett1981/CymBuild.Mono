/*
    CYB-361/CYB-362 Schema Migration Workbench R4
    Purpose:
      - Rebuild schema migration filtered indexes using the agreed RowStatus predicate format.
      - Deployment-safe and idempotent. No data is deleted and no application schema DDL is executed from the UI.
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'SMigration.Schema_ObjectComparisons', N'U') IS NOT NULL
BEGIN
    IF EXISTS
    (
        SELECT 1
        FROM sys.indexes AS i
        WHERE i.name = N'IX_Schema_ObjectComparisons_Run_Active'
          AND i.object_id = OBJECT_ID(N'SMigration.Schema_ObjectComparisons')
    )
    BEGIN
        DROP INDEX [IX_Schema_ObjectComparisons_Run_Active]
        ON [SMigration].[Schema_ObjectComparisons];
    END;

    CREATE INDEX [IX_Schema_ObjectComparisons_Run_Active]
    ON [SMigration].[Schema_ObjectComparisons]
    (
        [RunGuid],
        [DifferenceType],
        [ObjectType],
        [SchemaName],
        [ObjectName]
    )
    WHERE [RowStatus] <> 0 AND [RowStatus] <> 254;
END;
GO

IF OBJECT_ID(N'SMigration.Schema_ObjectComparisons', N'U') IS NOT NULL
BEGIN
    IF EXISTS
    (
        SELECT 1
        FROM sys.indexes AS i
        WHERE i.name = N'UX_Schema_ObjectComparisons_Run_Key_Active'
          AND i.object_id = OBJECT_ID(N'SMigration.Schema_ObjectComparisons')
    )
    BEGIN
        DROP INDEX [UX_Schema_ObjectComparisons_Run_Key_Active]
        ON [SMigration].[Schema_ObjectComparisons];
    END;

    CREATE UNIQUE INDEX [UX_Schema_ObjectComparisons_Run_Key_Active]
    ON [SMigration].[Schema_ObjectComparisons]
    (
        [RunGuid],
        [ObjectType],
        [SchemaName],
        [ObjectName],
        [ParentObjectName]
    )
    WHERE [RowStatus] <> 0 AND [RowStatus] <> 254;
END;
GO

IF OBJECT_ID(N'SMigration.Schema_ValidationIssues', N'U') IS NOT NULL
BEGIN
    IF EXISTS
    (
        SELECT 1
        FROM sys.indexes AS i
        WHERE i.name = N'IX_Schema_ValidationIssues_Run_Active'
          AND i.object_id = OBJECT_ID(N'SMigration.Schema_ValidationIssues')
    )
    BEGIN
        DROP INDEX [IX_Schema_ValidationIssues_Run_Active]
        ON [SMigration].[Schema_ValidationIssues];
    END;

    CREATE INDEX [IX_Schema_ValidationIssues_Run_Active]
    ON [SMigration].[Schema_ValidationIssues]
    (
        [RunGuid],
        [Severity],
        [ObjectType],
        [SchemaName],
        [ObjectName]
    )
    WHERE [RowStatus] <> 0 AND [RowStatus] <> 254;
END;
GO

IF OBJECT_ID(N'SMigration.Schema_ExecutionLog', N'U') IS NOT NULL
BEGIN
    IF EXISTS
    (
        SELECT 1
        FROM sys.indexes AS i
        WHERE i.name = N'IX_Schema_ExecutionLog_Run_Active'
          AND i.object_id = OBJECT_ID(N'SMigration.Schema_ExecutionLog')
    )
    BEGIN
        DROP INDEX [IX_Schema_ExecutionLog_Run_Active]
        ON [SMigration].[Schema_ExecutionLog];
    END;

    CREATE INDEX [IX_Schema_ExecutionLog_Run_Active]
    ON [SMigration].[Schema_ExecutionLog]
    (
        [RunGuid],
        [ID]
    )
    WHERE [RowStatus] <> 0 AND [RowStatus] <> 254;
END;
GO

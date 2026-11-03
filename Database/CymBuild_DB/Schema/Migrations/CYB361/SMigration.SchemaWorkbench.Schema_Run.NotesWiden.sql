/*
    CYB-361 Schema Migration bootstrap - widen SMigration.Schema_Run.Notes.

    Installs bootstrapped before Notes was widened to NVARCHAR(MAX) (see
    SMigration.SchemaWorkbench.Bootstrap.sql) still have Notes as NVARCHAR(2000). The
    bootstrap's self-heal only adds genuinely missing nullable columns; it deliberately
    refuses to alter an existing column's width, so it rejects this gap and requires a
    reviewed source-controlled migration instead. This is that migration.

    Widening a NOT NULL column that already carries non-null values is lossless and needs
    no backfill decision, so it is performed directly. It only ever widens Notes to MAX; it
    never narrows or touches any other shape, and it is idempotent - once Notes is already
    NVARCHAR(MAX) this is a no-op.
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'[SMigration].[Schema_Run]', N'U') IS NOT NULL
   AND EXISTS
   (
       SELECT 1
       FROM sys.columns AS c
       JOIN sys.types AS t
           ON t.user_type_id = c.user_type_id
       WHERE c.object_id = OBJECT_ID(N'[SMigration].[Schema_Run]', N'U')
         AND c.name = N'Notes'
         AND t.name = N'nvarchar'
         AND c.max_length <> -1
   )
BEGIN
    DECLARE @NotesDefaultObjectId INT;
    DECLARE @NotesDefaultDefinition NVARCHAR(MAX);

    SELECT
        @NotesDefaultObjectId = dc.[object_id],
        @NotesDefaultDefinition = dc.[definition]
    FROM sys.default_constraints AS dc
    JOIN sys.columns AS c
        ON c.[object_id] = dc.[parent_object_id]
       AND c.[column_id] = dc.[parent_column_id]
    WHERE dc.[parent_object_id] = OBJECT_ID(N'[SMigration].[Schema_Run]', N'U')
      AND c.[name] = N'Notes';

    IF @NotesDefaultObjectId IS NOT NULL
       AND OBJECT_NAME(@NotesDefaultObjectId) <> N'DF_Schema_Run_Notes'
    BEGIN
        THROW 51364, N'Schema Migration bootstrap blocked: [Notes] has an unexpected default constraint name.', 1;
    END;

    IF @NotesDefaultObjectId IS NOT NULL
    BEGIN
        PRINT (N'Dropping [DF_Schema_Run_Notes] to widen [Notes]');
        ALTER TABLE [SMigration].[Schema_Run] DROP CONSTRAINT [DF_Schema_Run_Notes];
    END;

    PRINT (N'Widening [SMigration].[Schema_Run].[Notes] to NVARCHAR(MAX)');
    ALTER TABLE [SMigration].[Schema_Run] ALTER COLUMN [Notes] NVARCHAR(MAX) NOT NULL;

    IF @NotesDefaultObjectId IS NOT NULL
    BEGIN
        PRINT (N'Recreating [DF_Schema_Run_Notes]');
        ALTER TABLE [SMigration].[Schema_Run]
            ADD CONSTRAINT [DF_Schema_Run_Notes] DEFAULT (N'') FOR [Notes];
    END;
END;
GO

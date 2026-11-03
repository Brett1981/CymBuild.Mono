/*
    CYB-361 generated manual preview deployment script
    Target server   : SOC-SQLBRE01\SQL2022
    Target database : CymBuild_UAT
    Run Guid        : 3c9dc0fc-8c07-4eeb-9283-6778127e4a58
    Generated UTC   : 2026-08-14T22:38:41.3326942Z

    INSPECTION ONLY. Do not execute this generated file as the approved deployment path.
    Run Invoke-CymBuildSchemaDeployment.ps1 so existence checks, LIVE guardrails and SMigration audit are enforced.
*/
USE [CymBuild_UAT];
GO
EXEC sys.sp_set_session_context @key = N'CymBuild_schema_predeployment_will_run', @value = 1, @read_only = 0;
GO

/* Prepare shared migration support for Table SCore.ObjectSecurity from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Migrations\_Shared\SMigration.AlterColumnNullabilityWithDependencies.sql */
/*
    CymBuild schema deployment shared helper.

    Creates a connection-local temporary procedure used by dedicated, source-controlled table
    migrations. The helper changes only column nullability and dynamically preserves supported
    target indexes and standalone user-created statistics that depend on the altered columns.
    Read-only preflight may recognise schema-bound functions/views that the controlled
    SCore.PreDeploymentScript can remove through SCore.SCHEMABINDING. Apply mode remains strict:
    those dependencies must be absent before any column is altered. Unsupported table, column,
    index, statistics, full-text, computed-column, and unmanaged schema-bound dependency shapes
    are rejected before target maintenance begins.

    The calling migration must own an active transaction. Unsupported dependency shapes are
    rejected before any dependency is dropped.
*/
SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'tempdb..#CymBuild_AlterColumnNullabilityWithDependencies', N'P') IS NOT NULL
BEGIN
    DROP PROCEDURE #CymBuild_AlterColumnNullabilityWithDependencies;
END;
GO
GO

/* Preflight Table SCore.ObjectSecurity from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Migrations\CYB361\SCore.ObjectSecurity.preflight.sql */
/*
    CYB-361 / CYB-362 guarded preflight for SCore.ObjectSecurity.

    Source-controlled expected shape:
      - Guid       UNIQUEIDENTIFIER NULL ROWGUIDCOL
      - ObjectGuid UNIQUEIDENTIFIER NOT NULL
      - UserId     INT NOT NULL

    This preflight is read-only. It deliberately refuses to infer ObjectGuid or UserId values.
    Before SCore.PreDeploymentScript, the controlled runner may recognise only schema-bound
    functions/views that are provably managed by SCore.SCHEMABINDING. The runner repeats this
    preflight in strict mode after pre-deployment maintenance.
*/
SET NOCOUNT ON;

DECLARE @ObjectId INT = OBJECT_ID(N'[SCore].[ObjectSecurity]', N'U');

IF @ObjectId IS NULL
BEGIN
    THROW 60361, N'CYB-361 ObjectSecurity migration requires existing table [SCore].[ObjectSecurity].', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.columns AS c
    JOIN sys.types AS t
      ON t.user_type_id = c.user_type_id
    WHERE c.object_id = @ObjectId
      AND c.name = N'Guid'
      AND t.name = N'uniqueidentifier'
      AND c.is_rowguidcol = 1
)
BEGIN
    THROW 60361, N'CYB-361 ObjectSecurity migration blocked: [Guid] is not UNIQUEIDENTIFIER ROWGUIDCOL.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.columns AS c
    JOIN sys.types AS t
      ON t.user_type_id = c.user_type_id
    WHERE c.object_id = @ObjectId
      AND c.name = N'ObjectGuid'
      AND t.name = N'uniqueidentifier'
)
BEGIN
    THROW 60361, N'CYB-361 ObjectSecurity migration blocked: [ObjectGuid] is missing or has an unexpected data type.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.columns AS c
    JOIN sys.types AS t
      ON t.user_type_id = c.user_type_id
    WHERE c.object_id = @ObjectId
      AND c.name = N'UserId'
      AND t.name = N'int'
)
BEGIN
    THROW 60361, N'CYB-361 ObjectSecurity migration blocked: [UserId] is missing or has an unexpected data type.', 1;
END;

DECLARE @NullObjectGuidCount BIGINT;
DECLARE @NullUserIdCount BIGINT;
DECLARE @OrphanUserIdCount BIGINT;
DECLARE @Message NVARCHAR(2048);

SELECT
    @NullObjectGuidCount = COUNT_BIG(1)
FROM [SCore].[ObjectSecurity] AS os
WHERE os.[ObjectGuid] IS NULL;

IF @NullObjectGuidCount > 0
BEGIN
    SET @Message = N'CYB-361 ObjectSecurity migration blocked: '
        + CONVERT(NVARCHAR(30), @NullObjectGuidCount)
        + N' row(s) have NULL ObjectGuid. No value can be inferred safely.';
    THROW 60361, @Message, 1;
END;

SELECT
    @NullUserIdCount = COUNT_BIG(1)
FROM [SCore].[ObjectSecurity] AS os
WHERE os.[UserId] IS NULL;

IF @NullUserIdCount > 0
BEGIN
    SET @Message = N'CYB-361 ObjectSecurity migration blocked: '
        + CONVERT(NVARCHAR(30), @NullUserIdCount)
        + N' row(s) have NULL UserId. No identity value will be guessed.';
    THROW 60361, @Message, 1;
END;

SELECT
    @OrphanUserIdCount = COUNT_BIG(1)
FROM [SCore].[ObjectSecurity] AS os
WHERE NOT EXISTS
(
    SELECT 1
    FROM [SCore].[Identities] AS i
    WHERE i.[ID] = os.[UserId]
);

IF @OrphanUserIdCount > 0
BEGIN
    SET @Message = N'CYB-361 ObjectSecurity migration blocked: '
        + CONVERT(NVARCHAR(30), @OrphanUserIdCount)
        + N' row(s) reference a UserId not present in SCore.Identities.';
    THROW 60361, @Message, 1;
END;

IF OBJECT_ID(N'tempdb..#CymBuild_AlterColumnNullabilityWithDependencies', N'P') IS NULL
BEGIN
    THROW 60361, N'CYB-361 ObjectSecurity migration preflight requires the shared column-dependency helper on the current deployment connection.', 1;
END;

DECLARE @AllowPreDeploymentManagedSchemaBoundDependencies BIT =
    CONVERT
    (
        BIT,
        CASE
            WHEN TRY_CONVERT(INT, SESSION_CONTEXT(N'CymBuild_schema_predeployment_will_run')) = 1 THEN 1
            ELSE 0
        END
    );

EXEC #CymBuild_AlterColumnNullabilityWithDependencies
    @SchemaName = N'SCore',
    @TableName = N'ObjectSecurity',
    @ColumnChangesJson = N'[
        {"ColumnName":"Guid","IsNullable":true},
        {"ColumnName":"ObjectGuid","IsNullable":false},
        {"ColumnName":"UserId","IsNullable":false}
    ]',
    @ValidateOnly = 1,
    @AllowPreDeploymentManagedSchemaBoundDependencies = @AllowPreDeploymentManagedSchemaBoundDependencies;

GO
EXEC [SCore].[PreDeploymentScript];
GO
EXEC sys.sp_set_session_context @key = N'CymBuild_schema_predeployment_will_run', @value = 0, @read_only = 0;
GO

/* Strict post-pre-deployment preflight Table SCore.ObjectSecurity */
/*
    CYB-361 / CYB-362 guarded preflight for SCore.ObjectSecurity.

    Source-controlled expected shape:
      - Guid       UNIQUEIDENTIFIER NULL ROWGUIDCOL
      - ObjectGuid UNIQUEIDENTIFIER NOT NULL
      - UserId     INT NOT NULL

    This preflight is read-only. It deliberately refuses to infer ObjectGuid or UserId values.
    Before SCore.PreDeploymentScript, the controlled runner may recognise only schema-bound
    functions/views that are provably managed by SCore.SCHEMABINDING. The runner repeats this
    preflight in strict mode after pre-deployment maintenance.
*/
SET NOCOUNT ON;

DECLARE @ObjectId INT = OBJECT_ID(N'[SCore].[ObjectSecurity]', N'U');

IF @ObjectId IS NULL
BEGIN
    THROW 60361, N'CYB-361 ObjectSecurity migration requires existing table [SCore].[ObjectSecurity].', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.columns AS c
    JOIN sys.types AS t
      ON t.user_type_id = c.user_type_id
    WHERE c.object_id = @ObjectId
      AND c.name = N'Guid'
      AND t.name = N'uniqueidentifier'
      AND c.is_rowguidcol = 1
)
BEGIN
    THROW 60361, N'CYB-361 ObjectSecurity migration blocked: [Guid] is not UNIQUEIDENTIFIER ROWGUIDCOL.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.columns AS c
    JOIN sys.types AS t
      ON t.user_type_id = c.user_type_id
    WHERE c.object_id = @ObjectId
      AND c.name = N'ObjectGuid'
      AND t.name = N'uniqueidentifier'
)
BEGIN
    THROW 60361, N'CYB-361 ObjectSecurity migration blocked: [ObjectGuid] is missing or has an unexpected data type.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.columns AS c
    JOIN sys.types AS t
      ON t.user_type_id = c.user_type_id
    WHERE c.object_id = @ObjectId
      AND c.name = N'UserId'
      AND t.name = N'int'
)
BEGIN
    THROW 60361, N'CYB-361 ObjectSecurity migration blocked: [UserId] is missing or has an unexpected data type.', 1;
END;

DECLARE @NullObjectGuidCount BIGINT;
DECLARE @NullUserIdCount BIGINT;
DECLARE @OrphanUserIdCount BIGINT;
DECLARE @Message NVARCHAR(2048);

SELECT
    @NullObjectGuidCount = COUNT_BIG(1)
FROM [SCore].[ObjectSecurity] AS os
WHERE os.[ObjectGuid] IS NULL;

IF @NullObjectGuidCount > 0
BEGIN
    SET @Message = N'CYB-361 ObjectSecurity migration blocked: '
        + CONVERT(NVARCHAR(30), @NullObjectGuidCount)
        + N' row(s) have NULL ObjectGuid. No value can be inferred safely.';
    THROW 60361, @Message, 1;
END;

SELECT
    @NullUserIdCount = COUNT_BIG(1)
FROM [SCore].[ObjectSecurity] AS os
WHERE os.[UserId] IS NULL;

IF @NullUserIdCount > 0
BEGIN
    SET @Message = N'CYB-361 ObjectSecurity migration blocked: '
        + CONVERT(NVARCHAR(30), @NullUserIdCount)
        + N' row(s) have NULL UserId. No identity value will be guessed.';
    THROW 60361, @Message, 1;
END;

SELECT
    @OrphanUserIdCount = COUNT_BIG(1)
FROM [SCore].[ObjectSecurity] AS os
WHERE NOT EXISTS
(
    SELECT 1
    FROM [SCore].[Identities] AS i
    WHERE i.[ID] = os.[UserId]
);

IF @OrphanUserIdCount > 0
BEGIN
    SET @Message = N'CYB-361 ObjectSecurity migration blocked: '
        + CONVERT(NVARCHAR(30), @OrphanUserIdCount)
        + N' row(s) reference a UserId not present in SCore.Identities.';
    THROW 60361, @Message, 1;
END;

IF OBJECT_ID(N'tempdb..#CymBuild_AlterColumnNullabilityWithDependencies', N'P') IS NULL
BEGIN
    THROW 60361, N'CYB-361 ObjectSecurity migration preflight requires the shared column-dependency helper on the current deployment connection.', 1;
END;

DECLARE @AllowPreDeploymentManagedSchemaBoundDependencies BIT =
    CONVERT
    (
        BIT,
        CASE
            WHEN TRY_CONVERT(INT, SESSION_CONTEXT(N'CymBuild_schema_predeployment_will_run')) = 1 THEN 1
            ELSE 0
        END
    );

EXEC #CymBuild_AlterColumnNullabilityWithDependencies
    @SchemaName = N'SCore',
    @TableName = N'ObjectSecurity',
    @ColumnChangesJson = N'[
        {"ColumnName":"Guid","IsNullable":true},
        {"ColumnName":"ObjectGuid","IsNullable":false},
        {"ColumnName":"UserId","IsNullable":false}
    ]',
    @ValidateOnly = 1,
    @AllowPreDeploymentManagedSchemaBoundDependencies = @AllowPreDeploymentManagedSchemaBoundDependencies;

GO

/* Deploy Table SCore.ObjectSecurity using DedicatedMigration from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Migrations\CYB361\SCore.ObjectSecurity.alter.sql */
/*
    CYB-361 / CYB-362 dedicated, data-preserving migration for SCore.ObjectSecurity.

    This script aligns the demonstrated QA shape with the source-controlled DEV shape without
    recreating the table or deleting/updating business rows. It is idempotent and repeats all
    preconditions inside the deployment transaction.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @ObjectId INT = OBJECT_ID(N'[SCore].[ObjectSecurity]', N'U');

    IF @ObjectId IS NULL
    BEGIN
        THROW 60361, N'CYB-361 ObjectSecurity migration requires existing table [SCore].[ObjectSecurity].', 1;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.columns AS c
        JOIN sys.types AS t
          ON t.user_type_id = c.user_type_id
        WHERE c.object_id = @ObjectId
          AND c.name = N'Guid'
          AND t.name = N'uniqueidentifier'
          AND c.is_rowguidcol = 1
    )
    BEGIN
        THROW 60361, N'CYB-361 ObjectSecurity migration blocked: [Guid] is not UNIQUEIDENTIFIER ROWGUIDCOL.', 1;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.columns AS c
        JOIN sys.types AS t
          ON t.user_type_id = c.user_type_id
        WHERE c.object_id = @ObjectId
          AND c.name = N'ObjectGuid'
          AND t.name = N'uniqueidentifier'
    )
    BEGIN
        THROW 60361, N'CYB-361 ObjectSecurity migration blocked: [ObjectGuid] is missing or has an unexpected data type.', 1;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.columns AS c
        JOIN sys.types AS t
          ON t.user_type_id = c.user_type_id
        WHERE c.object_id = @ObjectId
          AND c.name = N'UserId'
          AND t.name = N'int'
    )
    BEGIN
        THROW 60361, N'CYB-361 ObjectSecurity migration blocked: [UserId] is missing or has an unexpected data type.', 1;
    END;

    DECLARE @NullObjectGuidCount BIGINT;
    DECLARE @NullUserIdCount BIGINT;
    DECLARE @OrphanUserIdCount BIGINT;
    DECLARE @Message NVARCHAR(2048);

    SELECT
        @NullObjectGuidCount = COUNT_BIG(1)
    FROM [SCore].[ObjectSecurity] AS os WITH (UPDLOCK, HOLDLOCK)
    WHERE os.[ObjectGuid] IS NULL;

    IF @NullObjectGuidCount > 0
    BEGIN
        SET @Message = N'CYB-361 ObjectSecurity migration blocked: '
            + CONVERT(NVARCHAR(30), @NullObjectGuidCount)
            + N' row(s) have NULL ObjectGuid. No value can be inferred safely.';
        THROW 60361, @Message, 1;
    END;

    SELECT
        @NullUserIdCount = COUNT_BIG(1)
    FROM [SCore].[ObjectSecurity] AS os WITH (UPDLOCK, HOLDLOCK)
    WHERE os.[UserId] IS NULL;

    IF @NullUserIdCount > 0
    BEGIN
        SET @Message = N'CYB-361 ObjectSecurity migration blocked: '
            + CONVERT(NVARCHAR(30), @NullUserIdCount)
            + N' row(s) have NULL UserId. No identity value will be guessed.';
        THROW 60361, @Message, 1;
    END;

    SELECT
        @OrphanUserIdCount = COUNT_BIG(1)
    FROM [SCore].[ObjectSecurity] AS os WITH (UPDLOCK, HOLDLOCK)
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM [SCore].[Identities] AS i
        WHERE i.[ID] = os.[UserId]
    );

    IF @OrphanUserIdCount > 0
    BEGIN
        SET @Message = N'CYB-361 ObjectSecurity migration blocked: '
            + CONVERT(NVARCHAR(30), @OrphanUserIdCount)
            + N' row(s) reference a UserId not present in SCore.Identities.';
        THROW 60361, @Message, 1;
    END;

    /*
        Shared source-controlled migration infrastructure handles the mechanical SQL Server
        requirements for nullability changes: dependent rowstore indexes, standalone user-created
        statistics, and temporary ROWGUIDCOL removal/restoration. Table-specific intent remains
        explicit in this migration.
    */
    EXEC #CymBuild_AlterColumnNullabilityWithDependencies
        @SchemaName = N'SCore',
        @TableName = N'ObjectSecurity',
        @ColumnChangesJson = N'[
            {"ColumnName":"Guid","IsNullable":true},
            {"ColumnName":"ObjectGuid","IsNullable":false},
            {"ColumnName":"UserId","IsNullable":false}
        ]';

    DECLARE @ObjectGuidDefaultObjectId INT;
    DECLARE @ObjectGuidDefaultDefinition NVARCHAR(MAX);

    SELECT
        @ObjectGuidDefaultObjectId = dc.[object_id],
        @ObjectGuidDefaultDefinition = dc.[definition]
    FROM sys.default_constraints AS dc
    JOIN sys.columns AS c
      ON c.[object_id] = dc.[parent_object_id]
     AND c.[column_id] = dc.[parent_column_id]
    WHERE dc.[parent_object_id] = @ObjectId
      AND c.[name] = N'ObjectGuid';

    IF @ObjectGuidDefaultObjectId IS NULL
    BEGIN
        IF OBJECT_ID(N'[SCore].[DF_ObjectSecurity_RecordGuid]', N'D') IS NOT NULL
        BEGIN
            THROW 60361, N'CYB-361 ObjectSecurity migration blocked: constraint name DF_ObjectSecurity_RecordGuid is already used by another object.', 1;
        END;

        ALTER TABLE [SCore].[ObjectSecurity]
            ADD CONSTRAINT [DF_ObjectSecurity_RecordGuid]
            DEFAULT ('00000000-0000-0000-0000-000000000000') FOR [ObjectGuid];
    END;
    ELSE IF LOWER(@ObjectGuidDefaultDefinition)
            NOT LIKE N'%00000000-0000-0000-0000-000000000000%'
    BEGIN
        THROW 60361, N'CYB-361 ObjectSecurity migration blocked: ObjectGuid has an unexpected default constraint.', 1;
    END;

    DECLARE @UserForeignKeyObjectId INT;

    SELECT TOP (1)
        @UserForeignKeyObjectId = fk.[object_id]
    FROM sys.foreign_keys AS fk
    JOIN sys.foreign_key_columns AS fkc
      ON fkc.[constraint_object_id] = fk.[object_id]
    JOIN sys.columns AS pc
      ON pc.[object_id] = fkc.[parent_object_id]
     AND pc.[column_id] = fkc.[parent_column_id]
    JOIN sys.columns AS rc
      ON rc.[object_id] = fkc.[referenced_object_id]
     AND rc.[column_id] = fkc.[referenced_column_id]
    WHERE fk.[parent_object_id] = @ObjectId
      AND fk.[referenced_object_id] = OBJECT_ID(N'[SCore].[Identities]', N'U')
      AND pc.[name] = N'UserId'
      AND rc.[name] = N'ID';

    IF @UserForeignKeyObjectId IS NULL
    BEGIN
        IF OBJECT_ID(N'[SCore].[FK_ObjectSecurity_Users]', N'F') IS NOT NULL
        BEGIN
            THROW 60361, N'CYB-361 ObjectSecurity migration blocked: FK_ObjectSecurity_Users exists with an unexpected definition.', 1;
        END;

        ALTER TABLE [SCore].[ObjectSecurity] WITH NOCHECK
            ADD CONSTRAINT [FK_ObjectSecurity_Users]
            FOREIGN KEY ([UserId]) REFERENCES [SCore].[Identities] ([ID]);

        ALTER TABLE [SCore].[ObjectSecurity]
            CHECK CONSTRAINT [FK_ObjectSecurity_Users];
    END;

    IF EXISTS
    (
        SELECT 1
        FROM sys.columns AS c
        WHERE c.object_id = @ObjectId
          AND
          (
              (c.name = N'Guid' AND (c.is_nullable <> 1 OR c.is_rowguidcol <> 1))
              OR (c.name = N'ObjectGuid' AND c.is_nullable <> 0)
              OR (c.name = N'UserId' AND c.is_nullable <> 0)
          )
    )
    BEGIN
        THROW 60361, N'CYB-361 ObjectSecurity migration verification failed: target column shape does not match the source-controlled definition.', 1;
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
    BEGIN
        ROLLBACK TRANSACTION;
    END;

    THROW;
END CATCH;

GO
DECLARE @CymBuildPostDeploymentRunGuid UNIQUEIDENTIFIER = NEWID();
EXEC [SCore].[PostDeploymentScript] @ThrowOnIssues = 1, @RunGuid = @CymBuildPostDeploymentRunGuid;
GO

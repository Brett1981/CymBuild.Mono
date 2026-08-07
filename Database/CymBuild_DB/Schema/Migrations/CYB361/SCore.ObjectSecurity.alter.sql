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

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create or alter procedure [SMigration].[SchemaExcludedObject_Apply]')
GO

CREATE OR ALTER PROCEDURE [SMigration].[SchemaExcludedObject_Apply]
(
    @Guid UNIQUEIDENTIFIER OUTPUT,
    @ObjectType NVARCHAR(50),
    @SchemaName NVARCHAR(128),
    @ObjectName NVARCHAR(512),
    @ParentObjectName NVARCHAR(512) = N'',
    @Reason NVARCHAR(2000) = N'',
    @IsExcluded BIT,
    @OriginServerName NVARCHAR(255) = N'',
    @OriginDatabaseName NVARCHAR(255) = N'',
    @ActorUserId INT = -1,
    @LastSeenRunGuid UNIQUEIDENTIFIER = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @ObjectType = LTRIM(RTRIM(ISNULL(@ObjectType, N'')));
    SET @SchemaName = LTRIM(RTRIM(ISNULL(@SchemaName, N'')));
    SET @ObjectName = LTRIM(RTRIM(ISNULL(@ObjectName, N'')));
    SET @ParentObjectName = LTRIM(RTRIM(ISNULL(@ParentObjectName, N'')));
    SET @Reason = LTRIM(RTRIM(ISNULL(@Reason, N'')));

    IF @ObjectType = N'' OR @SchemaName = N'' OR @ObjectName = N''
        THROW 51410, 'Schema exclusion requires object type, schema name and object name.', 1;

    IF ISNULL(@IsExcluded, 0) = 1 AND @Reason = N''
        THROW 51411, 'Schema exclusion requires an audit reason.', 1;

    DECLARE @StableObjectKey NVARCHAR(1300) = CONCAT
    (
        UPPER(@ObjectType COLLATE Latin1_General_100_CI_AS), N'|',
        UPPER(@SchemaName COLLATE Latin1_General_100_CI_AS), N'|',
        UPPER(@ObjectName COLLATE Latin1_General_100_CI_AS), N'|',
        UPPER(@ParentObjectName COLLATE Latin1_General_100_CI_AS)
    );
    DECLARE @StableObjectKeyHash BINARY(32) = HASHBYTES(N'SHA2_256', CONVERT(VARBINARY(MAX), @StableObjectKey));
    DECLARE @ExistingGuid UNIQUEIDENTIFIER;
    DECLARE @ExistingStableObjectKey NVARCHAR(1300);
    DECLARE @StartedTransaction BIT = 0;

    IF @@TRANCOUNT = 0
    BEGIN
        BEGIN TRANSACTION;
        SET @StartedTransaction = 1;
    END;

    BEGIN TRY
        SELECT TOP (1)
            @ExistingGuid = excluded.[Guid],
            @ExistingStableObjectKey = excluded.[StableObjectKey]
        FROM [SMigration].[Schema_ExcludedObjects] AS excluded WITH (UPDLOCK, HOLDLOCK)
        WHERE excluded.[StableObjectKeyHash] = @StableObjectKeyHash
        ORDER BY excluded.[ID];

        IF @ExistingGuid IS NOT NULL
           AND @ExistingStableObjectKey <> @StableObjectKey
            THROW 51412, 'Schema exclusion stable-key hash collision detected. No exclusion was changed.', 1;

        SET @Guid = COALESCE(@ExistingGuid, NULLIF(@Guid, '00000000-0000-0000-0000-000000000000'), NEWID());

        IF ISNULL(@IsExcluded, 0) = 1
        BEGIN
            EXEC [SMigration].[SchemaDataObject_Ensure]
                @Guid = @Guid,
                @SchemeName = N'SMigration',
                @ObjectName = N'Schema_ExcludedObjects';

            IF EXISTS
            (
                SELECT 1
                FROM [SMigration].[Schema_ExcludedObjects] AS excluded
                WHERE excluded.[Guid] = @Guid
            )
            BEGIN
                UPDATE [SMigration].[Schema_ExcludedObjects]
                SET
                    [RowStatus] = 1,
                    [StableObjectKey] = @StableObjectKey,
                    [StableObjectKeyHash] = @StableObjectKeyHash,
                    [ObjectType] = @ObjectType,
                    [SchemaName] = @SchemaName,
                    [ObjectName] = @ObjectName,
                    [ParentObjectName] = @ParentObjectName,
                    [ExclusionScope] = N'AllDatabases',
                    [Reason] = @Reason,
                    [OriginServerName] = ISNULL(@OriginServerName, N''),
                    [OriginDatabaseName] = ISNULL(@OriginDatabaseName, N''),
                    [ExcludedByUserId] = ISNULL(@ActorUserId, -1),
                    [ExcludedOnUtc] = SYSUTCDATETIME(),
                    [UnexcludedByUserId] = NULL,
                    [UnexcludedOnUtc] = NULL,
                    [LastSeenRunGuid] = @LastSeenRunGuid,
                    [LastSeenOnUtc] = SYSUTCDATETIME()
                WHERE [Guid] = @Guid;
            END
            ELSE
            BEGIN
                INSERT INTO [SMigration].[Schema_ExcludedObjects]
                (
                    [Guid],
                    [RowStatus],
                    [StableObjectKey],
                    [StableObjectKeyHash],
                    [ObjectType],
                    [SchemaName],
                    [ObjectName],
                    [ParentObjectName],
                    [ExclusionScope],
                    [Reason],
                    [OriginServerName],
                    [OriginDatabaseName],
                    [ExcludedByUserId],
                    [ExcludedOnUtc],
                    [UnexcludedByUserId],
                    [UnexcludedOnUtc],
                    [LastSeenRunGuid],
                    [LastSeenOnUtc]
                )
                VALUES
                (
                    @Guid,
                    1,
                    @StableObjectKey,
                    @StableObjectKeyHash,
                    @ObjectType,
                    @SchemaName,
                    @ObjectName,
                    @ParentObjectName,
                    N'AllDatabases',
                    @Reason,
                    ISNULL(@OriginServerName, N''),
                    ISNULL(@OriginDatabaseName, N''),
                    ISNULL(@ActorUserId, -1),
                    SYSUTCDATETIME(),
                    NULL,
                    NULL,
                    @LastSeenRunGuid,
                    SYSUTCDATETIME()
                );
            END;
        END
        ELSE IF @ExistingGuid IS NOT NULL
        BEGIN
            EXEC [SCore].[DeleteDataObject]
                @Guid = @ExistingGuid;

            UPDATE [SMigration].[Schema_ExcludedObjects]
            SET
                [RowStatus] = 254,
                [UnexcludedByUserId] = ISNULL(@ActorUserId, -1),
                [UnexcludedOnUtc] = SYSUTCDATETIME(),
                [LastSeenRunGuid] = @LastSeenRunGuid,
                [LastSeenOnUtc] = SYSUTCDATETIME()
            WHERE [Guid] = @ExistingGuid
              AND [RowStatus] <> 0
              AND [RowStatus] <> 254;

            SET @Guid = @ExistingGuid;
        END;

        IF @StartedTransaction = 1
            COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @StartedTransaction = 1 AND XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

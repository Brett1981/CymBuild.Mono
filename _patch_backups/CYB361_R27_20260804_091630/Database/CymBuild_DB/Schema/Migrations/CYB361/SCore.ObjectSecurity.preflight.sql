/*
    CYB-361 / CYB-362 guarded preflight for SCore.ObjectSecurity.

    Source-controlled expected shape:
      - Guid       UNIQUEIDENTIFIER NULL ROWGUIDCOL
      - ObjectGuid UNIQUEIDENTIFIER NOT NULL
      - UserId     INT NOT NULL

    This preflight is read-only. It deliberately refuses to infer ObjectGuid or UserId values.
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

EXEC #CymBuild_AlterColumnNullabilityWithDependencies
    @SchemaName = N'SCore',
    @TableName = N'ObjectSecurity',
    @ColumnChangesJson = N'[
        {"ColumnName":"Guid","IsNullable":true},
        {"ColumnName":"ObjectGuid","IsNullable":false},
        {"ColumnName":"UserId","IsNullable":false}
    ]',
    @ValidateOnly = 1;

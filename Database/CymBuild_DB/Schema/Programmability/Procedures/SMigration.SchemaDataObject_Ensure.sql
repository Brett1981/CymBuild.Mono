SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create or alter procedure [SMigration].[SchemaDataObject_Ensure]')
GO

PRINT (N'Create procedure [SMigration].[SchemaDataObject_Ensure]')
GO
CREATE PROCEDURE [SMigration].[SchemaDataObject_Ensure]
(
    @Guid UNIQUEIDENTIFIER,
    @SchemeName NVARCHAR(255),
    @ObjectName NVARCHAR(255)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @EntityTypeId INT;

    SELECT TOP (1)
        @EntityTypeId = entityType.[ID]
    FROM [SCore].[EntityHobts] AS entityHobt
    INNER JOIN [SCore].[EntityTypes] AS entityType
        ON entityType.[ID] = entityHobt.[EntityTypeID]
    WHERE entityHobt.[SchemaName] = @SchemeName
      AND entityHobt.[ObjectName] = @ObjectName
      AND entityHobt.[RowStatus] <> 0
      AND entityHobt.[RowStatus] <> 254
      AND entityType.[RowStatus] <> 0
      AND entityType.[RowStatus] <> 254
    ORDER BY entityType.[ID];

    IF @EntityTypeId IS NULL
    BEGIN
        SELECT TOP (1)
            @EntityTypeId = entityType.[ID]
        FROM [SCore].[EntityTypes] AS entityType
        WHERE entityType.[Name] = N'EntityTypes'
          AND entityType.[RowStatus] <> 0
          AND entityType.[RowStatus] <> 254
        ORDER BY entityType.[ID];
    END;

    IF @EntityTypeId IS NULL
    BEGIN
        SELECT TOP (1)
            @EntityTypeId = entityType.[ID]
        FROM [SCore].[EntityTypes] AS entityType
        WHERE entityType.[RowStatus] <> 0
          AND entityType.[RowStatus] <> 254
        ORDER BY entityType.[ID];
    END;

    IF @EntityTypeId IS NULL
        THROW 51354, 'No active SCore.EntityTypes row exists to support Schema Migration DataObjects creation.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM [SCore].[DataObjects] AS dataObject
        WHERE dataObject.[Guid] = @Guid
    )
    BEGIN
        INSERT INTO [SCore].[DataObjects]
        (
            [Guid],
            [RowStatus],
            [EntityTypeId]
        )
        VALUES
        (
            @Guid,
            1,
            @EntityTypeId
        );
    END
    ELSE
    BEGIN
        UPDATE [SCore].[DataObjects]
        SET
            [RowStatus] = CASE WHEN [RowStatus] = 0 OR [RowStatus] = 254 THEN 1 ELSE [RowStatus] END,
            [EntityTypeId] = ISNULL([EntityTypeId], @EntityTypeId)
        WHERE [Guid] = @Guid;
    END;
END;
GO
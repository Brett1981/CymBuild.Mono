SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataEntityTypeScope_Set]')
GO
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataEntityTypeScope_Set]')
GO

CREATE PROCEDURE [SMigration].[MetadataEntityTypeScope_Set]
(
    @EntityTypeGuid UNIQUEIDENTIFIER,
    @IsMetaData BIT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS
    (
        SELECT 1
        FROM SCore.EntityTypes AS et
        WHERE et.Guid = @EntityTypeGuid
          AND et.RowStatus NOT IN (0,254)
    )
    BEGIN
        ;THROW 52200, 'The EntityType was not found or is inactive.', 1;
    END;

    UPDATE SCore.EntityTypes
    SET IsMetaData = ISNULL(@IsMetaData, 0)
    WHERE Guid = @EntityTypeGuid
      AND RowStatus NOT IN (0,254)
      AND IsMetaData <> ISNULL(@IsMetaData, 0);

    SELECT CONVERT(INT, @@ROWCOUNT) AS UpdatedCount;
END;
GO
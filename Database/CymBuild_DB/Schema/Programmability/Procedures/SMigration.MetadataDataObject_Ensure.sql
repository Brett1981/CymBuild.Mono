SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataDataObject_Ensure]')
GO

CREATE PROCEDURE [SMigration].[MetadataDataObject_Ensure]
(
    @Guid       UNIQUEIDENTIFIER,
    @SchemeName NVARCHAR(255),
    @ObjectName NVARCHAR(255)
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EntityTypeId INT = NULL;

    SELECT TOP (1)
        @EntityTypeId = et.ID
    FROM SCore.EntityHobts AS eh
    INNER JOIN SCore.EntityTypes AS et
        ON et.ID = eh.EntityTypeID
    WHERE eh.SchemaName = @SchemeName
      AND eh.ObjectName = @ObjectName
      AND eh.RowStatus NOT IN (0,254)
      AND et.RowStatus NOT IN (0,254)
    ORDER BY et.ID;

    IF @EntityTypeId IS NULL
    BEGIN
        SELECT TOP (1)
            @EntityTypeId = et.ID
        FROM SCore.EntityTypes AS et
        WHERE et.Name = N'EntityTypes'
          AND et.RowStatus NOT IN (0,254)
        ORDER BY et.ID;
    END;

    IF @EntityTypeId IS NULL
    BEGIN
        SELECT TOP (1)
            @EntityTypeId = et.ID
        FROM SCore.EntityTypes AS et
        WHERE et.RowStatus NOT IN (0,254)
        ORDER BY et.ID;
    END;

    IF @EntityTypeId IS NULL
    BEGIN
        ;THROW 51010, 'No active SCore.EntityTypes row exists to support DataObjects creation.', 1;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM SCore.DataObjects AS d
        WHERE d.Guid = @Guid
    )
    BEGIN
        INSERT INTO SCore.DataObjects
        (
            Guid,
            RowStatus,
            EntityTypeId
        )
        SELECT
            @Guid,
            1,
            @EntityTypeId;
    END
    ELSE
    BEGIN
        UPDATE SCore.DataObjects
        SET
            RowStatus = CASE WHEN RowStatus IN (0,254) THEN 1 ELSE RowStatus END,
            EntityTypeId = ISNULL(EntityTypeId, @EntityTypeId)
        WHERE Guid = @Guid;
    END;
END;
GO
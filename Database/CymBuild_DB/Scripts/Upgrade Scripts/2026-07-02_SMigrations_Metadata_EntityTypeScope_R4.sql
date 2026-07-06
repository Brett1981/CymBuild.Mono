/* CI/CD-safe idempotent SMigration EntityType metadata scope deployment.
   R4: setup grid support for active SCore.EntityTypes IsMetaData scope.
*/
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

IF SCHEMA_ID(N'SMigration') IS NULL
    EXEC(N'CREATE SCHEMA [SMigration] AUTHORIZATION [dbo];');
GO

CREATE OR ALTER PROCEDURE [SMigration].[MetadataEntityTypeScope_List]
(
    @ShowMetadataOnly BIT = 1,
    @SearchText NVARCHAR(250) = N''
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SearchPattern NVARCHAR(252) = N'%' + ISNULL(@SearchText, N'') + N'%';

    SELECT
        et.Guid AS EntityTypeGuid,
        et.Name,
        CONVERT(INT, et.RowStatus) AS RowStatus,
        et.IsMetaData,
        et.HasDocuments,
        et.IsRootEntity,
        et.IsDeletable,
        CONVERT(BIT, CASE WHEN mainHobt.ID IS NULL THEN 0 ELSE 1 END) AS HasMainHoBT,
        ISNULL(mainHobt.SchemaName, N'') AS MainHoBTSchemaName,
        ISNULL(mainHobt.ObjectName, N'') AS MainHoBTObjectName
    FROM SCore.EntityTypes AS et
    OUTER APPLY
    (
        SELECT TOP (1)
            eh.ID,
            eh.SchemaName,
            eh.ObjectName
        FROM SCore.EntityHobts AS eh
        WHERE eh.EntityTypeID = et.ID
          AND eh.RowStatus NOT IN (0,254)
        ORDER BY
            CASE WHEN eh.IsMainHoBT = 1 THEN 0 ELSE 1 END,
            eh.ID
    ) AS mainHobt
    WHERE et.RowStatus NOT IN (0,254)
      AND (ISNULL(@ShowMetadataOnly, 0) = 0 OR et.IsMetaData = 1)
      AND
      (
          ISNULL(@SearchText, N'') = N''
          OR et.Name LIKE @SearchPattern
          OR ISNULL(mainHobt.SchemaName, N'') LIKE @SearchPattern
          OR ISNULL(mainHobt.ObjectName, N'') LIKE @SearchPattern
      )
    ORDER BY
        et.IsMetaData DESC,
        et.Name;
END;
GO

CREATE OR ALTER PROCEDURE [SMigration].[MetadataEntityTypeScope_Set]
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

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataEntityTypeScope_List]')
GO

CREATE PROCEDURE [SMigration].[MetadataEntityTypeScope_List]
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

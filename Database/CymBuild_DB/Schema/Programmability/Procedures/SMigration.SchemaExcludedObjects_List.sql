SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create or alter procedure [SMigration].[SchemaExcludedObjects_List]')
GO

PRINT (N'Create procedure [SMigration].[SchemaExcludedObjects_List]')
GO
CREATE PROCEDURE [SMigration].[SchemaExcludedObjects_List]
(
    @IncludeInactive BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        excluded.[Guid],
        excluded.[ObjectType],
        excluded.[SchemaName],
        excluded.[ObjectName],
        excluded.[ParentObjectName],
        excluded.[StableObjectKey],
        excluded.[Reason],
        excluded.[ExclusionScope],
        excluded.[OriginServerName],
        excluded.[OriginDatabaseName],
        excluded.[ExcludedByUserId],
        CONVERT(NVARCHAR(30), excluded.[ExcludedOnUtc], 126) AS [ExcludedOnUtc],
        CONVERT(NVARCHAR(30), excluded.[UnexcludedOnUtc], 126) AS [UnexcludedOnUtc],
        excluded.[LastSeenRunGuid],
        CONVERT(NVARCHAR(30), excluded.[LastSeenOnUtc], 126) AS [LastSeenOnUtc],
        excluded.[RowStatus]
    FROM [SMigration].[Schema_ExcludedObjects] AS excluded
    WHERE ISNULL(@IncludeInactive, 0) = 1
       OR
       (
           excluded.[RowStatus] <> 0
           AND excluded.[RowStatus] <> 254
       )
    ORDER BY
        excluded.[ObjectType],
        excluded.[SchemaName],
        excluded.[ObjectName],
        excluded.[ParentObjectName];
END;
GO
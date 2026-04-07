SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[GetEntityPropertyGuid]
(
    @SchemaName nvarchar(254),
    @HoBTName nvarchar(254),
    @ColumnName nvarchar(254)
)
RETURNS nvarchar(600) 
                --WITH SCHEMABINDING
AS  
BEGIN

	DECLARE @EntityPropertyGuid uniqueidentifier

    SELECT  @EntityPropertyGuid = ep.Guid
    FROM    SCore.EntityProperties ep 
    JOIN    [SCore].[EntityHobts] eh on (eh.Id = ep.EntityHoBTID)
    WHERE   (ep.Name = @ColumnName)
        AND (eh.SchemaName = @SchemaName)
        AND (eh.ObjectName = @HoBTName)
        AND (ep.RowStatus = 1)
        AND (eh.RowStatus = 1)

	RETURN @EntityPropertyGuid

END
GO
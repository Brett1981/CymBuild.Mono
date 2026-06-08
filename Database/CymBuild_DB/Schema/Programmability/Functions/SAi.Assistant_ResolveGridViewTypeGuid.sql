SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SAi].[Assistant_ResolveGridViewTypeGuid]')
GO

CREATE FUNCTION [SAi].[Assistant_ResolveGridViewTypeGuid] (@Name NVARCHAR(50))
RETURNS UNIQUEIDENTIFIER
AS
BEGIN
	DECLARE @Guid UNIQUEIDENTIFIER;

	SELECT @Guid = gvt.Guid
	FROM SUserInterface.GridViewTypes gvt
	WHERE gvt.Name = @Name
		AND gvt.RowStatus NOT IN (
			0
			,254
			);

	RETURN @Guid;
END;
GO
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SAi].[Assistant_ResolveAnyIconGuid]')
GO

CREATE FUNCTION [SAi].[Assistant_ResolveAnyIconGuid] ()
RETURNS UNIQUEIDENTIFIER
AS
BEGIN
	DECLARE @Guid UNIQUEIDENTIFIER;

	SELECT TOP (1) @Guid = i.Guid
	FROM SUserInterface.Icons i
	WHERE i.RowStatus NOT IN (
			0
			,254
			)
	ORDER BY i.ID;

	RETURN @Guid;
END;
GO
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SAi].[Assistant_ResolveEntityTypeId]')
GO

CREATE FUNCTION [SAi].[Assistant_ResolveEntityTypeId] (@EntityName NVARCHAR(250))
RETURNS INT
AS
BEGIN
	DECLARE @Id INT;

	SELECT @Id = et.ID
	FROM SCore.EntityTypes AS et
	WHERE et.Name = @EntityName
		AND et.RowStatus NOT IN (
			0
			,254
			);

	RETURN ISNULL(@Id, - 1);
END;
GO
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SCore].[tvf_ActionsForEntityProperty]')
GO

CREATE FUNCTION [SCore].[tvf_ActionsForEntityProperty]
	(
		@Guid UNIQUEIDENTIFIER
	)
RETURNS TABLE
AS
RETURN SELECT		epa.RowStatus,
					epa.RowVersion,
					epa.Guid,
					epa.Statement					
	   FROM			SCore.EntityPropertyActions	AS epa
	   JOIN			SCore.EntityProperties AS p ON  p.id = epa.EntityPropertyId
	   WHERE		(p.Guid = @Guid)
GO
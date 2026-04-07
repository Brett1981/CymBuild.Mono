SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO


CREATE FUNCTION [SUserInterface].[tvf_ActionsForGridView]
	(
		@Guid UNIQUEIDENTIFIER,
		@UserId INT
	)
RETURNS TABLE
AS
RETURN SELECT		gva.RowStatus,
					gva.RowVersion,
					gva.Guid,
					eq.Statement,
					olfu.Label as Title
	   FROM			SCore.EntityQueries	AS eq
	   JOIN			SUserInterface.GridViewActions gva ON (gva.EntityQueryId = eq.Id)
	OUTER APPLY
				SCore.ObjectLabelForUser(gva.LanguageLabelId, @UserId) olfu
	   WHERE		(EXISTS
						(
							SELECT	1
							FROM	SUserInterface.GridViewDefinitions gvd
							WHERE	(gvd.ID = gva.GridViewDefinitionId)
								AND	(gvd.Guid = @Guid)
						)
					)
GO
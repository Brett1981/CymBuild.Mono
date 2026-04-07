SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SUserInterface].[tvf_GridViewActions]
  (
    @GridViewDefinitionGuid UNIQUEIDENTIFIER,
    @UserId       INT
  )
RETURNS TABLE
   --WITH SCHEMABINDING
AS
  RETURN SELECT
          gva.ID,
          gva.RowStatus,
          gva.Guid,
          olfu.Label AS Title,
		  eq.Name
  FROM
          SUserInterface.GridViewActions gva
  JOIN	
		  SCore.EntityQueries eq on (eq.ID = gva.EntityQueryId)
  OUTER APPLY
          SCore.ObjectLabelForUser(gva.LanguageLabelId, @UserId) olfu
  WHERE
          (gva.RowStatus NOT IN (0, 254))
          AND (EXISTS
          (
              SELECT	1
			  FROM		SUserInterface.GridViewDefinitions gvd
			  WHERE		(gvd.ID = gva.GridViewDefinitionId)
					AND	(gvd.Guid = @GridViewDefinitionGuid)
          )
          )
GO
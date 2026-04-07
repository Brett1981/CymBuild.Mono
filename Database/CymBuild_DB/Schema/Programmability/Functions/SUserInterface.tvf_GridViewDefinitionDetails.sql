SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SUserInterface].[tvf_GridViewDefinitionDetails]
(
	@UserId INT,
	@ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
     --WITH SCHEMABINDING
AS
  RETURN SELECT
			root_hobt.ID					AS ID,
			root_hobt.RowStatus				AS RowStatus,
			root_hobt.Guid					AS Guid,
			root_hobt.Code					AS Code,
			root_hobt.GridDefinitionId		AS GridDefinitionId,
			root_hobt.DetailPageUri			AS DetailPageUri,
			root_hobt.SqlQuery				AS SqlQuery,
			root_hobt.DefaultSortColumnName AS DefaultSortColumnName,
			root_hobt.SecurableCode			AS SecurableCode,
			root_hobt.DisplayOrder			AS DisplayOrder,
			olfu.LabelPlural				AS Name
FROM
        SUserInterface.GridViewDefinitions root_hobt
JOIN
        SUserInterface.GridDefinitions gd ON (gd.ID = root_hobt.GridDefinitionId)
OUTER APPLY
        SCore.ObjectLabelForUser(root_hobt.LanguageLabelId, @UserId) olfu
WHERE
        (gd.Guid = @ParentGuid)
GO
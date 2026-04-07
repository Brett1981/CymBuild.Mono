SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SUserInterface].[tvf_GridViewColumnDefinitions]
  (
    @GridViewDefinitionId INT,
    @UserId       INT
  )
RETURNS TABLE
   --WITH SCHEMABINDING
AS
  RETURN SELECT
          gvcd.ID,
          gvcd.RowStatus,
          gvcd.RowVersion,
          gvcd.Guid,
          gvcd.Name,
          gvcd.ColumnOrder,
          olfu.Label AS Title,
          gvcd.GridViewDefinitionId,
          gvcd.IsPrimaryKey,
          gvcd.IsHidden,
          gvcd.IsFiltered,
          gvcd.IsCombo,
          gvcd.IsLongitude,
          gvcd.IsLatitude,
          gvcd.DisplayFormat,
          gvcd.Width,
          gvcd.LanguageLabelId,
		  --[NEW][CBLD-383]
		  gvcd.TopHeaderCategory,
		  gvcd.TopHeaderCategoryOrder
  FROM
          SUserInterface.GridViewColumnDefinitions gvcd
  OUTER APPLY
          SCore.ObjectLabelForUser(gvcd.LanguageLabelId, @UserId) olfu
  WHERE
          (gvcd.GridViewDefinitionId = @GridViewDefinitionId)
          AND (gvcd.RowStatus NOT IN (0, 254))
          AND (EXISTS
          (
              SELECT
                      1
              FROM
                      SCore.ObjectSecurityForUser_CanRead(gvcd.Guid, @UserId) oscr
          )
          )
GO
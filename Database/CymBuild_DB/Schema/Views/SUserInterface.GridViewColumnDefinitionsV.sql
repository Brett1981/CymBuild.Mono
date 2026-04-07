SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SUserInterface].[GridViewColumnDefinitionsV]
   --WITH SCHEMABINDING
AS
  SELECT
          gvcd.ID,
          gvcd.RowStatus,
          gvcd.RowVersion,
          gvcd.Guid,
          gvcd.Name,
          gvcd.ColumnOrder,
          gvcd.GridViewDefinitionId,
          gvcd.IsPrimaryKey,
          gvcd.IsHidden,
          gvcd.IsFiltered,
          gvcd.IsCombo,
          gvcd.IsLongitude,
          gvcd.IsLatitude,
          gvcd.DisplayFormat,
          gvcd.Width,
          ll.Guid AS LanguageLabelGuid
  FROM
          SUserInterface.GridViewColumnDefinitions gvcd
  JOIN SCore.LanguageLabels ll ON (ll.ID = gvcd.LanguageLabelId)
  WHERE
          (gvcd.RowStatus NOT IN (0, 254))

GO
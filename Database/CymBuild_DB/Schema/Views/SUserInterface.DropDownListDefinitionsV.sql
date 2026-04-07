SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SUserInterface].[DropDownListDefinitionsV]
             --WITH SCHEMABINDING
AS
SELECT	ddld.ID,
		ddld.RowStatus,
		ddld.RowVersion,
		ddld.Guid,
		ddld.Code,
		ddld.NameColumn,
		ddld.ValueColumn,
		ddld.GroupColumn,
		ddld.SqlQuery,
		ddld.DefaultSortColumnName,
		ddld.IsDefaultColumn,
		ddld.DetailPageUrl,
		ddld.IsDetailWindowed,
		ddld.EntityTypeId,
		ddld.InformationPageUrl
FROM	SUserInterface.DropDownListDefinitions ddld
WHERE	(ddld.RowStatus NOT IN (0, 254))
GO
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SCore].[EntityTypesV] 
    --WITH SCHEMABINDING
AS SELECT	et.ID,
		et.RowStatus,
		et.RowVersion,
		et.Guid,
		et.Name,
		et.IsReadOnlyOffline,
		et.IsRequiredSystemData,
		et.HasDocuments,
		et.LanguageLabelID,
		et.DoNotTrackChanges,
		i.Name as IconCss,
		et.IsRootEntity,
		et.DetailPageUrl
FROM	Score.[EntityTypes] et
JOIN   SUserInterface.Icons i ON et.IconId = i.ID
WHERE	(et.[RowStatus] NOT IN (0, 254))
GO
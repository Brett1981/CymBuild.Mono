SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SUserInterface].[GridViewDefinitionsV] 
AS SELECT
        gvd.ID,
        gvd.RowStatus,
        gvd.RowVersion,
        gvd.Guid,
        gvd.Code,
        gvd.GridDefinitionId,
        gvd.DetailPageUri,
        gvd.SqlQuery,
        gvd.DefaultSortColumnName,
        gvd.SecurableCode,
        gvd.DisplayOrder,
        gvd.DisplayGroupName,
        gvd.MetricSqlQuery,
        gvd.ShowMetric,
        gvd.IsDetailWindowed,
        gvd.EntityTypeID,
        gvd.MetricTypeID,
        gvd.MetricMin,
        gvd.MetricMax,
        gvd.MetricMinorUnit,
        gvd.MetricMajorUnit,
        gvd.MetricStartAngle,
        gvd.MetricEndAngle,
        gvd.MetricReversed,
        gvd.MetricRange1Min,
        gvd.MetricRange1Max,
        gvd.MetricRange1ColourHex,
        gvd.MetricRange2Min,
        gvd.MetricRange2Max,
        gvd.MetricRange2ColourHex,
        i.Name AS DrawerIconCss,
        gvd.IsDefaultSortDescending,
        gvd.AllowNew,
        gvd.AllowExcelExport,
        gvd.AllowPdfExport,
        gvd.AllowCsvExport,
		gvd.GridViewTypeId,
		gvd.AllowBulkChange
FROM
        SUserInterface.GridViewDefinitions gvd
JOIN
        SUserInterface.Icons i ON (gvd.DrawerIconId = i.ID)
WHERE
        (gvd.RowStatus NOT IN (0, 254))
GO
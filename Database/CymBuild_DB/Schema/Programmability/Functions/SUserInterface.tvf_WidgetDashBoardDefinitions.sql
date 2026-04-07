SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SUserInterface].[tvf_WidgetDashBoardDefinitions] (@UserId INT)
RETURNS TABLE
	   --WITH SCHEMABINDING
AS
RETURN
(
    -- Select Widget Grid Definitions
    SELECT 
        N'WIDGETGRIDS' AS Type,
        olfu.LabelPlural AS Name,
        gvd.ID,
        gvd.Guid,
        gvd.ROWVERSION,
        gvd.Code,
        gd.Code AS GridCode,
        gvd.GridDefinitionId,
        gvd.SqlQuery,
        gvd.DetailPageUri,
        gvd.DefaultSortColumnName,
        gvd.DisplayGroupName,
        gvd.DisplayOrder,
        gvd.MetricSqlQuery,
        gvd.ShowMetric,
        gvd.IsDetailWindowed,
        i.Name AS DrawerIconCss,
        gvd.IsDefaultSortDescending,
        gvd.AllowNew,
        gvd.AllowExcelExport,
        gvd.AllowPdfExport,
        gvd.AllowCsvExport,
        et.Guid AS EntityTypeGuid,
        gvt.Guid AS GridViewTypeGuid,
        gvd.GridViewTypeId,
        gvd.AllowBulkChange,
        '' AS WidgetDisplayGroupName,
        0 AS WidgetDisplayOrder,
        0 AS [Min], 
        0 AS [Max],
        0 AS [MinorUnit],
        0 AS [MajorUnit],
        0 AS [StartAngle],
        0 AS [EndAngle],
        0 AS [Reverse],
        0 AS Range1MinValue,
        0 AS Range1MaxValue,
        '' AS Range1ColourHex,
        0 AS Range2MinValue,
        0 AS Range2MaxValue,
        '' AS Range2ColourHex,
        '' AS MetricTypeName,
        '00000000-0000-0000-0000-000000000000' AS MetricGuid,
        '' AS GaugeMetricSqlQuery,
        '' AS PageUri
    FROM 
        SUserInterface.GridViewDefinitions gvd
    JOIN 
        SUserInterface.GridDefinitions gd ON gd.ID = gvd.GridDefinitionId
    JOIN 
        SUserInterface.Icons i ON gvd.DrawerIconId = i.ID
    JOIN 
        SUserInterface.GridViewTypes gvt ON gvt.ID = gvd.GridViewTypeId
    JOIN 
        SCore.EntityTypes et ON gvd.EntityTypeID = et.ID
    OUTER APPLY 
        SCore.ObjectLabelForUser(gvd.LanguageLabelID, @UserId) olfu
    WHERE 
        EXISTS (
            SELECT 1 
            FROM SCore.ObjectSecurityForUser_CanRead(gvd.Guid, @UserId) 
        )
		AND 
		EXISTS (
            SELECT 1 
            FROM SCore.ObjectSecurityForUser_CanRead(gd.Guid, @UserId) 
        )
		AND (gvd.ShowOnDashboard = 1)
		AND (gvd.ShowMetric = 0)
		AND (gvd.RowStatus NOT IN (0,254))

    UNION ALL

    -- Select Widget Gauges
    SELECT 
        N'WIDGETGAUGES' AS Type,
        olfu.LabelPlural,
        0 AS ID,
        '00000000-0000-0000-0000-000000000000' AS Guid,
        0 AS ROWVERSION,
        gvd.Code AS Code,
        gd.Code AS GridCode,
        '' AS GridDefinitionId,
        '' AS SqlQuery,
        '' AS DetailPageUri,
        '' AS DefaultSortColumnName,
        '' AS DisplayGroupName,
        0 AS DisplayOrder,
        '' AS MetricSqlQuery,
        0 AS ShowMetric,
        0 AS IsDetailWindowed,
        '' AS DrawerIconCss,
        0 AS IsDefaultSortDescending,
        0 AS AllowNew,
        0 AS AllowExcelExport,
        0 AS AllowPdfExport,
        0 AS AllowCsvExport,
        '00000000-0000-0000-0000-000000000000' AS EntityTypeGuid,
        '00000000-0000-0000-0000-000000000000' AS GridViewTypeGuid,
        0 AS GridViewTypeId,
        0 AS AllowBulkChange,
        gvd.DisplayGroupName,
        gvd.DisplayOrder,
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
        mt.Name AS MetricTypeName,
        gvd.Guid AS MetricGuid,
        gvd.MetricSqlQuery,
        gd.PageUri
    FROM 
        SUserInterface.GridViewDefinitions gvd
    JOIN 
        SUserInterface.GridDefinitions gd ON gd.ID = gvd.GridDefinitionId
    JOIN 
        SUserInterface.MetricTypes mt ON mt.ID = gvd.MetricTypeID
    OUTER APPLY 
        SCore.ObjectLabelForUser(gvd.LanguageLabelId, @UserId) olfu
    WHERE 
        (gvd.ShowMetric = 1) 
		AND gvd.MetricSqlQuery <> N''
        AND gvd.RowStatus NOT IN (0, 254)
        AND gd.RowStatus NOT IN (0, 254)
        AND mt.RowStatus NOT IN (0, 254)
        AND EXISTS (
            SELECT 1 
            FROM SCore.ObjectSecurityForUser_CanRead(gvd.Guid, @UserId)
        )
		AND EXISTS (
            SELECT 1 
            FROM SCore.ObjectSecurityForUser_CanRead(gd.Guid, @UserId)
        )

    UNION ALL

    -- Select Widget Layout
    SELECT 
        N'WIDGETLAYOUT' AS Type,
        WidgetLayout,
        0 AS ID,
        '00000000-0000-0000-0000-000000000000' AS Guid,
        0 AS ROWVERSION,
        '' AS Code,
        '' AS GridCode,
        '' AS GridDefinitionId,
        '' AS SqlQuery,
        '' AS DetailPageUri,
        '' AS DefaultSortColumnName,
        '' AS DisplayGroupName,
        0 AS DisplayOrder,
        '' AS MetricSqlQuery,
        0 AS ShowMetric,
        0 AS IsDetailWindowed,
        '' AS DrawerIconCss,
        0 AS IsDefaultSortDescending,
        0 AS AllowNew,
        0 AS AllowExcelExport,
        0 AS AllowPdfExport,
        0 AS AllowCsvExport,
        '00000000-0000-0000-0000-000000000000' AS EntityTypeGuid,
        '00000000-0000-0000-0000-000000000000' AS GridViewTypeGuid,
        0 AS GridViewTypeId,
        0 AS AllowBulkChange,
        '' AS WidgetDisplayGroupName,
        0 AS WidgetDisplayOrder,
        0 AS Min,
        0 AS Max,
        0 AS MinorUnit,
        0 AS MajorUnit,
        0 AS StartAngle,
        0 AS EndAngle,
        0 AS Reverse,
        0 AS Range1MinValue,
        0 AS Range1MaxValue,
        '' AS Range1ColourHex,
        0 AS Range2MinValue,
        0 AS Range2MaxValue,
        '' AS Range2ColourHex,
        '' AS MetricTypeName,
        '00000000-0000-0000-0000-000000000000' AS MetricGuid,
        '' AS GaugeMetricSqlQuery,
        '' AS PageUri
    FROM 
        SCore.UserPreferences
    WHERE 
        ID = @UserId
)


GO
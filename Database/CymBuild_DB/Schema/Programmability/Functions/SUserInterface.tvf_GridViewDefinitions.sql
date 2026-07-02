SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SUserInterface].[tvf_GridViewDefinitions]')
GO
PRINT (N'Create function [SUserInterface].[tvf_GridViewDefinitions]')
GO

CREATE FUNCTION [SUserInterface].[tvf_GridViewDefinitions]
(
    @Id INT,
    @GridViewCode NVARCHAR(20),
    @GridCode NVARCHAR(30),
    @UserId INT
)
RETURNS TABLE
--WITH SCHEMABINDING
AS
RETURN
SELECT
    gvd.[ID] AS [ID],
    gvd.[RowStatus] AS [RowStatus],
    gvd.[RowVersion] AS [RowVersion],
    gvd.[Guid] AS [Guid],
    gvd.[Code] AS [Code],
    gvd.[GridDefinitionId] AS [GridDefinitionId],
    gvd.[DetailPageUri] AS [DetailPageUri],
    gvd.[SqlQuery] AS [SqlQuery],
    gvd.[DefaultSortColumnName] AS [DefaultSortColumnName],
    gvd.[SecurableCode] AS [SecurableCode],
    gvd.[DisplayOrder] AS [DisplayOrder],
    gvd.[DisplayGroupName] AS [DisplayGroupName],
    gvd.[MetricSqlQuery] AS [MetricSqlQuery],
    gvd.[ShowMetric] AS [ShowMetric],
    gvd.[IsDetailWindowed] AS [IsDetailWindowed],
    gvd.[EntityTypeID] AS [EntityTypeID],
    gvd.[MetricTypeID] AS [MetricTypeID],
    gvd.[MetricMin] AS [MetricMin],
    gvd.[MetricMax] AS [MetricMax],
    gvd.[MetricMinorUnit] AS [MetricMinorUnit],
    gvd.[MetricMajorUnit] AS [MetricMajorUnit],
    gvd.[MetricStartAngle] AS [MetricStartAngle],
    gvd.[MetricEndAngle] AS [MetricEndAngle],
    gvd.[MetricReversed] AS [MetricReversed],
    gvd.[MetricRange1Min] AS [MetricRange1Min],
    gvd.[MetricRange1Max] AS [MetricRange1Max],
    gvd.[MetricRange1ColourHex] AS [MetricRange1ColourHex],
    gvd.[MetricRange2Min] AS [MetricRange2Min],
    gvd.[MetricRange2Max] AS [MetricRange2Max],
    gvd.[MetricRange2ColourHex] AS [MetricRange2ColourHex],
    gvd.[IsDefaultSortDescending] AS [IsDefaultSortDescending],
    CASE
        WHEN gvd.[Code] = N'TRANSACTIONDETAILS'
         AND EXISTS
             (
                 SELECT
                     1
                 FROM SUserInterface.GridDefinitions AS gd_allow
                 WHERE gd_allow.ID = gvd.GridDefinitionId
                   AND gd_allow.Code = N'TRANSACTIONDETAILS'
                   AND gd_allow.RowStatus NOT IN (0, 254)
             )
         AND NOT EXISTS
             (
                 SELECT
                     1
                 FROM SCore.UserGroups AS ug_fin
                 JOIN SCore.Groups AS g_fin
                   ON g_fin.ID = ug_fin.GroupID
                 WHERE ug_fin.IdentityID = @UserId
                   AND ug_fin.RowStatus NOT IN (0, 254)
                   AND g_fin.RowStatus NOT IN (0, 254)
                   AND
                   (
                       g_fin.Code = N'FINANCE'
                       OR g_fin.Name IN (N'Finance', N'Finance Group')
                   )
             )
            THEN CONVERT(BIT, 0)
        ELSE gvd.[AllowNew]
    END AS [AllowNew],
    gvd.[AllowExcelExport] AS [AllowExcelExport],
    gvd.[AllowPdfExport] AS [AllowPdfExport],
    gvd.[AllowCsvExport] AS [AllowCsvExport],
    gvd.[LanguageLabelId] AS [LanguageLabelId],
    gvd.[DrawerIconId] AS [DrawerIconId],
    gvd.[GridViewTypeId] AS [GridViewTypeId],
    gvd.[AllowBulkChange] AS [AllowBulkChange],
    gvd.[ShowOnMobile] AS [ShowOnMobile],
    gvd.[TreeListFirstOrderBy] AS [TreeListFirstOrderBy],
    gvd.[TreeListSecondOrderBy] AS [TreeListSecondOrderBy],
    gvd.[TreeListThirdOrderBy] AS [TreeListThirdOrderBy],
    gvd.[TreeListOrderBy] AS [TreeListOrderBy],
    gvd.[TreeListGroupBy] AS [TreeListGroupBy],
    gvd.[ShowOnDashboard] AS [ShowOnDashboard],
    gvd.[FilteredListCreatedOnColumn] AS [FilteredListCreatedOnColumn],
    gvd.[FilteredListRedStatusIndicatorTxt] AS [FilteredListRedStatusIndicatorTxt],
    gvd.[FilteredListOrangeStatusIndicatorTxt] AS [FilteredListOrangeStatusIndicatorTxt],
    gvd.[FilteredListGreenStatusIndicatorTxt] AS [FilteredListGreenStatusIndicatorTxt],
    gvd.[FilteredListGroupBy] AS [FilteredListGroupBy],
    gvd.[IsHidden] AS [IsHidden],
    CONVERT(NVARCHAR(250), COALESCE(olfu.LabelPlural, gvd.[Code], N'')) AS [Name],
    CONVERT(NVARCHAR(100), COALESCE(i.[Name], N'')) AS [DrawerIconCss],
    COALESCE(et.[Guid], CONVERT(UNIQUEIDENTIFIER, '00000000-0000-0000-0000-000000000000')) AS [EntityTypeGuid],
    COALESCE(gvt.[Guid], CONVERT(UNIQUEIDENTIFIER, '00000000-0000-0000-0000-000000000000')) AS [GridViewTypeGuid],
    CONVERT(NVARCHAR(30), COALESCE(gd_filter.[Code], N'')) AS [GridCode]
FROM SUserInterface.GridViewDefinitions AS gvd
LEFT JOIN SUserInterface.GridDefinitions AS gd_filter
  ON gd_filter.ID = gvd.GridDefinitionId
LEFT JOIN SUserInterface.Icons AS i
  ON i.ID = gvd.DrawerIconId
LEFT JOIN SUserInterface.GridViewTypes AS gvt
  ON gvt.ID = gvd.GridViewTypeId
LEFT JOIN SCore.EntityTypes AS et
  ON et.ID = gvd.EntityTypeID
OUTER APPLY SCore.ObjectLabelForUser(gvd.LanguageLabelID, @UserId) AS olfu
WHERE
    (
        gvd.ID = @Id
        OR
        (
            gd_filter.RowStatus NOT IN (0, 254)
            AND gd_filter.Code = @GridCode
            AND
            (
                gvd.Code = @GridViewCode
                OR @GridViewCode = N''
            )
        )
    )
    AND gvd.RowStatus NOT IN (0, 254)
    AND EXISTS
    (
        SELECT
            1
        FROM SCore.ObjectSecurityForUser_CanRead(gvd.Guid, @UserId) AS oscr
    );
GO
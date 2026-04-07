SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SUserInterface].[tvf_GridViewDefinitions]
  (
    @Id           INT,
    @GridViewCode NVARCHAR(20),
    @GridCode     NVARCHAR(30),
    @UserId       INT
  )
RETURNS TABLE
      --WITH SCHEMABINDING
AS
  RETURN SELECT
		gvd.ID,
		gvd.Code,
		gvd.Guid,
		olfu.LabelPlural Name,
		gvd.RowVersion,
		gvd.GridDefinitionId,
		gvd.SqlQuery,
		gvd.DetailPageUri,
		gvd.DefaultSortColumnName,
		gvd.DisplayGroupName,
		gvd.DisplayOrder,
		gvd.MetricSqlQuery,
		gvd.ShowMetric,
		gvd.IsDetailWindowed,
		i.Name			 AS DrawerIconCss,
		gvd.IsDefaultSortDescending,
		gvd.AllowNew,
		gvd.AllowExcelExport,
		gvd.AllowPdfExport,
		gvd.AllowCsvExport,
		et.Guid			 AS EntityTypeGuid,
		gvt.Guid		 AS GridViewTypeGuid,
		gvd.GridViewTypeId,
		gvd.AllowBulkChange,
		gvd.ShowOnMobile,
		gvd.TreeListFirstOrderBy,
		gvd.TreeListSecondOrderBy,
		gvd.TreeListThirdOrderBy,
		gvd.TreeListOrderBy,
		gvd.TreeListGroupBy,
		gvd.FilteredListCreatedOnColumn,
		gvd.FilteredListGroupBy,
		gvd.FilteredListRedStatusIndicatorTxt,
		gvd.FilteredListOrangeStatusIndicatorTxt,
		gvd.FilteredListGreenStatusIndicatorTxt
FROM
		SUserInterface.GridViewDefinitions AS gvd
JOIN
		SUserInterface.Icons i ON gvd.DrawerIconId = i.ID
JOIN
		SUserInterface.GridViewTypes gvt ON (gvt.ID = gvd.GridViewTypeId)
JOIN
		SCore.EntityTypes AS et ON (gvd.EntityTypeID = et.ID)
OUTER APPLY
		SCore.ObjectLabelForUser(gvd.LanguageLabelID, @UserId) olfu
WHERE
		(
				(gvd.ID = @Id)
				OR (
						(EXISTS
							(
								SELECT	1
								FROM	SUserInterface.GridDefinitions AS gd
								WHERE	(gd.ID = gvd.GridDefinitionId)
									AND (gd.RowStatus NOT IN (0, 254))
									AND	(gd.Code = @GridCode)
							)
						)
						AND (
								(gvd.Code = @GridViewCode)
								OR (@GridViewCode = N'')
						)
				)
		)
		AND (gvd.RowStatus NOT IN (0, 254))		
		AND (EXISTS
		(
			SELECT
					1
			FROM
					SCore.ObjectSecurityForUser_CanRead(gvd.Guid, @UserId) oscr
		)
		)
GO
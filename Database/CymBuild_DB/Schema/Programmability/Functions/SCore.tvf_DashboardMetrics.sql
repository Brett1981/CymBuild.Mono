SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[tvf_DashboardMetrics]
  (
    @UserId INT
  )
RETURNS TABLE
   --WITH SCHEMABINDING
AS
  RETURN
  SELECT
          olfu.LabelPlural          Label,
          gvd.DisplayGroupName,
          gvd.DisplayOrder,
          gvd.MetricMin             [Min],
          gvd.MetricMax             [Max],
          gvd.MetricMinorUnit       [MinorUnit],
          gvd.MetricMajorUnit       [MajorUnit],
          gvd.MetricStartAngle      [StartAngle],
          gvd.MetricEndAngle        [EndAngle],
          gvd.MetricReversed        [Reverse],
          gvd.MetricRange1Min       AS Range1MinValue,
          gvd.MetricRange1Max       AS Range1MaxValue,
          gvd.MetricRange1ColourHex AS Range1ColourHex,
          gvd.MetricRange2Min       AS Range2MinValue,
          gvd.MetricRange2Max       AS Range2MaxValue,
          gvd.MetricRange2ColourHex AS Range2ColourHex,
          mt.Name                   MetricTypeName,
          gvd.Guid,
          gvd.MetricSqlQuery,
          gd.PageUri
  FROM
          SUserInterface.GridViewDefinitions AS gvd
  JOIN
          SUserInterface.GridDefinitions gd ON (gd.ID = gvd.GridDefinitionId)
  JOIN
          SUserInterface.MetricTypes AS mt ON (mt.ID = gvd.MetricTypeID)
  OUTER APPLY
          SCore.ObjectLabelForUser(gvd.LanguageLabelId, @UserId) olfu
  WHERE
          (gvd.ShowMetric = 1)
          AND (gvd.RowStatus NOT IN (0, 254))
          AND (gd.RowStatus NOT IN (0, 254))
          AND (mt.RowStatus NOT IN (0, 254))
		  AND	(EXISTS
					(				
						SELECT
								1
						FROM
								SCore.ObjectSecurityForUser_CanRead(gvd.Guid, @UserId) oscr
					)
				)


GO
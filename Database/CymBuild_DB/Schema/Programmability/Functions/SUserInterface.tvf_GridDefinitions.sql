SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SUserInterface].[tvf_GridDefinitions]
  (
    @GridCode NVARCHAR(30),
    @UserId   INT
  )
RETURNS TABLE
   --WITH SCHEMABINDING
AS
  RETURN SELECT
          gd.ID,
          gd.RowStatus,
          gd.RowVersion,
          gd.Guid,
          gd.Code,
          olfu.LabelPlural Name,
          gd.PageUri,
          gd.TabName,
          gd.ShowAsTiles
  FROM
          SUserInterface.GridDefinitions AS gd
  OUTER APPLY
          SCore.ObjectLabelForUser(gd.LanguageLabelId, @UserId) olfu
  WHERE
          (gd.RowStatus NOT IN (0, 254))
          AND (gd.Code = @GridCode)
          AND (EXISTS
          (
              SELECT
                      1
              FROM
                      SCore.ObjectSecurityForUser_CanRead(gd.Guid, @UserId) oscr
          )
          )

GO
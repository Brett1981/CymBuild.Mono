SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SUserInterface].[tvf_MainMenuItems]
  (
    @UserId   INT
  )
RETURNS TABLE
   --WITH SCHEMABINDING
AS
  RETURN SELECT
          mmi.ID,
          mmi.RowStatus,
          mmi.RowVersion,
          mmi.Guid,
          olfu.LabelPlural Name,
          i.Name AS Icon,
		  mmi.NavigationUrl,
		  mmi.SortOrder
  FROM
          SUserInterface.MainMenuItems AS mmi
  JOIN		
		  SUserInterface.Icons AS i ON (i.Id = mmi.IconId)
  OUTER APPLY
          SCore.ObjectLabelForUser(mmi.LanguageLabelId, @UserId) olfu
  WHERE
          (mmi.RowStatus NOT IN (0, 254))
          AND (EXISTS
          (
              SELECT
                      1
              FROM
                      SCore.ObjectSecurityForUser_CanRead(mmi.Guid, @UserId) oscr
          )
          )

GO
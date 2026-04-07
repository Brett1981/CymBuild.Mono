SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SUserInterface].[tvf_ActionMenuItems]
  (
    @UserId INT,
    @Guid   UNIQUEIDENTIFIER
  )
RETURNS TABLE
   --WITH SCHEMABINDING
AS
  RETURN SELECT
          ami.ID,
          ami.RowStatus,
          ami.Guid,
          ami.Type,
          ami.EntityTypeId,
		  ami.SortOrder,
          ISNULL(olfu.Label, N'') AS Label
  FROM
          SUserInterface.ActionMenuItems ami
  JOIN
          SCore.EntityTypes et ON (ami.EntityTypeId = et.ID)
  OUTER APPLY
          SCore.ObjectLabelForUser(ami.LanguageLabelId, @UserId) olfu
  WHERE
          (ami.RowStatus NOT IN (0, 254))
          AND (et.Guid = @Guid)
          AND (EXISTS
          (
              SELECT
                      1
              FROM
                      SCore.ObjectSecurityForUser_CanRead(ami.Guid, @UserId) oscr
          )
          )

GO
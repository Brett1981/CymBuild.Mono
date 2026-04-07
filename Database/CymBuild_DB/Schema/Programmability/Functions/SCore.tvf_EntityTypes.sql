SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[tvf_EntityTypes]
  (
    @Guid   UNIQUEIDENTIFIER,
    @UserId INT
  )
RETURNS TABLE
   --WITH SCHEMABINDING
AS
  RETURN SELECT
          et.RowStatus,
          et.RowVersion,
          et.Guid,
          et.Name,
          et.IsReadOnlyOffline,
          et.IsRequiredSystemData,
          et.HasDocuments,
          i.Name AS IconCss,
          et.IsRootEntity,
          et.DetailPageUrl,
          ll.Guid AS LanguageLabelGuid,
          et.DoNotTrackChanges,
          os.CanRead,
          os.CanWrite,
          lt.Label
  FROM
          SCore.EntityTypes AS et
  JOIN
          SCore.LanguageLabelsV AS ll ON (et.LanguageLabelID = ll.ID)
  JOIN
          SUserInterface.Icons i ON (i.ID = et.IconId)
  OUTER APPLY
          SCore.ObjectSecurityForUser(et.Guid,
          @UserId
          ) AS os
  OUTER APPLY
          SCore.ObjectLabelForUser(et.LanguageLabelID,
          @UserId
          ) AS lt
  WHERE
          (et.Guid = @Guid)
          AND (et.RowStatus NOT IN (0, 254))
          AND (et.ID > -1);
GO
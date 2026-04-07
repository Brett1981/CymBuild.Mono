SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[tvf_UserGroups]
  (
    @UserGuid UNIQUEIDENTIFIER
  )
RETURNS TABLE
AS
  RETURN SELECT
          ug.ID,
          ug.Guid,
          ug.RowStatus,
          ug.RowVersion,
          ug.IdentityID,
          ug.GroupID,
          g.Name AS GroupName
  FROM
          SCore.UserGroups ug
  JOIN    
          SCore.Groups g ON (ug.GroupID = g.ID)
  JOIN
          SCore.Identities i ON (ug.IdentityID = i.ID)
  WHERE
          (i.Guid = @UserGuid)
          
GO
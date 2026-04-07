SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE FUNCTION [SUserInterface].[tvf_Icons]
  (
    @UserId INT
  )
RETURNS TABLE
        --WITH SCHEMABINDING
AS
  RETURN 
	SELECT
		icons.ID,
		icons.Guid,
		icons.RowStatus,
		icons.Name
  FROM
          SUserInterface.Icons AS icons

  WHERE
          (icons.RowStatus NOT IN (0, 254))
         
          AND (EXISTS
          (
              SELECT
                      1
              FROM
                      SCore.ObjectSecurityForUser_CanRead(icons.Guid, @UserId) oscr
          )
          )

GO
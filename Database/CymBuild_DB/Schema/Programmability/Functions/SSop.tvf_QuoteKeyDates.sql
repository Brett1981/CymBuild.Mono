SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SSop].[tvf_QuoteKeyDates]
  (
    @UserId     INT,
    @ParentGuid UNIQUEIDENTIFIER
  )
RETURNS TABLE
   --WITH SCHEMABINDING
AS
  RETURN
  SELECT
          pkd.ID,
          pkd.RowStatus,
          pkd.RowVersion,
          pkd.Guid,
          pkd.Detail,
          pkd.DateTime
  FROM
          SSop.ProjectKeyDates pkd
  JOIN
          SSop.Quotes q ON (q.ProjectId = pkd.ProjectID)
  WHERE
          (pkd.RowStatus NOT IN (0, 254))
AND	(EXISTS
			(
			  SELECT
					  1
			  FROM
					  SCore.ObjectSecurityForUser_CanRead(q.Guid, @UserId) oscr
			)
		)
          AND (q.Guid = @ParentGuid)
GO
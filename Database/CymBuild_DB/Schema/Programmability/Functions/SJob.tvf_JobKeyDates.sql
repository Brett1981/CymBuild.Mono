SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_JobKeyDates]
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
          SJob.Jobs j ON (j.ProjectId = pkd.ProjectID)
  WHERE
          (pkd.RowStatus NOT IN (0, 254))
          AND (j.Guid = @ParentGuid)
		  AND	(EXISTS
			(				
	SELECT
			1
	FROM
			SCore.ObjectSecurityForUser_CanRead(pkd.Guid, @UserId) oscr
			)
		)
GO
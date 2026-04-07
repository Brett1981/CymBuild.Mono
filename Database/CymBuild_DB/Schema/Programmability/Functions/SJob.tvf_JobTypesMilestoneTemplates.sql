SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_JobTypesMilestoneTemplates]
  (
    @UserId     INT,
    @ParentGuid UNIQUEIDENTIFIER
  )
RETURNS TABLE
   --WITH SCHEMABINDING
AS
  RETURN
  SELECT
          jtmt.ID,
          jtmt.RowStatus,
          jtmt.RowVersion,
          jtmt.Guid,
          jtmt.SortOrder,
          mt.Name
  FROM
          SJob.JobTypeMilestoneTemplates jtmt
  JOIN
          SJob.MilestoneTypes mt ON (mt.ID = jtmt.MilestoneTypeID)
  JOIN
          SJob.JobTypes jt ON (jt.ID = jtmt.JobTypeID)
  WHERE
          (jtmt.RowStatus NOT IN (0, 254))
          AND (jt.Guid = @ParentGuid)
AND	(EXISTS
			(
			  SELECT
					  1
			  FROM
					  SCore.ObjectSecurityForUser_CanRead(jtmt.Guid, @UserId) oscr
			)
		)
GO
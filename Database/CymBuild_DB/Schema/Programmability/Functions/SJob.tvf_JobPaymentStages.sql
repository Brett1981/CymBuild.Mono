SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_JobPaymentStages]
	(
		@UserId INT,
		@ParentGuid UNIQUEIDENTIFIER
	)
RETURNS TABLE
   --WITH SCHEMABINDING
AS
RETURN SELECT		jps.ID,
					jps.RowStatus,
					jps.RowVersion,
					jps.Guid,
					jps.StagedDate,
					rs.Number AS AfterStageNumber,
					jps.Value,
					rs.Number AS PayAfterStageNumber
	   FROM			SJob.JobPaymentStages			  AS jps
	   JOIN			SJob.Jobs j ON (j.ID = jps.JobId)
	   JOIN			SJob.RibaStages				  AS rs ON (rs.ID = jps.AfterStageId)
	   WHERE		(jps.RowStatus NOT IN (0, 254))
				AND (jps.ID		> 0)
AND	(EXISTS
			(
					SELECT
							1
					FROM
							SCore.ObjectSecurityForUser_CanRead(jps.Guid, @UserId) oscr
			)
		)
				AND (j.Guid		= @ParentGuid)
	   
GO
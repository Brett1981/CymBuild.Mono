SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_JobMemos]
	(
		@UserId INT,
		@ParentGuid UNIQUEIDENTIFIER
	)
RETURNS TABLE
              --WITH SCHEMABINDING
AS
RETURN SELECT		jm.ID,
					jm.RowStatus,
					jm.RowVersion,
					jm.Guid,
					jm.Memo,
					j.Guid AS JobId,
					id.FullName, 
					CONVERT(DATE,jm.CreatedDateTimeUTC) AS CreatedDate 
	   FROM			SJob.JobMemos			AS jm
	   JOIN			SJob.Jobs				AS j ON (j.ID = jm.JobID)
	   JOIN			SCore.Identities		AS id ON (id.ID = jm.CreatedByUserId) 
	   WHERE		(jm.RowStatus NOT IN (0, 254))
				AND (j.Guid		= @ParentGuid)
				AND	(EXISTS
			(
				SELECT	1
				FROM	SCore.ObjectSecurityForUser_CanRead (jm.guid, @UserId) oscr
			)
		)
GO
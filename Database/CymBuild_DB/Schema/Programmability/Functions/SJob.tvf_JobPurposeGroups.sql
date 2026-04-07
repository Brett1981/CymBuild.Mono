SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_JobPurposeGroups]
	(
		@UserId INT,
		@ParentGuid UNIQUEIDENTIFIER
	)
RETURNS TABLE
            --WITH SCHEMABINDING
AS
RETURN SELECT		jpg.ID,
					jpg.RowStatus,
					--jpg.RowVersion,
					jpg.Guid,
					pg.Name AS PurposeGroup
	   FROM			SJob.JobPurposeGroups		  AS jpg
	   JOIN			SJob.PurposeGroups			AS pg ON (pg.ID = jpg.PurposeGroupID)
	   WHERE		(jpg.RowStatus NOT IN (0, 254))
				AND	(EXISTS
						(
							SELECT	1
							FROM	SCore.ObjectSecurityForUser_CanRead (jpg.guid, @UserId) oscr
						)
					)
				AND	(EXISTS
						(
							SELECT	1
							FROM	SJob.Jobs j
							WHERE	(j.ID = jpg.JobID)
								AND (j.Guid		= @ParentGuid)
						)
					)
GO
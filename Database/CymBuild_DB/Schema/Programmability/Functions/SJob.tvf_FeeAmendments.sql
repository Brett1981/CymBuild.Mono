SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_FeeAmendments]
	(
		@UserId INT,
		@ParentGuid UNIQUEIDENTIFIER
	)
RETURNS TABLE
         --WITH SCHEMABINDING
AS
RETURN SELECT		fa.ID,
					fa.RowStatus,
					fa.RowVersion,
					fa.Guid,
					fa.CreatedDateTime,
					fa.RibaStage0Change + fa.RibaStage1Change + fa.RibaStage2Change + fa.RibaStage3Change + fa.RibaStage4Change + fa.RibaStage5Change + fa.RibaStage6Change + fa.RibaStage7Change + fa.PreConstructionStageChange + fa.ConstructionStageChange AS TotalRibaStageChange,
					fa.FeeCapChange,
					i.FullName,
					fa.RibaStage0MeetingChange + fa.RibaStage1MeetingChange + fa.RibaStage2MeetingChange + fa.RibaStage3MeetingChange + fa.RibaStage4MeetingChange + fa.RibaStage5MeetingChange + fa.RibaStage6MeetingChange + fa.RibaStage7MeetingChange + fa.PreConstructionStageMeetingChange + fa.ConstructionStageMeetingChange AS TotalMeetingChange,
					fa.RibaStage0VisitChange + fa.RibaStage1VisitChange + fa.RibaStage2VisitChange + fa.RibaStage3VisitChange + fa.RibaStage4VisitChange + fa.RibaStage5VisitChange + fa.RibaStage6VisitChange + fa.RibaStage7VisitChange + fa.PreConstructionStageVisitChange + fa.ConstructionStageVisitChange AS TotalVisitChange,
					fa.Reason
	   FROM			SJob.FeeAmendment				  AS fa
	   JOIN			SJob.Jobs					  AS j ON (j.ID = fa.JobID)
	   JOIN			SCore.Identities			AS i ON (i.id = fa.CreatedByUserID)
	   WHERE		(fa.RowStatus NOT IN (0, 254))
				AND (j.Guid		= @ParentGuid)
				AND	(EXISTS
			(
					SELECT
							1
					FROM
							SCore.ObjectSecurityForUser_CanRead(fa.Guid, @UserId) oscr
			)
		)
GO
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_JobFeeDrawdown]
	(
		@UserId INT,
		@ParentGuid UNIQUEIDENTIFIER
	)
RETURNS TABLE
   --WITH SCHEMABINDING
AS
RETURN SELECT	j.RowStatus,
				j.Guid,
				j.Stage,
				j.StageLabel,
				j.Agreed,
				j.Invoiced,
				j.Remaining,
				CONVERT(INT, j.QuotedMeetings) QuotedMeetings,
				j.CompletedMeetings,
				CONVERT(INT, j.QuotedSiteVisits) QuotedSiteVisits,
				j.CompletedSiteVisits,
				j.IsTotalHighlightRow
	   FROM		SJob.Job_FeeDrawdown AS j
	   WHERE	(j.Guid = @ParentGuid)
			AND	(EXISTS
			(
				SELECT	1
				FROM	SCore.ObjectSecurityForUser_CanRead (j.guid, @UserId) oscr
			)
		)

GO
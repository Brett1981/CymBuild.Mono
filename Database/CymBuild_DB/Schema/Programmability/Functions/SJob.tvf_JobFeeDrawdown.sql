SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SJob].[tvf_JobFeeDrawdown]')
GO

CREATE FUNCTION [SJob].[tvf_JobFeeDrawdown]
(
    @UserId INT,
    @ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
AS
RETURN
    SELECT
        j.RowStatus,
        j.Guid,
        j.Stage,
        j.StageLabel,
        j.Agreed,
        j.Invoiced,
        j.Paid,
        j.Remaining,
        CONVERT(INT, j.QuotedMeetings) AS QuotedMeetings,
        j.CompletedMeetings,
        CONVERT(INT, j.QuotedSiteVisits) AS QuotedSiteVisits,
        j.CompletedSiteVisits,
        j.IsTotalHighlightRow
    FROM SJob.Job_FeeDrawdown AS j
    WHERE j.Guid = @ParentGuid
      AND j.RowStatus NOT IN (0, 254)
      AND EXISTS
      (
          SELECT 1
          FROM SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) AS oscr
      );
GO
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SJob].[tvf_FeeAmendmentRibaStages]')
GO
CREATE FUNCTION [SJob].[tvf_FeeAmendmentRibaStages]
(
    @UserId INT,
    @ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
AS
RETURN
    SELECT
        fars.RowStatus,
        fars.Guid,
        fa.Guid AS FeeAmendmentID,
        j.Guid AS JobID,
        rs.Guid AS RibaStageID,
        rs.Description AS RibaStage,
        fars.FeeChange,
        fars.MeetingChange,
        fars.VisitChange
    FROM SJob.FeeAmendmentRibaStages AS fars
    JOIN SJob.FeeAmendment AS fa
        ON fa.ID = fars.FeeAmendmentID
    JOIN SJob.Jobs AS j
        ON j.ID = fars.JobID
    JOIN SJob.RibaStages AS rs
        ON rs.ID = fars.RibaStageID
    WHERE fa.Guid = @ParentGuid
      AND fars.RowStatus NOT IN (0,254)
      AND EXISTS
      (
          SELECT 1
          FROM SCore.ObjectSecurityForUser_CanRead(fars.Guid, @UserId) AS oscr
      );
GO
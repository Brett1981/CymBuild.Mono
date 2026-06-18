SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SJob].[tvf_FeeAmendments]')
GO

CREATE FUNCTION [SJob].[tvf_FeeAmendments]
(
    @UserId INT,
    @ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
AS
RETURN
    SELECT
        fa.ID,
        fa.RowStatus,
        fa.RowVersion,
        fa.Guid,
        fa.CreatedDateTime,
        CAST
        (
            fa.RibaStage0Change
          + fa.RibaStage1Change
          + fa.RibaStage2Change
          + fa.RibaStage3Change
          + fa.RibaStage4Change
          + fa.RibaStage5Change
          + fa.RibaStage6Change
          + fa.RibaStage7Change
          + fa.PreConstructionStageChange
          + fa.ConstructionStageChange
          + ISNULL(dynamic_totals.DynamicRibaStageChange, 0)
            AS DECIMAL(19,2)
        ) AS TotalRibaStageChange,
        fa.FeeCapChange,
        i.FullName,
        CAST
        (
            fa.RibaStage0MeetingChange
          + fa.RibaStage1MeetingChange
          + fa.RibaStage2MeetingChange
          + fa.RibaStage3MeetingChange
          + fa.RibaStage4MeetingChange
          + fa.RibaStage5MeetingChange
          + fa.RibaStage6MeetingChange
          + fa.RibaStage7MeetingChange
          + fa.PreConstructionStageMeetingChange
          + fa.ConstructionStageMeetingChange
          + ISNULL(dynamic_totals.DynamicMeetingChange, 0)
            AS DECIMAL(19,2)
        ) AS TotalMeetingChange,
        CAST
        (
            fa.RibaStage0VisitChange
          + fa.RibaStage1VisitChange
          + fa.RibaStage2VisitChange
          + fa.RibaStage3VisitChange
          + fa.RibaStage4VisitChange
          + fa.RibaStage5VisitChange
          + fa.RibaStage6VisitChange
          + fa.RibaStage7VisitChange
          + fa.PreConstructionStageVisitChange
          + fa.ConstructionStageVisitChange
          + ISNULL(dynamic_totals.DynamicVisitChange, 0)
            AS DECIMAL(19,2)
        ) AS TotalVisitChange,
        fa.Reason
    FROM SJob.FeeAmendment AS fa
    JOIN SJob.Jobs AS j
        ON j.ID = fa.JobID
    JOIN SCore.Identities AS i
        ON i.ID = fa.CreatedByUserID
	OUTER APPLY
	(
		SELECT
			SUM(x.FeeChange) AS DynamicRibaStageChange,
			SUM(x.MeetingChange) AS DynamicMeetingChange,
			SUM(x.VisitChange) AS DynamicVisitChange
		FROM
		(
			SELECT
				fars.FeeChange,
				fars.MeetingChange,
				fars.VisitChange
			FROM SJob.FeeAmendmentRibaStages AS fars
			WHERE fars.FeeAmendmentID = fa.ID
			  AND fars.RowStatus NOT IN (0,254)

			UNION ALL

			SELECT
				cfa.StageChange,
				cfa.StageMeetingChange,
				cfa.StageVisitChange
			FROM SJob.CustomFeeAmendment AS cfa
			WHERE cfa.FeeAmendmentId = fa.ID
			  AND cfa.RowStatus NOT IN (0,254)
		) x
	) AS dynamic_totals
    WHERE fa.RowStatus NOT IN (0,254)
      AND j.Guid = @ParentGuid
      AND EXISTS
      (
          SELECT 1
          FROM SCore.ObjectSecurityForUser_CanRead(fa.Guid, @UserId) AS oscr
      );
GO
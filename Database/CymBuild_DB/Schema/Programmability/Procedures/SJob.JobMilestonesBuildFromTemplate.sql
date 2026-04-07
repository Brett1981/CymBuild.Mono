SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SJob].[JobMilestonesBuildFromTemplate]
  (
    @JobID INT
  )
AS
  BEGIN
    DECLARE @JobMilestonesEntityTypeId INT;

    SELECT
            @JobMilestonesEntityTypeId = ID
    FROM
            SCore.EntityTypes et
    WHERE
            (Guid = '39ebe47d-7e0d-495b-8a2f-9a9306c77b7c')

    DECLARE @MileStones TABLE
        (
          Guid            UNIQUEIDENTIFIER,
          MilestoneTypeId INT,
          SortOrder       INT
        )

    INSERT @MileStones
          (
            Guid,
            MilestoneTypeId,
            SortOrder
          )
        SELECT
                NEWID(),
                jtmt.MilestoneTypeID,
                jtmt.SortOrder
        FROM
                SJob.JobTypeMilestoneTemplates AS jtmt
        JOIN
                SJob.JobTypes AS jt ON (jt.ID = jtmt.JobTypeID)
        JOIN
                SJob.Jobs AS j ON (j.JobTypeID = jt.ID)
        WHERE
                (j.ID = @JobID)
            AND (NOT EXISTS
                  (
                    SELECT  1
                    FROM    SJob.Milestones m
                    WHERE   (m.JobID = j.ID)
                        AND (m.MilestoneTypeID = jtmt.MilestoneTypeID)
						AND	(m.RowStatus NOT IN (0, 254))
                  )
                )
			AND	(jtmt.RowStatus NOT IN (0, 254))


    INSERT SCore.DataObjects
          (
            Guid,
            RowStatus,
            EntityTypeId
          )
        SELECT
                Guid,
                1,
                @JobMilestonesEntityTypeId
        FROM
                @MileStones

    INSERT SJob.Milestones
          (
            RowStatus,
            Guid,
            JobID,
            MilestoneTypeID,
            SortOrder
          )
        SELECT
                1,
                Guid,
                @JobID,
                MilestoneTypeId,
                SortOrder
        FROM
                @MileStones

  END;
GO
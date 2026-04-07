SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO




CREATE PROCEDURE [SJob].[MilestonesDelete]
  @Guid UNIQUEIDENTIFIER
AS
  BEGIN
    EXEC SCore.DeleteDataObject
      @Guid = @Guid;	-- uniqueidentifier


    UPDATE  SJob.Milestones
    SET     RowStatus = 254
    WHERE
      (Guid = @Guid);

    DECLARE @CorrectedOrder TABLE
        (
          ID        BIGINT,
          SortOrder INT
        );

    INSERT @CorrectedOrder
          (
            ID,
            SortOrder
          )
        SELECT
                m.ID,
                ROW_NUMBER() OVER (ORDER BY m.SortOrder)
        FROM
                SJob.Milestones m
        WHERE
                (EXISTS
                (
                    SELECT
                            1
                    FROM
                            SJob.Milestones m1
                    WHERE
                            (m1.Guid = @Guid)
                            AND (m.JobID = m1.JobID)
                )
                )
                AND (m.RowStatus NOT IN (0, 254));

    UPDATE  m
    SET     SortOrder = co.SortOrder
    FROM
            SJob.Milestones m
    JOIN
            @CorrectedOrder co ON (m.ID = co.ID);

  END;

GO
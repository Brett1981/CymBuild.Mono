SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO



CREATE PROCEDURE [SJob].[JobTypeMilestoneTemplatesDelete]
(
    @Guid UNIQUEIDENTIFIER
)
AS 
BEGIN 
	EXEC SCore.DeleteDataObject @Guid = @Guid	-- uniqueidentifier
	
	
    UPDATE  SJob.JobTypeMilestoneTemplates
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
                jtmt.ID,
                ROW_NUMBER() OVER (ORDER BY jtmt.SortOrder)
        FROM
                SJob.JobTypeMilestoneTemplates jtmt
        WHERE
                (EXISTS
                (
                    SELECT
                            1
                    FROM
                            SJob.JobTypeMilestoneTemplates jtmt1
                    WHERE
                            (jtmt1.Guid = @Guid)
                            AND (jtmt.JobTypeID = jtmt1.JobTypeID)
                )
                )
                AND (jtmt.RowStatus NOT IN (0, 254));

    UPDATE  jtmt
    SET     SortOrder = co.SortOrder
    FROM
            SJob.JobTypeMilestoneTemplates jtmt 
    JOIN
            @CorrectedOrder co ON (jtmt.ID = co.ID);

END
GO
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO


CREATE PROCEDURE [SJob].[JobTypeMilestoneTemplateUpsert]
  @JobTypeGuid       UNIQUEIDENTIFIER,
  @MilestoneTypeGuid UNIQUEIDENTIFIER,
  @Description       NVARCHAR(500),
  @SortOrder         INT,
  @Guid              UNIQUEIDENTIFIER OUT
AS
  BEGIN
    DECLARE @JobTypeID       INT,
            @MilestoneTypeID INT

    SELECT
            @JobTypeID = ID
    FROM
            SJob.JobTypes
    WHERE
            (Guid = @JobTypeGuid)

    SELECT
            @MilestoneTypeID = ID
    FROM
            SJob.MilestoneTypes
    WHERE
            (Guid = @MilestoneTypeGuid)

    DECLARE @IsInsert BIT
    EXEC SCore.UpsertDataObject
      @Guid       = @Guid,					-- uniqueidentifier
      @SchemeName = N'SJob',				-- nvarchar(255)
      @ObjectName = N'JobTypeMilestoneTemplates',				-- nvarchar(255)
      @IsInsert   = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
      BEGIN
        INSERT SJob.JobTypeMilestoneTemplates
              (
                RowStatus,
                Guid,
                JobTypeID,
                MilestoneTypeID,
                Description,
                SortOrder
              )
        VALUES
                (
                  1,	-- RowStatus - tinyint
                  @Guid,	-- Guid - uniqueidentifier
                  @JobTypeID,	-- JobTypeID - int
                  @MilestoneTypeID,	-- MilestoneTypeID - int
                  @Description,	-- Description - nvarchar(500)
                  @SortOrder	-- SortOrder - int
                )
      END;
    ELSE
      BEGIN
        UPDATE  SJob.JobTypeMilestoneTemplates
        SET     JobTypeID = @JobTypeID,
                MilestoneTypeID = @MilestoneTypeID,
                Description = @Description,
                SortOrder = @SortOrder
        WHERE
          (Guid = @Guid);
      END;

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
                ROW_NUMBER() OVER (ORDER BY CASE WHEN jtmt.Guid = @Guid THEN jtmt.SortOrder + 0.1 ELSE jtmt.SortOrder END)
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
  END;

GO
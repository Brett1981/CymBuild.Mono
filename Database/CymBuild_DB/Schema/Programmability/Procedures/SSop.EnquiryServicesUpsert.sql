SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SSop].[EnquiryServicesUpsert]
  (
    @EnquiryGuid        UNIQUEIDENTIFIER,
    @StartRibaStageGuid UNIQUEIDENTIFIER,
    @EndRibaStageGuid   UNIQUEIDENTIFIER,
    @JobTypeGuid        UNIQUEIDENTIFIER,
    @Guid               UNIQUEIDENTIFIER
  )
AS
  BEGIN
    DECLARE @EnquiryId        INT = -1,
            @StartRibaStageId INT = -1,
            @EndRibaStageId   INT = -1,
            @JobTypeId        INT = -1,
            @IsInsert         BIT;

    SELECT
            @EnquiryId = ID
    FROM
            SSop.Enquiries
    WHERE
            (Guid = @EnquiryGuid);

    SELECT
            @StartRibaStageId = ID
    FROM
            SJob.RibaStages
    WHERE
            (Guid = @StartRibaStageGuid);

    SELECT
            @EndRibaStageId = ID
    FROM
            SJob.RibaStages
    WHERE
            (Guid = @EndRibaStageGuid);

    SELECT
            @JobTypeId = ID
    FROM
            SJob.JobTypes
    WHERE
            (Guid = @JobTypeGuid)

    EXEC SCore.UpsertDataObject
      @Guid       = @Guid,					-- uniqueidentifier
      @SchemeName = N'SSop',				-- nvarchar(255)
      @ObjectName = N'EnquiryServices',				-- nvarchar(255)
	  @IncludeDefaultSecurity = 0,
      @IsInsert   = @IsInsert OUTPUT;	-- bit

    IF (@IsInsert = 1)
      BEGIN
        INSERT SSop.EnquiryServices
              (
                RowStatus,
                Guid,
                EnquiryId,
                JobTypeId,
                StartRibaStageId,
                EndRibaStageId
              )
        VALUES
                (
                  1,	-- RowStatus - tinyint
                  @Guid,	-- Guid - uniqueidentifier
                  @EnquiryId,	-- EnquiryId - int
                  @JobTypeId,	-- JobTypeId - int
                  @StartRibaStageId,	-- StartRibaStageId - int
                  @EndRibaStageId	-- EndRibaStageId - int
                )
      END;
    ELSE
      BEGIN
        UPDATE  SSop.EnquiryServices
        SET     EnquiryId = @EnquiryId,
                JobTypeId = @JobTypeId,
                StartRibaStageId = @StartRibaStageId,
                EndRibaStageId = @EndRibaStageId
        WHERE
          (Guid = @Guid);
      END;

  END;
GO
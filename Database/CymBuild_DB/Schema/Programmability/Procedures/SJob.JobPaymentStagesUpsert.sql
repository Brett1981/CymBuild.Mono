SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO



CREATE PROCEDURE [SJob].[JobPaymentStagesUpsert]
(
    @JobGuid UNIQUEIDENTIFIER,
	@StagedDate DATE,
    @AfterStageGuid UNIQUEIDENTIFIER,
	@Value DECIMAL(18,2),
    @Guid UNIQUEIDENTIFIER
)
AS 
BEGIN 
    DECLARE @AfterStageId INT,
            @JobID INT

    SELECT  @JobID = ID 
    FROM    SJob.Jobs 
    WHERE   ([Guid] = @JobGuid)

	SELECT	@AfterStageId = ID
	FROM	SJob.RibaStages rs 
	WHERE	([Guid] = @AfterStageGuid)

    DECLARE @IsInsert BIT
    EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
							@SchemeName = N'SJob',				-- nvarchar(255)
							@ObjectName = N'JobPaymentStages',				-- nvarchar(255)
							@IsInsert = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
    BEGIN
		INSERT	SJob.JobPaymentStages
			 (RowStatus, Guid, JobID, StagedDate, AfterStageId, Value)
		VALUES
			 (
				 1,	
				 @Guid,	
         @JobId, 
				 @StagedDate,
				 @AfterStageId,
				 @Value
			 )

    END
    ELSE
    BEGIN 
        UPDATE  SJob.JobPaymentStages
        SET     StagedDate = @StagedDate,
                AfterStageId = @AfterStageId,
				VALUE = @Value
        WHERE   ([Guid] = @Guid)
    END
END
GO
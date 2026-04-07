SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SFin].[TransactionDetailsUpsert]
(
    @TransactionGuid UNIQUEIDENTIFIER,
	@MilestoneGuid UNIQUEIDENTIFIER,
	@ActivityGuid UNIQUEIDENTIFIER,
	@Net DECIMAL(9,2),
	@Vat DECIMAL(9,2),
	@Gross DECIMAL(9,2),
	@VatRate DECIMAL(9,2),
	@Description nvarchar(2000),
	@JobPaymentStageGuid UNIQUEIDENTIFIER,
    @Guid UNIQUEIDENTIFIER,
	@RIBAStageGuid UNIQUEIDENTIFIER
)
AS 
BEGIN 
    DECLARE @TransactionID INT,
			@MilestoneID INT,
			@ActivityId INT,
			@JobPaymentStageId INT,
			@RIBAStageId INT;

    SELECT  @TransactionID = ID 
    FROM    SFin.Transactions
    WHERE   ([Guid] = @TransactionGuid)

	SELECT  @MilestoneID = ID 
	FROM    SJob.Milestones
	WHERE   ([Guid] = @MilestoneGuid)

	SELECT @RIBAStageId = ID
	FROM SJob.RibaStages
	WHERE ([Guid] = @RIBAStageGuid)

	SELECT  @ActivityId = ID 
	FROM    SJob.Activities
	WHERE   ([Guid] = @ActivityGuid)

	SELECT	@JobPaymentStageId = ID
	FROM	SJob.JobPaymentStages AS jps
	WHERE	([jps].[Guid] = @JobPaymentStageGuid)



	/* Check the values */
	IF (@Vat = 0)
	BEGIN 
		SET @Vat = @Net * (@VatRate / 100)
	END

	IF (@Gross = 0)
	BEGIN 
		SET @Gross = @Net + @Vat
	END

    DECLARE @IsInsert BIT
    EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
							@SchemeName = N'SFin',				-- nvarchar(255)
							@ObjectName = N'TransactionDetails',				-- nvarchar(255)
							@IsInsert = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
    BEGIN
		DECLARE	@JobNumber NVARCHAR(2000),
				@JobDescription NVARCHAR(2000),
				@JobType NVARCHAR(2000),
				@UprnFormattedAddressComma NVARCHAR(2000)

		SELECT	@JobNumber = j.Number,
				@JobDescription = j.JobDescription,
				@JobType = jt.Name,
				@UprnFormattedAddressComma = p.FormattedAddressComma
		FROM	SJob.Jobs j
		JOIN	SJob.JobTypes jt ON (jt.ID = j.JobTypeID)
		JOIN	SJob.Assets p ON (p.ID = j.UprnID)
		JOIN	SFin.Transactions t ON (t.JobID = j.ID)
		WHERE	(t.Guid = @TransactionGuid)
		
		IF (@@ROWCOUNT > 0) 
		BEGIN 
			SET @Description = @Description + N'	
Our project ref.: ' + @JobNumber + N'
Project description: ' + @JobDescription + N'
Property: ' + @UprnFormattedAddressComma + N'
Appointed role: ' + @JobType
		END

		SET @Description = REPLACE(@Description, CHAR(34), CHAR(39))

		INSERT SFin.TransactionDetails
			 (RowStatus, Guid, TransactionID, MilestoneID, ActivityID, net, vat, Gross, VatRate, Description, JobPaymentStageId, RIBAStageId)
		VALUES
			 (
				 1,	-- RowStatus - tinyint
				 @Guid,	-- Guid - uniqueidentifier
				 @TransactionID,
				 @MilestoneID, 
				 @ActivityId, 
				 @Net, 
				 @Vat,
				 @Gross, 
				 @VatRate, 
				 @Description,
				 @JobPaymentStageId,
				 @RIBAStageId
			 )
    END
    ELSE
    BEGIN 
        UPDATE  SFin.TransactionDetails
        SET     MilestoneID = @MilestoneID,
				ActivityID = @ActivityId,
				Net = @Net,
				Vat = @Vat,
				Gross = @Gross,
				VatRate = @VatRate,
				Description = @Description,
				JobPaymentStageId = @JobPaymentStageId,
				RIBAStageId = @RIBAStageId
        WHERE   ([Guid] = @Guid)
    END
END
GO
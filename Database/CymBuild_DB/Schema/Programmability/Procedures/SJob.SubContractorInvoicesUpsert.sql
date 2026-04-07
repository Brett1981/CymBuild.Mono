SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SJob].[SubContractorInvoicesUpsert]
	(	
		@Guid UNIQUEIDENTIFIER,
		@InvoiceNumber NVARCHAR(100),
		@InvoiceDate DATE,
		@DescriptionOfWork NVARCHAR(MAX),
		@SupportingComments NVARCHAR(MAX),
		@ActivityGuid UNIQUEIDENTIFIER,
		@MilestoneGuid UNIQUEIDENTIFIER,
		@ValueWithVAT DECIMAL(19,2),
		@ValueWithoutVAT DECIMAL(19,2),
		@SubContractorName NVARCHAR(100),
		@JobGuid UNIQUEIDENTIFIER
		
	)
AS
BEGIN
	DECLARE 
			@ActivityId		BIGINT,
			@MilestoneId	BIGINT,
			@JobId			INT,
			@IsInsert		BIT;


	SELECT @MilestoneId = ID
	FROM SJob.Milestones
	WHERE ([Guid] = @MilestoneGuid);

	SELECT @ActivityId = ID
	FROM SJob.Activities 
	WHERE ([Guid] = @ActivityGuid);

	SELECT @JobId = ID
	FROM SJob.Jobs
	WHERE ([Guid] = @JobGuid);

	

	EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
							@SchemeName = N'SJob',				-- nvarchar(255)
							@ObjectName = N'SubContractorInvoices',				-- nvarchar(255)
							@IncludeDefaultSecurity = 0,
							@IsInsert = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
	BEGIN
		INSERT	SJob.SubContractorInvoices
			 (
				RowStatus,
				Guid,
				InvoiceNumber,
				InvoiceDate,
				DescriptionOfWork,
				SupportingComments,
				ActivityId,
				MilestoneId,
				ValueWithVAT,
				ValueWithoutVAT,
				SubContractorName,
				JobId
			) 
		VALUES
			 (
				 1,								-- RowStatus - tinyint
				 @Guid,							-- Guid - uniqueidentifier
				 @InvoiceNumber,
				 @InvoiceDate,
				 @DescriptionOfWork,
				 @SupportingComments,
				 @ActivityId,
				 @MilestoneId,
				 @ValueWithVAT,
				 @ValueWithoutVAT,
				 @SubContractorName,
				 @JobId
			 );
	END;
	ELSE
	BEGIN
		UPDATE	SJob.SubContractorInvoices
		SET		
				InvoiceNumber = @InvoiceNumber,
				InvoiceDate = @InvoiceDate,
				DescriptionOfWork = @DescriptionOfWork,
				SupportingComments = @SupportingComments,
				ActivityId = @ActivityId,
				MilestoneId = @MilestoneId,
				ValueWithVAT = @ValueWithVAT,
				ValueWithoutVAT = @ValueWithoutVAT,
				SubContractorName = @SubContractorName,
				JobId = @JobId
		WHERE	(Guid = @Guid);
	END;


END;
GO
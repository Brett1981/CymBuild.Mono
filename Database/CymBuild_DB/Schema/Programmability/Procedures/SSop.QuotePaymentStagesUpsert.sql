SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO






CREATE PROCEDURE [SSop].[QuotePaymentStagesUpsert]
	(
		@QuoteGuid				  UNIQUEIDENTIFIER,
		@PaymentFrequencyTypeGuid UNIQUEIDENTIFIER,
		@PaymentFrequency		  INT,
		@Value					  DECIMAL(18, 2),
		@PercentageOfTotal		  DECIMAL(5, 2),
		@PayAfterStageGuid		  UNIQUEIDENTIFIER,
		@Guid					  UNIQUEIDENTIFIER
	)
AS
	BEGIN
		DECLARE @QuoteId				INT,
				@PaymentFrequencyTypeId INT,
				@PayAfterStageId		INT,
				@IsInsert				BIT;

		SELECT
				@QuoteId = ID
		FROM
				SSop.Quotes
		WHERE
				([Guid] = @QuoteGuid)

		SELECT
				@PaymentFrequencyTypeId = ID
		FROM
				SFin.PaymentFrequencyTypes pft
		WHERE
				([Guid] = @PaymentFrequencyTypeGuid)

		SELECT
				@PayAfterStageId = ID
		FROM
				SJob.RibaStages rs
		WHERE
				([Guid] = @PayAfterStageGuid)

		EXEC SCore.UpsertDataObject
			@Guid		= @Guid,					-- uniqueidentifier
			@SchemeName = N'SSop',				-- nvarchar(255)
			@ObjectName = N'QuotePaymentStages',				-- nvarchar(255)
			@IsInsert   = @IsInsert OUTPUT	-- bit

		IF (@IsInsert = 1)
			BEGIN
				INSERT SSop.QuotePaymentStages
						(
							RowStatus,
							Guid,
							QuoteId,
							PaymentFrequencyTypeId,
							PaymentFrequency,
							Value,
							PercentageOfTotal,
							PayAfterStageId
						)
				VALUES
						(
							1,	-- RowStatus - tinyint
							@Guid,	-- Guid - uniqueidentifier
							@QuoteId,	-- QuoteId - int
							@PaymentFrequencyTypeId,
							@PaymentFrequency,
							@Value,
							@PercentageOfTotal,
							@PayAfterStageId
						)
			END
		ELSE
			BEGIN
				UPDATE  SSop.QuotePaymentStages
				SET		QuoteId = @QuoteId,
						PaymentFrequencyTypeId = @PaymentFrequencyTypeId,
						PaymentFrequency = @PaymentFrequency,
						Value = @Value,
						PercentageOfTotal = @PercentageOfTotal,
						PayAfterStageId = @PayAfterStageId
				WHERE
					([Guid] = @Guid)
			END
	END
GO
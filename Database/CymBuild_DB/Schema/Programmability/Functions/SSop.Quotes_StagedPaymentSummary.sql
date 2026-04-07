SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SSop].[Quotes_StagedPaymentSummary]
	(
		@Guid UNIQUEIDENTIFIER
	)
RETURNS @JobPaymentStages TABLE
	(
		Id						 INT IDENTITY (1, 1),
		JobId					 INT,
		RowStatus				 TINYINT,
		Guid					 UNIQUEIDENTIFIER,
		StagedDate				 DATE,
		AfterStageId			 INT,
		Value					 DECIMAL(19, 2),
		InstanceId				 INT,
		PaymentFrequencyTypeID	 INT,
		PaymentFrequencyTypeName NVARCHAR(50),
		PayAfterStageName		 NVARCHAR(500)
	)
AS
	BEGIN
		DECLARE @QuoteTotal					  DECIMAL(19, 2),
				@FractionOfQuote			  DECIMAL(5, 4),
				@CurrentStage				  INT,
				@MaxStage					  INT,
				@StageValue					  DECIMAL(19, 2),
				@PaymentFrequencyType		  NVARCHAR(50),
				@PaymentFrequency			  INT,
				@PayAfterStageId			  INT,
				@PayAfterStageNumber		  INT,
				@PayAfterStageName			  NVARCHAR(100),
				@StagesToCreate				  INT,
				@RemainingFee				  DECIMAL(19, 2),
				@PercentageOfTotal			  DECIMAL(5, 2),
				@PreviousPageAfterStageNumber INT,
				@RibaStage1Fee				  DECIMAL(19, 2),
				@RibaStage2Fee				  DECIMAL(19, 2),
				@RibaStage3Fee				  DECIMAL(19, 2),
				@RibaStage4Fee				  DECIMAL(19, 2),
				@RibaStage5Fee				  DECIMAL(19, 2),
				@RibaStage6Fee				  DECIMAL(19, 2),
				@RibaStage7Fee				  DECIMAL(19, 2),
				@PreConstructionStageFee	  DECIMAL(19, 2),
				@ConstructionStageFee		  DECIMAL(19, 2),
				@RibaStage0FeePaid				DECIMAL(19,2),
				@RibaStage1FeePaid			  DECIMAL(19, 2),
				@RibaStage2FeePaid			  DECIMAL(19, 2),
				@RibaStage3FeePaid			  DECIMAL(19, 2),
				@RibaStage4FeePaid			  DECIMAL(19, 2),
				@RibaStage5FeePaid			  DECIMAL(19, 2),
				@RibaStage6FeePaid			  DECIMAL(19, 2),
				@RibaStage7FeePaid			  DECIMAL(19, 2),
				@PreConstructionStageFeePaid  DECIMAL(19, 2),
				@ConstructionStageFeePaid	  DECIMAL(19, 2),
				@TotalStageValue			  DECIMAL(19, 2),
				@StagePartValue				  DECIMAL(19, 2),
				@StageValueUsed				  DECIMAL(19, 2),
				@PaymentFrequencyTypeID		  INT,
				@CurrentFrequency			  INT,
				@ThisJobTotal				  DECIMAL(19, 2),
				@PaymentDate				  DATE,
				@JobPaymentStageValue		  DECIMAL(19, 2);

		DECLARE @QuotePaymentStages TABLE
				(
					ID					   INT			  IDENTITY (1, 1),
					PayAfterStageId		   INT			  NOT NULL DEFAULT ((-1)),
					PaymentFrequency	   INT			  NOT NULL DEFAULT ((1)),
					PaymentFrequencyType   NVARCHAR(50)	  NOT NULL DEFAULT '',
					PaymentFrequencyTypeId INT			  NOT NULL DEFAULT ((-1)),
					Value				   DECIMAL(19, 2) DEFAULT ((0)),
					PayAfterStageNumber	   INT			  NOT NULL DEFAULT ((0)),
					PercentageOfTotal	   DECIMAL(5, 2)  NOT NULL DEFAULT ((0)),
					PayAfterStageName	   NVARCHAR(500)  NOT NULL DEFAULT ''
				);

		DECLARE @StageValues TABLE
				(
					ID			INT IDENTITY (1, 1),
					StageNumber INT,
					Value		DECIMAL(19, 2)
				);

		SELECT
				@QuoteTotal = SUM(qjs.AgreedFee)
		FROM
				SSop.Quote_JobsSummary qjs
		WHERE
				(qjs.QuoteGuid = @Guid);


		INSERT @QuotePaymentStages
				(
					PayAfterStageId,
					PaymentFrequency,
					PaymentFrequencyType,
					PaymentFrequencyTypeId,
					Value,
					PayAfterStageNumber,
					PercentageOfTotal,
					PayAfterStageName
				)
			SELECT
					qps.PayAfterStageId,
					qps.PaymentFrequency,
					pft.Name,
					qps.PaymentFrequencyTypeId,
					qps.Value,
					rs.Number,
					qps.PercentageOfTotal,
					rs.Description
			FROM
					SSop.QuotePaymentStages qps
			JOIN	
					SSop.Quotes q ON (q.ID = qps.QuoteId)
			JOIN
					SFin.PaymentFrequencyTypes pft ON qps.PaymentFrequencyTypeId = pft.ID
			JOIN
					SJob.RibaStages rs ON qps.PayAfterStageId = rs.ID
			WHERE
					(q.Guid = @Guid)
			ORDER BY
					CASE
							WHEN rs.Number > -1 THEN
								rs.Number
							ELSE
							99999 + qps.ID
					END

		DECLARE @MaxJob		INT,
				@CurrentJob INT = -1

		SELECT
				@MaxJob = MAX(ID)
		FROM
				SSop.Quote_JobsSummary qjs
		WHERE
				(qjs.QuoteGuid = @Guid)

		WHILE (@CurrentJob < @MaxJob)
		BEGIN
			SELECT TOP (1)
					@CurrentJob					 = ID,
					@RibaStage1Fee				 = qjs.RibaStage1Fee,
					@RibaStage2Fee				 = qjs.RibaStage2Fee,
					@RibaStage3Fee				 = qjs.RibaStage3Fee,
					@RibaStage4Fee				 = qjs.RibaStage4Fee,
					@RibaStage5Fee				 = qjs.RibaStage5Fee,
					@RibaStage6Fee				 = qjs.RibaStage6Fee,
					@RibaStage7Fee				 = qjs.RibaStage7Fee,
					@RibaStage0FeePaid			 = 0,
					@RibaStage1FeePaid			 = 0,
					@RibaStage2FeePaid			 = 0,
					@RibaStage3FeePaid			 = 0,
					@RibaStage4FeePaid			 = 0,
					@RibaStage5FeePaid			 = 0,
					@RibaStage6FeePaid			 = 0,
					@RibaStage7FeePaid			 = 0,
					@PreConstructionStageFeePaid = 0,
					@ConstructionStageFeePaid	 = 0,
					@ConstructionStageFee		 = qjs.ConstructionStageFee,
					@PreConstructionStageFee	 = qjs.PreConstructionStageFee,
					@ThisJobTotal				 = qjs.RibaStage1Fee + qjs.RibaStage2Fee + qjs.RibaStage3Fee + qjs.RibaStage4Fee + qjs.RibaStage5Fee + qjs.RibaStage6Fee + qjs.RibaStage7Fee + qjs.PreConstructionStageFee + qjs.ConstructionStageFee,
					@FractionOfQuote			 = (qjs.RibaStage1Fee + qjs.RibaStage2Fee + qjs.RibaStage3Fee + qjs.RibaStage4Fee + qjs.RibaStage5Fee + qjs.RibaStage6Fee + qjs.RibaStage7Fee + qjs.PreConstructionStageFee + qjs.ConstructionStageFee) / @QuoteTotal
			FROM
					SSop.Quote_JobsSummary qjs
			WHERE
					(qjs.QuoteGuid = @Guid)
					AND (ID > @CurrentJob)
			ORDER BY
					ID

			-- Build the payment stages
			SELECT
					@MaxStage	  = MAX(ID),
					@CurrentStage = -1
			FROM
					@QuotePaymentStages

			SET @PaymentDate = GETDATE();

			WHILE (@CurrentStage < @MaxStage)
			BEGIN
				SELECT TOP (1)
						@CurrentStage			= ID,
						@StageValue				= Value,
						@PayAfterStageId		= PayAfterStageId,
						@PayAfterStageNumber	= PayAfterStageNumber,
						@PaymentFrequency		= PaymentFrequency,
						@PaymentFrequencyType   = PaymentFrequencyType,
						@PaymentFrequencyTypeID = PaymentFrequencyTypeId,
						@PercentageOfTotal		= PercentageOfTotal,
						@PayAfterStageName		= PayAfterStageName
				FROM
						@QuotePaymentStages
				WHERE
						(ID > @CurrentStage)
				ORDER BY
						ID

				IF (@PayAfterStageId > 0)
					BEGIN
						IF (@StageValue > 0)
							BEGIN
								SET @TotalStageValue = @StageValue * @FractionOfQuote
							END
						ELSE
						IF (@PercentageOfTotal > 0)
							BEGIN
								SET @TotalStageValue = @ThisJobTotal * (@PercentageOfTotal / 100)
							END
						ELSE
							BEGIN
								DELETE FROM
								@StageValues;

								INSERT @StageValues
										(
											StageNumber,
											Value
										)
								VALUES
									(
										0,
										0 - @RibaStage0FeePaid
									),
									(
										1,
										@RibaStage1Fee - @RibaStage1FeePaid
									),
									(
										2,
										@RibaStage2Fee - @RibaStage2FeePaid
									),
									(
										3,
										@RibaStage3Fee - @RibaStage3FeePaid
									),
									(
										4,
										@RibaStage4Fee - @RibaStage4FeePaid
									),
									(
										5,
										@RibaStage5Fee - @RibaStage5FeePaid
									),
									(
										6,
										@RibaStage6Fee - @RibaStage6FeePaid
									),
									(
										7,
										@RibaStage7Fee - @RibaStage7FeePaid
									),
									(
										99,
										@PreConstructionStageFee - @PreConstructionStageFeePaid
									),
									(
										999,
										@ConstructionStageFee - @ConstructionStageFeePaid
									)


								SELECT
										@TotalStageValue = SUM(Value)
								FROM
										@StageValues
								WHERE
										(StageNumber <= @PayAfterStageNumber)
							END
					END
				ELSE
				IF (@StageValue > 0)
					BEGIN
						SET @TotalStageValue = @StageValue * @FractionOfQuote
					END
				ELSE
				IF (@PercentageOfTotal > 0)
					BEGIN
						SET @TotalStageValue = @ThisJobTotal * (@PercentageOfTotal / 100)
					END
				ELSE
					BEGIN
						SET @TotalStageValue = @ThisJobTotal
					END

				SET @CurrentFrequency = 0
				SET @StagePartValue = @TotalStageValue / @PaymentFrequency
				SET @RemainingFee = @TotalStageValue
				SET @PreviousPageAfterStageNumber = @PayAfterStageNumber

				WHILE (@CurrentFrequency < @PaymentFrequency)
				BEGIN
					SET @CurrentFrequency = @CurrentFrequency + 1
					SET @PaymentDate = CASE @PaymentFrequencyType
											  WHEN N'Monthly' THEN
												  DATEADD(MONTH, 1, @PaymentDate)
											  WHEN N'Weekly' THEN
												  DATEADD(WEEK, 1, @PaymentDate)
											  WHEN N'Yearly' THEN
												  DATEADD(YEAR, 1, @PaymentDate)
											  WHEN N'Quarterly' THEN
												  DATEADD(QUARTER, 1, @PaymentDate)
											  ELSE
											  DATEADD(DAY, 1, @PaymentDate)
									  END

					SET @JobPaymentStageValue = CASE
													   WHEN @StagePartValue < @RemainingFee THEN
														   @StagePartValue
													   ELSE
													   @RemainingFee
											   END

					INSERT @JobPaymentStages
							(
								JobId,
								Guid,
								RowStatus,
								StagedDate,
								AfterStageId,
								Value,
								InstanceId,
								PaymentFrequencyTypeId,
								PaymentFrequencyTypeName,
								PayAfterStageName
							)
					VALUES
							(
								@CurrentJob,
								(
									SELECT
											Guid
									FROM
											SCore.NewGuid
								),
								1,
								@PaymentDate,
								@PayAfterStageId,
								@JobPaymentStageValue,
								@CurrentFrequency,
								@PaymentFrequencyTypeID,
								@PaymentFrequencyType,
								@PayAfterStageName
							);

					SET @RemainingFee = @RemainingFee - @JobPaymentStageValue

					IF (@PayAfterStageNumber = 1)
						BEGIN
							SET @RibaStage1FeePaid = @RibaStage1FeePaid + @JobPaymentStageValue
						END
					ELSE
					IF (@PayAfterStageNumber = 2)
						BEGIN
							SET @RibaStage2FeePaid = @RibaStage2FeePaid + @JobPaymentStageValue
						END
					ELSE
					IF (@PayAfterStageNumber = 3)
						BEGIN
							SET @RibaStage2FeePaid = @RibaStage3FeePaid + @JobPaymentStageValue
						END
					ELSE
					IF (@PayAfterStageNumber = 4)
						BEGIN
							SET @RibaStage4FeePaid = @RibaStage4FeePaid + @JobPaymentStageValue
						END
					ELSE
					IF (@PayAfterStageNumber = 5)
						BEGIN
							SET @RibaStage5FeePaid = @RibaStage5FeePaid + @JobPaymentStageValue
						END
					ELSE
					IF (@PayAfterStageNumber = 6)
						BEGIN
							SET @RibaStage6FeePaid = @RibaStage6FeePaid + @JobPaymentStageValue
						END
					ELSE
					IF (@PayAfterStageNumber = 7)
						BEGIN
							SET @RibaStage7FeePaid = @RibaStage7FeePaid + @JobPaymentStageValue
						END
					ELSE
					IF (@PayAfterStageNumber = 99)
						BEGIN
							SET @PreConstructionStageFeePaid = @PreConstructionStageFeePaid + @JobPaymentStageValue
						END
					ELSE
					IF (@PayAfterStageNumber = 999)
						BEGIN
							SET @ConstructionStageFeePaid = @ConstructionStageFeePaid + @JobPaymentStageValue
						END
				END
			END
		END;

		RETURN
	END
GO
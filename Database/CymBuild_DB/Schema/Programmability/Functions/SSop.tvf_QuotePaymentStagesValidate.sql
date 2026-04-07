SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO



CREATE FUNCTION [SSop].[tvf_QuotePaymentStagesValidate]
	(
		@PaymentFrequencyTypeGuid UNIQUEIDENTIFIER,
		@PaymentFrequency int,
		@Value DECIMAL (18,2),
		@PercentageOfTotal DECIMAL(5,2),
		@Guid UNIQUEIDENTIFIER
	)
RETURNS @ValidationResult TABLE
	(
		ID INT IDENTITY(1, 1) NOT NULL,
		TargetGuid UNIQUEIDENTIFIER NOT NULL DEFAULT ('00000000-0000-0000-0000-000000000000'),
		TargetType CHAR(1) NOT NULL DEFAULT (''),
		IsReadOnly BIT NOT NULL DEFAULT ((0)),
		IsHidden BIT NOT NULL DEFAULT ((0)),
		IsInvalid BIT NOT NULL DEFAULT ((0)),
		[IsInformationOnly] [BIT] NOT NULL DEFAULT((0)),
		Message NVARCHAR(2000) NOT NULL DEFAULT ('')
	)
AS
BEGIN

	IF (@Value <> 0)
			BEGIN

				INSERT @ValidationResult
						(
							TargetGuid,
							TargetType,
							IsReadOnly,
							IsHidden,
							IsInvalid,
							[Message]
						)
				SELECT
							epfvv.Guid,
							N'P',
							1,
							0,
							0,
							N''
				FROM	SCore.EntityPropertiesForValidationV AS epfvv
				WHERE	([epfvv].[Schema] = N'SSop')
					AND	(epfvv.Hobt = N'QuotePaymentStages')
					AND	(Name = (N'PercentageOfTotal'))		
			
			END

	IF (@PercentageOfTotal <> 0)
			BEGIN

				INSERT @ValidationResult
						(
							TargetGuid,
							TargetType,
							IsReadOnly,
							IsHidden,
							IsInvalid,
							[Message]
						)
				SELECT
							epfvv.Guid,
							N'P',
							1,
							0,
							0,
							N''
				FROM	SCore.EntityPropertiesForValidationV AS epfvv
				WHERE	([epfvv].[Schema] = N'SSop')
					AND	(epfvv.Hobt = N'QuotePaymentStages')
					AND	(Name = (N'Value'))		
			
			END
   

	IF (@PaymentFrequencyTypeGuid = '00000000-0000-0000-0000-000000000000')
			BEGIN

				INSERT @ValidationResult
						(
							TargetGuid,
							TargetType,
							IsReadOnly,
							IsHidden,
							IsInvalid,
							[Message]
						)
				SELECT
							epfvv.Guid,
							N'P',
							1,
							1,
							0,
							N''
				FROM	SCore.EntityPropertiesForValidationV AS epfvv
				WHERE	([epfvv].[Schema] = N'SSop')
					AND	(epfvv.Hobt = N'QuotePaymentStages')
					AND	(Name = (N'PaymentFrequency'))
								
			
			END
		ELSE IF (@PaymentFrequency < 1)
		BEGIN 
			INSERT @ValidationResult
						(
							TargetGuid,
							TargetType,
							IsReadOnly,
							IsHidden,
							IsInvalid,
							[Message]
						)
				SELECT
							epfvv.Guid,
							N'P',
							0,
							0,
							1,
							N'The Payment Frequency must be greater than 0.'
				FROM	SCore.EntityPropertiesForValidationV AS epfvv
				WHERE	([epfvv].[Schema] = N'SSop')
					AND	(epfvv.Hobt = N'QuotePaymentStages')
					AND	(Name = (N'PaymentFrequency'))
		END

	RETURN;
END;

GO
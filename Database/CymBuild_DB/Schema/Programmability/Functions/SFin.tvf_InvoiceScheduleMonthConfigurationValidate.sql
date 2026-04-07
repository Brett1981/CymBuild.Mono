SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE FUNCTION [SFin].[tvf_InvoiceScheduleMonthConfigurationValidate]
	(
		@Guid								UNIQUEIDENTIFIER,
		@OnDayOfMonth						DATE,
		@PeriodNumber						INT,
		@Amount								DECIMAL(19,2),
		@InvoiceScheduleGuid				UNIQUEIDENTIFIER
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
	DECLARE 
			@TriggerName NVARCHAR(100) = N'',
			@InvoiceScheduleId INT;


	SELECT @InvoiceScheduleId = ID
	FROM SFin.InvoiceSchedules
	WHERE ([Guid] = @InvoiceScheduleGuid)



	--Check if the user is trying to add the same period again.
	IF(EXISTS
			(
				SELECT 1 
				FROM SFin.InvoiceScheduleMonthConfiguration
				WHERE 
						([InvoiceScheduleId] = @InvoiceScheduleId)
					AND ([Guid] <> @Guid)
					AND ([PeriodNumber] = @PeriodNumber)
					AND ([RowStatus] NOT IN (0,254))


			)
		)
		INSERT	@ValidationResult
				(TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		SELECT	epfvv.Guid,
				N'P',
				0,
				0,
				1,
				N'Period has already been defined!'
		FROM	SCore.EntityPropertiesForValidationV AS epfvv
		WHERE	epfvv.[Schema]	= N'SFin'
			AND epfvv.Hobt		= N'InvoiceScheduleMonthConfiguration'
			AND epfvv.Name		= N'PeriodNumber'


	--Period must be between 1 & 12
	IF(@PeriodNumber < 1 OR @PeriodNumber > 12)
		INSERT	@ValidationResult
				(TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		SELECT	epfvv.Guid,
				N'P',
				0,
				0,
				1,
				N'Period must be between 1 & 12.'
		FROM	SCore.EntityPropertiesForValidationV AS epfvv
		WHERE	epfvv.[Schema]	= N'SFin'
			AND epfvv.Hobt		= N'InvoiceScheduleMonthConfiguration'
			AND epfvv.Name		= N'PeriodNumber'
			


	

		
 
	RETURN;
END;

GO
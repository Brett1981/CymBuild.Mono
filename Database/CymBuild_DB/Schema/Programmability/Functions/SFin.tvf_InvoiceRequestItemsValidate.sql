SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE FUNCTION [SFin].[tvf_InvoiceRequestItemsValidate]
(
    @Guid				UNIQUEIDENTIFIER,
	@MilestoneGuid		UNIQUEIDENTIFIER,
	@ActivityGuid		UNIQUEIDENTIFIER,
	@RibaStageGuid		UNIQUEIDENTIFIER,
	@Net				DECIMAL
)
RETURNS @ValidationResult TABLE
(
    ID INT IDENTITY(1, 1) NOT NULL,
    TargetGuid UNIQUEIDENTIFIER NOT NULL DEFAULT ('00000000-0000-0000-0000-000000000000'),
    TargetType CHAR(1) NOT NULL DEFAULT (''),
    IsReadOnly BIT NOT NULL DEFAULT ((0)),
    IsHidden BIT NOT NULL DEFAULT ((0)),
    IsInvalid BIT NOT NULL DEFAULT ((0)),
    [IsInformationOnly] [BIT] NOT NULL DEFAULT ((0)),
    Message NVARCHAR(2000) NOT NULL DEFAULT ('')
)
AS
BEGIN

	DECLARE 
			@EmptyGuid UNIQUEIDENTIFIER = N'00000000-0000-0000-0000-000000000000',
			@MilestoneSelected	BIT = 0,
			@ActivitySelected	BIT = 0;

    
	DECLARE 
			@ActivityID		INT,
			@MilestoneID	INT,
			@ActivityNet	DECIMAL(19,2),
			@MilestoneNet	DECIMAL(19,2);


		/*
			Check if a milestone has been selected (first save check only).
		*/
		IF( NOT EXISTS(
						SELECT 1 
						FROM SFin.InvoiceRequestItems 
						WHERE Guid = @Guid
					) AND (@MilestoneGuid <> @EmptyGuid) 
			)
			SET @MilestoneSelected = 1;

		/*
			Check if an activity has been selected (first save check only).
		*/
		IF( NOT EXISTS(
						SELECT 1 
						FROM SFin.InvoiceRequestItems 
						WHERE Guid = @Guid
				) AND (@ActivityGuid <> @EmptyGuid)
			)
			SET @ActivitySelected = 1;




		/*
			Set the "Net" field read-only (on the first save)
			when an activity or milestone is selected.

			Both of these values should be sourced from their respective record types.
		*/
		IF((@MilestoneSelected = 1) OR (@ActivitySelected = 1))
			BEGIN
				 INSERT @ValidationResult
					(TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
				SELECT
					epfvv.Guid,
					N'P',
					1,
					0,
					0,
					N''
				FROM SCore.EntityPropertiesForValidationV AS epfvv
				WHERE epfvv.[Schema] = N'SFin'
				  AND epfvv.Hobt = N'InvoiceRequestItems'
				  AND epfvv.Name IN (N'Net');
			END;




			

    RETURN;
END;
GO
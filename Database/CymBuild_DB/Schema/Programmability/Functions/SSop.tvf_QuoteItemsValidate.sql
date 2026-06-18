SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SSop].[tvf_QuoteItemsValidate]')
GO
CREATE FUNCTION [SSop].[tvf_QuoteItemsValidate]
	(
		@CreatedJobGuid			UNIQUEIDENTIFIER,
		@Guid					UNIQUEIDENTIFIER,
		@InvoicingScheduleGuid	UNIQUEIDENTIFIER,
		@QuoteGuid				UNIQUEIDENTIFIER,
		@DoNotConsolidate		BIT
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

	DECLARE @QuoteId INT;

	SELECT @QuoteId = ID
	FROM SSop.Quotes 
	WHERE Guid = @QuoteGuid;

	DECLARE @ReopenedStatus UNIQUEIDENTIFIER = '34EF363A-C8F7-4BA8-A2C6-067EBAEF12FD';
	DECLARE @CompletedStatus UNIQUEIDENTIFIER = '6042639D-EF8A-4B6F-9182-A69A7119C117';
	DECLARE @PartCompletedStatus UNIQUEIDENTIFIER = '286A39A3-E965-4C54-926C-3B272E6D8165';

	DECLARE @CurrentQuoteStatus UNIQUEIDENTIFIER;
	DECLARE @IsQuoteReopened BIT = 0;


	SELECT TOP(1) @CurrentQuoteStatus = wfs.Guid
	FROM SCore.DataObjectTransition dot
	JOIN SCore.WorkflowStatus AS wfs ON (wfs.ID = dot.StatusID)
	WHERE 
			(dot.DataObjectGuid = @QuoteGuid)
		AND (dot.RowStatus NOT IN (0,254))
	ORDER BY dot.ID DESC;


	IF(@CreatedJobGuid <> N'00000000-0000-0000-0000-000000000000' AND @CurrentQuoteStatus = @CompletedStatus )
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
					AND	(epfvv.Hobt = N'QuoteItems')
					

	END;
	
	--Only allow certain fields to be edited for quote items where: there is a job & quote has been reopened. 
	IF(@CreatedJobGuid <> '00000000-0000-0000-0000-000000000000' AND @CurrentQuoteStatus = @ReopenedStatus)
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
					AND	(epfvv.Hobt = N'QuoteItems')
					AND	(epfvv.Name NOT IN (N'SortOrder', N'Details'))

	END;

	--Hide the "Invoicing Schedule field until the record is saved for the first time"
	IF(NOT EXISTS(SELECT 1 FROM SSop.QuoteItems WHERE Guid = @Guid))
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
							1,
							0,
							N''
				FROM	SCore.EntityPropertiesForValidationV AS epfvv
				WHERE	([epfvv].[Schema] = N'SSop')
					AND	(epfvv.Hobt = N'QuoteItems')
					AND	(epfvv.Name = (N'InvoicingSchedule'))
		END;


	-- Prevent changing the Quote Item if the Enquiry is no set as ready for quote review. 
	-- This would be the case if the enquiry had been duplicated. 
	IF (EXISTS
	 (
		 SELECT 1
		 FROM	SSop.QuoteItems AS qi
		 JOIN	SSop.Quotes			 AS q ON (q.ID = qi.QuoteId)
		 JOIN	SSop.EnquiryServices AS es ON (es.ID = q.EnquiryServiceID)
		 JOIN	SSop.Enquiries		 AS e ON (e.ID	 = es.EnquiryId)
		 WHERE	(qi.Guid					 = @Guid)
			AND (e.IsReadyForQuoteReview = 0)
	 )
	   )
	BEGIN
		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		SELECT
				 ep.Guid,
				 N'P',
				 1,
				 0,
				 0,
				 N''
		FROM	SCore.EntityProperties AS ep
		JOIN	SCore.EntityHobts AS eh ON (eh.ID = ep.EntityHoBTID)
		JOIN	SCore.EntityTypes AS et ON (et.ID = eh.EntityTypeID)
		WHERE	(et.Name = N'QuoteItems')

		RETURN;
	END;



    IF (EXISTS 
			(
				SELECT	1
				FROM	SSop.QuoteItems qi 
				JOIN	SSop.Quotes q ON (q.ID = qi.QuoteId)
				WHERE	(qi.CreatedJobId > 0)
					AND	(qi.Guid = @Guid)
					AND	((q.IsFinal = 1)
					OR	(q.DateSent IS NOT NULL))
			)	
	)
    BEGIN 
        DECLARE @EntityTypeGuid UNIQUEIDENTIFIER = '6474b796-c20d-4947-9406-ae1b6dffef32'

        INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, [Message])
        VALUES (@EntityTypeGuid, N'E', 1, 0, 0, N'')
    END

	IF (@CreatedJobGuid = '00000000-0000-0000-0000-000000000000')
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
					AND	(epfvv.Hobt = N'QuoteItems')
					AND	(Name = (N'CreatedJobId'))
			END

	

	RETURN;
END;

GO
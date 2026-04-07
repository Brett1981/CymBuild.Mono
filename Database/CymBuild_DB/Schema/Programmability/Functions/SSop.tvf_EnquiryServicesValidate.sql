SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SSop].[tvf_EnquiryServicesValidate]
	(
		@QuoteGuid UNIQUEIDENTIFIER,
		@Guid UNIQUEIDENTIFIER,
		@DeclinedToQuoteDate DATE
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
	DECLARE @TargetGuid UNIQUEIDENTIFIER

	

    IF (@QuoteGuid = '00000000-0000-0000-0000-000000000000')
    BEGIN 
		INSERT @ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, IsInformationOnly, Message)
		SELECT
				 epfvv.Guid,	-- TargetGuid - uniqueidentifier
				 'P',	-- TargetType - char(1)
				 1,	-- IsReadOnly - bit
				 1,	-- IsHidden - bit
				 0,	-- IsInvalid - bit
				 0,	-- IsInformationOnly - bit
				 N''	-- Message - nvarchar(2000)
		FROM	SCore.EntityPropertiesForValidationV AS epfvv
		WHERE	(epfvv.[Schema] = N'SSop')
			AND	(epfvv.Hobt = N'EnquiryService_ExtendedInfo')
			AND	(epfvv.Name = N'QuoteID')

		SELECT	@TargetGuid = epg.Guid
		FROM	SCore.EntityPropertyGroups AS epg
		JOIN	SCore.EntityTypes AS et ON (et.ID = epg.EntityTypeID)
		WHERE	(et.Name = N'Enquiry Services')
			AND	(epg.Name = N'Quote Information')

		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, IsInformationOnly, Message)
		VALUES
			 (
				 @TargetGuid,	-- TargetGuid - uniqueidentifier
				 'G',	-- TargetType - char(1)
				 0,	-- IsReadOnly - bit
				 1,	-- IsHidden - bit
				 0,	-- IsInvalid - bit
				 0,	-- IsInformationOnly - bit
				 N''	-- Message - nvarchar(2000)
			 )
    END
	RETURN;
END;

GO
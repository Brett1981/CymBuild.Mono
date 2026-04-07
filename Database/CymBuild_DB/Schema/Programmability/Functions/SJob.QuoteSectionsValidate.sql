SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO


CREATE FUNCTION [SJob].[QuoteSectionsValidate]
	(
		@QuoteGuid UNIQUEIDENTIFIER,
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
    IF (EXISTS 
			(
				SELECT	1
				FROM	SSop.QuoteItems qi 
				JOIN	SSop.QuoteSections qs ON (qs.Id = qi.QuoteSectionId)
				JOIN	SSop.Quotes q ON (q.ID = qs.QuoteId)
				WHERE	(qi.CreatedJobId > 0)
					AND	(q.Guid = @QuoteGuid)
					AND	(q.DateAccepted IS NOT NULL)
			)	
	)
    BEGIN 
        DECLARE @EntityTypeGuid UNIQUEIDENTIFIER = 'd9c04600-46cc-4bc9-acc1-18a850c9e18a'

        INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, [Message])
        VALUES (@EntityTypeGuid, N'E', 1, 0, 0, N'')
    END

	RETURN;
END;

GO
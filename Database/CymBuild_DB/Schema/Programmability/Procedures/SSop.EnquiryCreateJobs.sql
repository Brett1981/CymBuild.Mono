SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE PROCEDURE [SSop].[EnquiryCreateJobs]
	(@Guid UNIQUEIDENTIFIER)
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @Quotes SCore.GuidUniqueList,
			@MaxGuid UNIQUEIDENTIFIER,
			@CurrentGuid UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000000'

	INSERT	@Quotes
		 (GuidValue)
	SELECT	q.Guid
	FROM	SSop.Enquiries AS e 
	JOIN	SSop.EnquiryServices AS es ON (es.EnquiryId = e.ID)
	JOIN	SSop.EnquiryService_ExtendedInfo AS esei ON (esei.Id = es.ID)
	JOIN	SSop.Quotes AS q ON (q.Id = esei.QuoteID)
	WHERE	(q.DateAccepted IS NOT NULL)
		AND	(e.Guid = @Guid)

	IF (@@ROWCOUNT < 1)
	BEGIN 
		;THROW 60000, N'There are no accepted Quotes on this Enquiry that have Jobs to create.', 1;
	END

	SELECT	@MaxGuid = MAX(GuidValue)
	FROM	@Quotes AS q

	WHILE	(@CurrentGuid < @MaxGuid)
	BEGIN 
		SELECT	TOP(1) @CurrentGuid = GuidValue 
		FROM	@Quotes AS q
		WHERE	(GuidValue > @CurrentGuid)
		ORDER BY q.GuidValue

		EXEC SSop.QuoteCreateJobs @Guid = @CurrentGuid	-- uniqueidentifier
	END
END
GO
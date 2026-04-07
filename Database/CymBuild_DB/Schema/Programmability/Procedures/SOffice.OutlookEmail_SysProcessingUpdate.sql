SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO



CREATE PROCEDURE [SOffice].[OutlookEmail_SysProcessingUpdate]
	(	
		@DeliveryReceiptReceived BIT,
		@ReadReceiptReceived BIT,
		@FiledDateTime DATETIME2,
		@Guid UNIQUEIDENTIFIER
	)
AS
BEGIN
	
		UPDATE	SOffice.OutlookEmails
		SET		
				DeliveryReceiptReceived = @DeliveryReceiptReceived,
				ReadReceiptReceived = @ReadReceiptReceived,
				FiledDateTime = @FiledDateTime
		WHERE	(Guid = @Guid);

END;
GO
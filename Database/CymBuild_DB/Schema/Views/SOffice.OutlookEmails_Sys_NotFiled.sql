SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO


CREATE VIEW [SOffice].[OutlookEmails_Sys_NotFiled]
	--WITH SCHEMABINDIGN
AS
SELECT	oe.ID,
		oe.Guid,
		oe.RowStatus,
		oe.RowVersion,
		t.EntityTypeId,
		et.Guid AS EntityTypeGuid,
		oe.TargetObjectId,
		t.Guid AS TargetObjectGuid,
		t.FilingLocation,
		oe.OutlookEmailMailboxID,
		oem.Name AS MailboxName,
		oe.MessageID,
		oe.OutlookEmailConversationId,
		oec.Guid OutlookEmailConversationGuid,
		oec.ConversationID,
		oe.OutlookEmailFromAddressID,
		oefa.Guid OutlookEmailFromAddressGuid,
		oefa.Address AS FromAddress,
		oe.ToAddresses,
		oe.Subject,
		oe.SentDateTime,
		oe.DeliveryReceiptRequested,
		oe.DeliveryReceiptReceived,
		oe.ReadReceiptRequested,
		oe.ReadReceiptReceived,
		oe.DoNotFile,
		oe.IsReadyToFile,
		oe.FiledDateTime,
		oe.IsFiled
FROM	SOffice.OutlookEmails oe
JOIN	SOffice.OutlookEmailMailboxes oem ON (oem.ID = oe.OutlookEmailMailboxID)
JOIN	SOffice.OutlookEmailConversations oec ON (oec.ID = oe.OutlookEmailConversationId)
JOIN	SOffice.TargetObjects t ON (oe.TargetObjectID = t.ID)
JOIN	SOffice.EntityTypes et ON (et.ID = t.EntityTypeId)
JOIN	SOffice.OutlookEmailFromAddresses oefa ON (oefa.ID = oe.OutlookEmailFromAddressID)
WHERE	(oe.DoNotFile = 0)
	AND	(oe.FiledDateTime IS NULL)
	AND	(oe.RowStatus NOT IN (0, 254))
	AND	(oem.RowStatus NOT IN (0, 254))
	AND	(oec.RowStatus NOT IN (0,254))
GO
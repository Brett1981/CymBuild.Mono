SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE VIEW [SOffice].[OutlookEmails_Sys_ReadyToFile]
	--WITH SCHEMABINDIGN
AS
SELECT	oe.ID,
		oe.Guid,
		oe.RowStatus,
		oe.RowVersion,
		t.EntityTypeId,
		et.Guid AS EntityTypeGuid,
		oe.TargetObjectID,
		t.Guid AS TargetObjectGuid,
		t.FilingLocation,
		oe.OutlookEmailMailboxID,
		oem.Name AS MailboxName,
		oe.MessageID,
		oec.ConversationID,
		oe.DeliveryReceiptRequested,
		oe.DeliveryReceiptReceived,
		oe.ReadReceiptRequested,
		oe.ReadReceiptReceived
FROM	SOffice.OutlookEmails oe
JOIN	SOffice.OutlookEmailMailboxes oem ON (oem.ID = oe.OutlookEmailMailboxID)
JOIN	SOffice.OutlookEmailConversations oec ON (oec.ID = oe.OutlookEmailConversationId)
JOIN	SOffice.TargetObjects t ON (t.ID = oe.TargetObjectID)
JOIN	SCore.EntityTypes et ON (et.ID = t.EntityTypeId)
WHERE	(oe.IsReadyToFile = 1)
	AND	(oe.DoNotFile = 0)
	AND	(oe.FiledDateTime IS NULL)
	AND	(oe.RowStatus NOT IN (0, 254))
	AND	(oem.RowStatus NOT IN (0, 254))
	AND	(oec.RowStatus NOT IN (0,254))
GO
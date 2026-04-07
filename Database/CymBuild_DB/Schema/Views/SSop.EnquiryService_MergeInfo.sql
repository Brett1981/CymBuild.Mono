SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SSop].[EnquiryService_MergeInfo]
AS
SELECT		es.ID,
			es.RowStatus,
			es.RowVersion,
			es.Guid,
			e.Guid AS EnquiryGuid,
			q.Guid AS QuoteGuid,
			e.Guid AS ParentGuid
FROM		SSop.EnquiryServices				  AS es
JOIN		SSop.Enquiries AS e ON (e.ID = es.EnquiryId)
JOIN		SSop.EnquiryService_ExtendedInfo AS esei ON (esei.Id = es.ID)
JOIN		SSop.Quotes AS q ON (q.Id = esei.QuoteID)
GO
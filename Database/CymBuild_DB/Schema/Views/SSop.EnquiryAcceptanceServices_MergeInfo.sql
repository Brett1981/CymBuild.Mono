SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SSop].[EnquiryAcceptanceServices_MergeInfo]
AS
SELECT		es.ID,
			es.RowStatus,
			es.RowVersion,
			jt.Name,
			N'' AS Accept,
			e.Guid AS EnquiryGuid,
			e.Guid AS ParentGuid,
			es.Guid AS Guid
FROM		SSop.EnquiryServices				  AS es
JOIN		SSop.Enquiries AS e ON (e.ID = es.EnquiryId)
JOIN		SJob.JobTypes AS jt ON (jt.ID = es.JobTypeId)

GO
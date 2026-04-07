SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SJob].[GetJobSignatoryInfo]
--WITH SCHEMABINDING
AS
SELECT		j.ID,
			j.RowStatus,
			j.RowVersion,
			ISNULL (   QuoteDetail.EnquiryGuid,
					   '00000000-0000-0000-0000-000000000000'
				   ) AS EnquiryGuid,
			ISNULL (   QuoteDetail.Guid,
					   '00000000-0000-0000-0000-000000000000'
				   ) AS QuoteGuid,
			j.Guid	 AS JobGuid,
			jt.Name JobTypeName,
			QuoteDetail.FullName,
			QuoteDetail.UserGuid,
			QuoteDetail.EmailAddress,
			QuoteDetail.JobTitle,
			QuoteDetail.IsActive,
			ISNULL (   QuoteDetail.Signature,
					   0x
				   ) AS BinarySignature
FROM		SJob.Jobs AS j
JOIN		SJob.JobTypes		 AS jt ON (jt.ID = j.JobTypeId)
OUTER APPLY
			(
				SELECT	q.ID,
						q.Guid,
						q.EnquiryServiceID,
						e.Guid AS EnquiryGuid,
						i.Guid AS UserGuid,
						i.EmailAddress,
						i.JobTitle,
						i.FullName,
						I.IsActive,
						i.Signature
				FROM	SSop.Quotes AS q
				LEFT JOIN	SSop.EnquiryServices AS es ON (es.ID = q.EnquiryServiceID)
				LEFT JOIN	SSop.Enquiries		 AS e ON (e.ID	 = es.EnquiryId) 
				LEFT JOIN	SCore.Identities	 AS i ON (i.ID	 = e.SignatoryIdentityId)
				WHERE	(EXISTS
					(
						SELECT	1
						FROM	SSop.QuoteItems AS qi
						WHERE	(qi.QuoteId		 = q.ID)
							AND (qi.CreatedJobId = j.ID)
					)
						)
			)		  AS QuoteDetail
;
GO
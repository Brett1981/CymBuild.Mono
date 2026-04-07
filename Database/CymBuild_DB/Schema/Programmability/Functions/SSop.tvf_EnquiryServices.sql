SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SSop].[tvf_EnquiryServices]
(
	@UserId INT,
	@ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
             --WITH SCHEMABINDING
AS RETURN	
SELECT  es.ID,
        es.RowStatus,
        es.RowVersion,
        es.Guid,
		jt.Name AS JobType,
		q.FullNumber AS Quote,
		esei.QuoteNet, 
		CONCAT(srs.Number, ' - ', srs.Description) AS StartRibaStage,
		CONCAT(ers.Number, ' - ', ers.Description) AS EndRibaStage,
		CASE 
			WHEN q.ID < 0 THEN N'No Quote'
			WHEN q.DateDeclinedToQuote IS NOT NULL THEN N'Declined To Quote.' --NEW [CBLD-592]
			ELSE qcf.QuoteStatus END AS QuoteStatus
FROM    SSop.EnquiryServices es
JOIN	SSop.EnquiryService_ExtendedInfo AS esei ON (esei.Id = es.ID)
JOIN	SSop.Quotes q ON (q.ID = esei.QuoteId)
JOIN	SSop.Quote_CalculatedFields AS qcf ON (qcf.ID = q.ID)
JOIN	SJob.JobTypes jt ON (jt.ID = es.JobTypeId)
JOIN	SJob.RibaStages srs ON (srs.ID = es.StartRibaStageId)
JOIN	SJob.RibaStages ers ON (ers.ID = es.EndRibaStageId)
JOIN	SSop.Enquiries enq ON (enq.ID = es.EnquiryId) --NEW [CBLD-592]
WHERE   (es.RowStatus NOT IN (0, 254))
	AND	(q.RowStatus NOT IN (0, 254))
AND	(EXISTS
			(
		SELECT
				1
		FROM
				SCore.ObjectSecurityForUser_CanRead(es.Guid, @UserId) oscr
			)
		)
	AND	(EXISTS 
			(
				SELECT	1
				FROM	SSop.Enquiries AS e
				WHERE	(e.Guid = @ParentGuid)
					AND	(e.ID = es.EnquiryId)
			)
		)
UNION ALL
SELECT  -1,
        CONVERT(tinyint, 1),
        null,
        '00000000-0000-0000-0000-000000000000',
		N'Total:' AS JobType,
		N'' AS Quote,
		SUM(esei.QuoteNet) AS QuoteNet, 
		N'' AS StartRibaStage,
		N'' AS EndRibaStage,
		N'' AS QuoteStatus
FROM    SSop.EnquiryServices es
JOIN	SSop.EnquiryService_ExtendedInfo AS esei ON (esei.Id = es.ID)
WHERE   (es.RowStatus NOT IN (0, 254))
	AND	(EXISTS 
			(
				SELECT	1
				FROM	SSop.Enquiries AS e
				WHERE	(e.Guid = @ParentGuid)
					AND	(e.ID = es.EnquiryId)
			)
		)
GO
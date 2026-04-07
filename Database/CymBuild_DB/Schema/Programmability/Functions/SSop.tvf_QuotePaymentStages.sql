SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SSop].[tvf_QuotePaymentStages]
	(
		@UserId INT,
		@ParentGuid UNIQUEIDENTIFIER
	)
RETURNS TABLE
   --WITH SCHEMABINDING
AS
RETURN SELECT		qps.ID,
					qps.RowStatus,
					qps.RowVersion,
					qps.Guid,
					pft.Name AS PaymentFrequencyType,
					qps.PaymentFrequency,
					qps.Value,
					qps.PercentageOfTotal,
					rs.Number AS PayAfterStageNumber
	   FROM			SSop.QuotePaymentStages			  AS qps
	   JOIN			SSop.Quotes					  AS q ON (q.ID = qps.QuoteId)
	   JOIN			SJob.RibaStages				  AS rs ON (rs.ID = qps.PayAfterStageId)
	   JOIN			SFin.PaymentFrequencyTypes pft ON (pft.ID = qps.PaymentFrequencyTypeId)
	   WHERE		(qps.RowStatus NOT IN (0, 254))
				AND (qps.ID		> 0)
AND	(EXISTS
			(
					SELECT
							1
					FROM
							SCore.ObjectSecurityForUser_CanRead(qps.Guid, @UserId) oscr
			)
		)
				AND (q.Guid		= @ParentGuid)
	   
GO
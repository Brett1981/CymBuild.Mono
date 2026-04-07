SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SSop].[tvf_QuoteItems]
(
	@UserId INT,
	@ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
       --WITH SCHEMABINDING
AS RETURN	
SELECT  qi.ID,
        qi.RowStatus,
        qi.Guid,
		qi.SortOrder,
		qi.Details,
		p.Code,
		qi.Quantity,
		qi.Net,
		qit.Vat,
		qit.Gross,
		qit.LineNet,
		qit.LineVat,
		qit.LineGross,
		CASE WHEN qi.DoNotConsolidateJob = 0 THEN N'Yes' ELSE N'No' END AS DoNotConsolidateJob, --reads better on the grid.
		invsch.Name AS InvoiceScheduleName,
		j.Number AS JobNumber
FROM    SSop.QuoteItems qi
JOIN	SSop.Quotes q ON (q.ID = qi.QuoteId)
JOIN	SSop.QuoteItemTotals qit ON (qit.ID = qi.ID)
JOIN	SProd.Products p ON (p.ID = qi.ProductId)	
JOIN    SFin.InvoiceSchedules as invsch ON (qi.InvoicingSchedule = invsch.ID)
JOIN	SJob.Jobs AS j ON (j.ID = qi.CreatedJobId)
WHERE   (qi.RowStatus NOT IN (0, 254))
AND	(EXISTS
			(
		SELECT
				1
		FROM
				SCore.ObjectSecurityForUser_CanRead(qi.Guid, @UserId) oscr
			)
		)
	AND	(q.Guid = @ParentGuid)
UNION ALL 
SELECT	-2,
		1,
		'00000000-0000-0000-0000-000000000000',
		999,
		N'Total',
		N'',
		SUM(qi.Quantity),
		SUM(qi.Net),
		SUM(qit.Vat),
		SUM(qit.Gross),
		SUM(qit.LineNet),
		SUM(qit.LineVat),
		SUM(qit.LineGross),
		N'',
		N'',
		N''
FROM    SSop.QuoteItems qi
JOIN	SSop.Quotes q ON (q.ID = qi.QuoteId)
JOIN	SSop.QuoteItemTotals qit ON (qit.ID = qi.ID)
JOIN    SFin.InvoiceSchedules as invsch ON (qi.InvoicingSchedule = invsch.ID)
JOIN	SJob.Jobs AS j ON (j.ID = qi.CreatedJobId)
WHERE   (qi.RowStatus NOT IN (0, 254))
	AND	(q.Guid = @ParentGuid)
GO
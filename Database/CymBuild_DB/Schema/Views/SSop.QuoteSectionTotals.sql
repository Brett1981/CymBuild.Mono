SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SSop].[QuoteSectionTotals]
        --WITH SCHEMABINDING
AS 
SELECT	qi.QuoteSectionId AS ID,
		CONVERT(DECIMAL(9, 2), ROUND(SUM(qit.LineNet), 2)) AS Net,
		CONVERT(DECIMAL(9, 2), ROUND(SUM(qit.LineVat), 2)) AS Vat,
		CONVERT(DECIMAL(9, 2), ROUND(SUM(qit.LineGross), 2)) AS Gross
FROM	SSop.QuoteItems qi
JOIN	SSop.QuoteItemTotals qit ON (qit.ID = qi.ID)
WHERE	(qi.RowStatus NOT IN (0, 254))
GROUP BY qi.QuoteSectionId
GO
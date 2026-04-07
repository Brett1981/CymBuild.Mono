SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SSop].[QuoteItems_MergeInfo]
AS
SELECT		qi.ID,
			qi.RowStatus,
			qi.RowVersion,
			qi.Guid,
			p.Description,
			qit.LineNet,
			q.Guid AS ParentGuid
FROM		SSop.QuoteItems				  AS qi
JOIN		SSop.QuoteItemTotals AS qit ON (qit.ID = qi.ID)
JOIN		SSop.Quotes AS q ON (q.ID = qi.QuoteId)
JOIN		SProd.Products AS p ON (p.ID = qi.ProductId)
GO
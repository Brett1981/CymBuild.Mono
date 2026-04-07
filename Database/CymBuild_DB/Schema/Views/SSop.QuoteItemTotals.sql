SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SSop].[QuoteItemTotals]
             --WITH SCHEMABINDING
AS 
SELECT	qi.ID,
		CONVERT(DECIMAL(19, 2), ROUND((qi.Net * (qi.VatRate / 100)), 2)) AS Vat,
		CONVERT(DECIMAL(19, 2), ROUND(qi.Net + ROUND((qi.net * ((qi.VatRate / 100))), 2), 2)) AS Gross,
		CONVERT(DECIMAL(19, 2), ROUND ((qi.net * qi.Quantity), 2)) AS LineNet,
		CONVERT(DECIMAL(19, 2), ROUND((ROUND ((qi.net * qi.Quantity), 2) * (qi.VatRate / 100 )), 2)) AS LineVat,
		CONVERT(DECIMAL(19, 2), ROUND(ROUND ((qi.net * qi.Quantity), 2) + ROUND((ROUND ((qi.net * qi.Quantity), 2) * ((qi.VatRate / 100 ))), 2), 2)) AS LineGross
FROM	SSop.QuoteItems qi
GO
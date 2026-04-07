SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE	FUNCTION [SProd].[tvf_ProductPrices]
(
	@ProductGuid UNIQUEIDENTIFIER,
	@UserId INT
)
RETURNS TABLE
AS 
RETURN
SELECT	plp.ID,
		plp.RowStatus,
		plp.Guid,
		pl.Name,
		plp.Price,
		CASE WHEN std.StandardPriceListID = plp.PriceListId THEN 1 ELSE 0 END AS IsStandardPrice
FROM	SSop.PriceListProducts AS plp
JOIN	SSop.PriceLists AS pl ON (pl.ID = plp.PriceListId)
OUTER APPLY	 
		(
			SELECT	s.StandardPriceListID
			FROM	SCore.System AS s
			JOIN	SSop.PriceListProducts AS plp2 ON (plp2.ID = s.StandardPriceListID)
			WHERE	(plp.ProductId = plp2.ProductId)
		) std
WHERE	(plp.RowStatus NOT IN (0, 254))
	AND	(EXISTS
			(
				SELECT	1
				FROM	SProd.Products AS p 
				WHERE	(p.Guid = @ProductGuid)
			)
		)
	AND	(EXISTS
			(
				SELECT	1
				FROM	SCore.ObjectSecurityForUser_CanRead(plp.Guid, @UserID) AS osfucr
			)
		)
		




GO
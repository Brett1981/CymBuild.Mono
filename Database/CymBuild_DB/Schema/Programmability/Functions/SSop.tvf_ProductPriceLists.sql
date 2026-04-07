SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO


CREATE FUNCTION [SSop].[tvf_ProductPriceLists]
(
	@UserId INT,
	@ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
AS RETURN
SELECT  plp.ID,
        plp.RowStatus,
        plp.RowVersion,
        plp.Guid,
		p.Code,
		p.Description,
		plp.Price,
		pl.Name
FROM    SSop.PriceListProducts plp
JOIN	SSop.PriceLists pl ON (pl.ID = plp.PriceListId)
JOIN	SProd.Products p ON (p.ID = plp.ProductId)
WHERE   (plp.RowStatus NOT IN (0, 254))
	AND	(plp.ID > 0)
	AND	(EXISTS
			(
		SELECT
				1
		FROM
				SCore.ObjectSecurityForUser_CanRead(plp.Guid, @UserId) oscr
			)
		)
	AND p.Guid = @ParentGuid;

GO
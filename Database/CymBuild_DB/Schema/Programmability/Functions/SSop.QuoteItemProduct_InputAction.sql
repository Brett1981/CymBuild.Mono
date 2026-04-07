SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SSop].[QuoteItemProduct_InputAction]
(
    @DataObject NVARCHAR(MAX)
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @ProductGuid UNIQUEIDENTIFIER,
            @QuoteGuid UNIQUEIDENTIFIER,
            @PricingAccountID INT,
            @ContractId INT,
            @Quantity DECIMAL(19,2),
            @StandardPrice DECIMAL(19, 2),
            @ProductPrice DECIMAL(19, 2),
            @DataProperties SCore.DataProperties,
            @QuotePropertyGuid UNIQUEIDENTIFIER,
            @ProductPropertyGuid UNIQUEIDENTIFIER,
			@QuantityPropertyGuid UNIQUEIDENTIFIER,
            @NetPropertyGuid UNIQUEIDENTIFIER;
 
    -- Retrieve Property GUIDs
    SELECT @QuotePropertyGuid = SCore.GetEntityPropertyGuid(N'SSop', N'QuoteItems', N'QuoteId');
    SELECT @ProductPropertyGuid = SCore.GetEntityPropertyGuid(N'SSop', N'QuoteItems', N'ProductId');
    SELECT @NetPropertyGuid = SCore.GetEntityPropertyGuid(N'SSop', N'QuoteItems', N'Net');
	SELECT @QuantityPropertyGuid = SCore.GetEntityPropertyGuid(N'SSop', N'QuoteItems', N'Quantity');
 
    -- Populate @DataProperties table from JSON
    INSERT INTO @DataProperties
    (
        [EntityPropertyGuid],
        [IsInvalid],
        [IsEnabled],
        [IsRestricted],
        [IsHidden],
        [StringValue],
        [DoubleValue],
        [IntegerValue],
        [BigIntValue],
        [BitValue],
        [DateTimeValue]
    )
    SELECT
        [EntityPropertyGuid],
        [IsInvalid],
        [IsEnabled],
        [IsRestricted],
        [IsHidden],
        [StringValue],
        [DoubleValue],
        [IntValue],
        [BigIntValue],
        [BitValue],
        [DateTimeValue]
    FROM
        SCore.Json_GetDataProperties(@DataObject);
 
    -- Extract Product GUID, ensuring it's a valid UNIQUEIDENTIFIER or replacing it with an empty GUID
    SELECT @ProductGuid = TRY_CAST(StringValue AS UNIQUEIDENTIFIER)
    FROM @DataProperties
    WHERE (EntityPropertyGuid = @ProductPropertyGuid);
 
    -- Extract Quote GUID, ensuring it's a valid UNIQUEIDENTIFIER or replacing it with an empty GUID
    SELECT @QuoteGuid = TRY_CAST(StringValue AS UNIQUEIDENTIFIER)
    FROM @DataProperties
    WHERE (EntityPropertyGuid = @QuotePropertyGuid);

	SELECT @Quantity = TRY_CAST(DoubleValue AS DECIMAL)
    FROM @DataProperties
    WHERE (EntityPropertyGuid = @QuantityPropertyGuid);
 
    -- Decide the Pricing Account
    SELECT
        @PricingAccountID = CASE
                                WHEN q.ClientAccountId < 0 THEN
                                    q.AgentAccountId
                                ELSE
                                    q.ClientAccountId
                            END,
        @ContractId = q.ContractID
    FROM
        SSop.Quotes q
    WHERE
        (q.Guid = @QuoteGuid)
        
 
    -- Get the standard price
    SELECT @StandardPrice = plp.Price
    FROM SSop.PriceListProducts plp
    JOIN SProd.Products P ON P.Id = plp.ProductId
    --JOIN SCore.System s ON s.StandardPriceListID = plp.PriceListId
    WHERE (p.Guid = @ProductGuid);
 
    -- Calculate the Price
    SELECT @ProductPrice = COALESCE(ContractPrice.Price, AccountPrice.Price, @StandardPrice, 0)
    FROM SProd.Products p
    OUTER APPLY
    (
        SELECT
            CASE
                WHEN plp.Price IS NOT NULL THEN plp.Price
                WHEN pl.UpliftOnStandardPrice <> 0 THEN @StandardPrice * pl.UpliftOnStandardPrice
                ELSE NULL
            END AS Price
        FROM SSop.PriceLists pl
        LEFT JOIN SSop.PriceListProducts plp ON (plp.ProductId = p.ID)
        WHERE (ISNULL(plp.ProductId, p.ID) = p.ID) AND 
              EXISTS (SELECT 1 FROM SCrm.Accounts a WHERE (a.PriceListId = pl.ID) AND (a.ID = @PricingAccountID))
    ) AS AccountPrice
    OUTER APPLY
    (
        SELECT
            CASE
                WHEN plp.Price IS NOT NULL THEN plp.Price
                WHEN pl.UpliftOnStandardPrice <> 0 THEN @StandardPrice * pl.UpliftOnStandardPrice
                ELSE NULL
            END AS Price
        FROM SSop.PriceLists pl
        LEFT JOIN SSop.PriceListProducts plp ON (plp.ProductId = p.ID)
        WHERE (ISNULL(plp.ProductId, p.ID) = p.ID) AND 
              EXISTS (SELECT 1 FROM SSop.Contracts c WHERE (c.PriceListId = pl.ID) AND (c.ID = @ContractId))
    ) AS ContractPrice
    WHERE (p.Guid = @ProductGuid);
 
	IF (@Quantity = 0)
	BEGIN 
		SET	@Quantity = 1
	END

	UPDATE	@DataProperties
	SET	DoubleValue = @Quantity
	WHERE	EntityPropertyGuid = @QuantityPropertyGuid

    -- Update the @DataProperties with the calculated price
    UPDATE @DataProperties
    SET DoubleValue = @ProductPrice 
    WHERE EntityPropertyGuid = @NetPropertyGuid;
 
    -- Update the original DataObject with modified DataProperties
    SELECT @DataObject = SCore.JSON_UpdateDataProperties(@DataObject, @DataProperties);
 
    -- Return the updated DataObject
    RETURN @DataObject;
END;
GO
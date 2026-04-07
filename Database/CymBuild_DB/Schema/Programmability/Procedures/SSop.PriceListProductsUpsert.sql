SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SSop].[PriceListProductsUpsert]
(
    @PriceListGuid UNIQUEIDENTIFIER,
	@ProductGuid UNIQUEIDENTIFIER,
	@Price DECIMAL (9,2),
    @Guid UNIQUEIDENTIFIER
)
AS 
BEGIN 
    DECLARE @PriceListId INT,
			@ProductId INT

	SELECT  @PriceListId = ID 
    FROM    SSop.PriceLists
    WHERE   ([Guid] = @PriceListGuid)

	SELECT  @ProductId = ID 
    FROM    SProd.Products
    WHERE   ([Guid] = @ProductGuid)

    DECLARE	@IsInsert BIT = 0;

	EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
							@SchemeName = N'SSop',				-- nvarchar(255)
							@ObjectName = N'PriceListProducts',				-- nvarchar(255)
							@IsInsert = @IsInsert OUTPUT	-- bit

	IF @IsInsert = 1
    BEGIN
		INSERT SSop.PriceListProducts
			 (RowStatus, Guid, PriceListId, ProductId, Price)
		VALUES
			 (
				 1,	-- RowStatus - tinyint
				 @Guid,	-- Guid - uniqueidentifier
				 @PriceListId,	-- PriceListId - int
				 @ProductId,	-- ProductId - int
				 @Price	-- Price - decimal(9, 2)
			 )
    END
    ELSE
    BEGIN 
        UPDATE  SSop.PriceListProducts
        SET     PriceListId = @PriceListId,
				ProductId = @ProductId,
				Price = @Price
		WHERE   ([Guid] = @Guid)
    END
END
GO
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SSop].[PriceListsUpsert] 
								@Name NVARCHAR(100),
								@IsActive BIT,
								@UpliftOnStandardPrice DECIMAL(9, 2),
								@Guid UNIQUEIDENTIFIER OUT
AS
BEGIN
	DECLARE	@IsInsert BIT = 0;

	EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
							@SchemeName = N'SSop',				-- nvarchar(255)
							@ObjectName = N'PriceLists',				-- nvarchar(255)
							@IncludeDefaultSecurity = 0, -- bit
							@IsInsert = @IsInsert OUTPUT	-- bit

	IF @IsInsert = 1
	BEGIN
		INSERT	SSop.PriceLists
			 (RowStatus,
			  Guid,
			  Name,
              IsActive,
			  UpliftOnStandardPrice
			)
		VALUES
			 (
				 1,						-- RowStatus - tinyint
				 @Guid,				-- Guid - uniqueidentifier
				 @Name,
				 @IsActive,
				 @UpliftOnStandardPrice
			 );
	END;
	ELSE
	BEGIN
		UPDATE	SSop.PriceLists
		SET		Name = @Name,
				IsActive = @IsActive,
				UpliftOnStandardPrice = @UpliftOnStandardPrice
		WHERE	(Guid = @Guid);
	END;
END;

GO
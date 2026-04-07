SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SSop].[QuoteSourcesUpsert] 
								@Name NVARCHAR(50),
								@Guid UNIQUEIDENTIFIER OUT
AS
BEGIN
	DECLARE @IsInsert BIT

	EXEC SCore.UpsertDataObject
			@Guid		= @Guid,					-- uniqueidentifier
			@SchemeName = N'SSop',				-- nvarchar(255)
			@ObjectName = N'Quotes',				-- nvarchar(255)
			@IncludeDefaultSecurity = 0, --bit
			@IsInsert   = @IsInsert OUTPUT	-- bit

	IF (@IsInsert = 1)
	BEGIN
		INSERT	SSop.QuoteSources
			 (RowStatus,
			  Guid,
			  Name
			)
		VALUES
			 (
				 1,						-- RowStatus - tinyint
				 @Guid,				-- Guid - uniqueidentifier
				 @Name
			 );
	END;
	ELSE
	BEGIN
		UPDATE	SSop.QuoteSources
		SET		Name = @Name
		WHERE	(Guid = @Guid);
	END;
END;

GO
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCore].[MarketsUpsert]
	(
		@Guid				UNIQUEIDENTIFIER,
		@Name				NVARCHAR(150)
	)
AS
	BEGIN
	

	
		DECLARE @IsInsert BIT
		EXEC SCore.UpsertDataObject
			@Guid		= @Guid,					-- uniqueidentifier
			@SchemeName = N'SCore',				-- nvarchar(255)
			@ObjectName = N'Markets',				-- nvarchar(255)
			@IsInsert   = @IsInsert OUTPUT	-- bit

		IF (@IsInsert = 1)
			BEGIN
				INSERT SCore.Markets
						(
							RowStatus,
							Guid,
							Name
						)
				VALUES
						(
							1,	-- RowStatus - tinyint
							@Guid,	-- Guid - uniqueidentifier
							@Name
						)
			END
		ELSE
			BEGIN
				UPDATE SCore.Markets
				SET		Name = @Name
				WHERE
					([Guid] = @Guid)
			END
	END
GO
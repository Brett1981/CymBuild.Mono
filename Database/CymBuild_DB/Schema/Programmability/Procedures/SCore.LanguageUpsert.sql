SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO


CREATE PROCEDURE [SCore].[LanguageUpsert]
	(	@Name NVARCHAR(250),
		@Locale NVARCHAR(50),
		@Guid UNIQUEIDENTIFIER OUT
	)
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @IsInsert BIT = 0;
	EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
								@SchemeName = N'SCore',			-- nvarchar(255)
								@ObjectName = N'Languages',		-- nvarchar(255)
								@IsInsert = @IsInsert OUTPUT;	-- bit

	IF (@IsInsert = 1)
	BEGIN
		INSERT	SCore.Languages
			 (Guid, Name, Locale, RowStatus)
		VALUES
			 (
				 @Guid,
				 @Name,
				 @Locale,
				 1
			 );
	END;
	ELSE
	BEGIN
		UPDATE	SCore.Languages
		SET		Name = @Name,
				Locale = @Locale
		WHERE	(Guid = @Guid);
	END;
END;
GO
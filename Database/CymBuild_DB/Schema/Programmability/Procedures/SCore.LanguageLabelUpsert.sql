SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE PROCEDURE [SCore].[LanguageLabelUpsert]
	(	@Name NVARCHAR(250),
		@Guid UNIQUEIDENTIFIER OUT
	)
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @IsInsert BIT = 0;
	EXEC SCore.UpsertDataObject @Guid = @Guid,						-- uniqueidentifier
								@SchemeName = N'SCore',				-- nvarchar(255)
								@ObjectName = N'LanguageLabels',	-- nvarchar(255)
								@IsInsert = @IsInsert OUTPUT;		-- bit

	IF (@IsInsert = 1)
	BEGIN
		INSERT	SCore.LanguageLabels
			 (Guid, Name, RowStatus)
		VALUES
			 (
				 @Guid,
				 @Name,
				 1
			 );
	END;
	ELSE
	BEGIN
		UPDATE	SCore.LanguageLabels
		SET		Name = @Name
		WHERE	(Guid = @Guid);
	END;
END;
GO
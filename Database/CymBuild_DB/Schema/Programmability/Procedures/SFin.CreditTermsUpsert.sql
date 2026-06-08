SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[CreditTermsUpsert]')
GO


CREATE PROCEDURE [SFin].[CreditTermsUpsert]
	(	@Name NVARCHAR(250),
		@DueDays INT,
		@Guid UNIQUEIDENTIFIER OUT
	)
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @IsInsert BIT = 0;
	EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
								@SchemeName = N'SFin',			-- nvarchar(255)
								@ObjectName = N'CreditTerms',	-- nvarchar(255)
								@IsInsert = @IsInsert OUTPUT;	-- bit

	IF (@IsInsert = 1)
	BEGIN
		INSERT	SFin.CreditTerms
			 (Guid, Name, DueDays, RowStatus)
		VALUES
			 (
				 @Guid,
				 @Name,
				 @DueDays,
				 1
			 );
	END;
	ELSE
	BEGIN
		UPDATE	SFin.CreditTerms
		SET		Name = @Name,
				DueDays = @DueDays
		WHERE	(Guid = @Guid);
	END;
END;
GO
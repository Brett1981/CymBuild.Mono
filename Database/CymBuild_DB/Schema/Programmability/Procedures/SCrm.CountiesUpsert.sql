SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCrm].[CountiesUpsert] 
								@Name NVARCHAR(100),
								@CountryGuid UNIQUEIDENTIFIER,
								@Guid UNIQUEIDENTIFIER OUT
AS
BEGIN
	DECLARE	@CountryID INT 

	SELECT	@CountryID = c.ID 
	FROM	SCrm.Countries c
	WHERE	(Guid = @CountryGuid)

	DECLARE @IsInsert BIT
    EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
							@SchemeName = N'SCrm',				-- nvarchar(255)
							@ObjectName = N'Counties',				-- nvarchar(255)
							@IncludeDefaultSecurity = 0,
							@IsInsert = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
    BEGIN
		INSERT	SCrm.Counties
			 (RowStatus,
			  Guid,
			  Name,
			  CountryID)
		VALUES
			 (
				 1,						-- RowStatus - tinyint
				 @Guid,				-- Guid - uniqueidentifier
				 @Name,
				 @CountryID
			 );
	END;
	ELSE
	BEGIN
		UPDATE	SCrm.Counties
		SET		Name = @Name,
				CountryID = @CountryID
		WHERE	(Guid = @Guid);
	END;
END;

GO
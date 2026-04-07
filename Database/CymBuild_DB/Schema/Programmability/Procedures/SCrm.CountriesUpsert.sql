SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCrm].[CountriesUpsert] 
								@Name NVARCHAR(100),
								@Guid UNIQUEIDENTIFIER OUT
AS
BEGIN

	DECLARE @IsInsert BIT
    EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
							@SchemeName = N'SCrm',				-- nvarchar(255)
							@ObjectName = N'Countries',				-- nvarchar(255)
							@IncludeDefaultSecurity = 0,    -- bit
							@IsInsert = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
    BEGIN
		/* Create the basic job record */
		INSERT	SCrm.Countries
			 (RowStatus,
			  Guid,
			  Name)
		VALUES
			 (
				 1,						-- RowStatus - tinyint
				 @Guid,				-- Guid - uniqueidentifier
				 @Name
			 );
	END;
	ELSE
	BEGIN
		UPDATE	SCrm.Countries
		SET		Name = @Name
		WHERE	(Guid = @Guid);
	END;
END;

GO
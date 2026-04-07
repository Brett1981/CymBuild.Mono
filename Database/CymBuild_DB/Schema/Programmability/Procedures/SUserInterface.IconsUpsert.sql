SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SUserInterface].[IconsUpsert]')
GO
CREATE PROCEDURE [SUserInterface].[IconsUpsert]
(
	@Guid UNIQUEIDENTIFIER,
	@Name NVARCHAR(50)
)
AS 
BEGIN
	SET NOCOUNT ON

	DECLARE @IsInsert BIT = 0;
	EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
								@SchemeName = N'SUserInterface',			-- nvarchar(255)
								@ObjectName = N'Icons',		-- nvarchar(255)
								@IsInsert = @IsInsert OUTPUT;	-- bit


	--Ensure icon isn't already added.
	IF(EXISTS(SELECT 1 FROM SUserInterface.Icons WHERE Name = @Name OR Name LIKE @Name))
	BEGIN 
		;THROW 60000, N'Icon already exists!', 1
	END

	IF (@IsInsert = 1)
	BEGIN
		INSERT	SUserInterface.Icons
			 (
				RowStatus,
				Guid,
				Name
			 )
		VALUES
			 (
				 1,
				 @Guid,
				 @Name
			 );
	END;
	ELSE
	BEGIN
		UPDATE	SUserInterface.Icons
		SET		
			Name					= @Name
		WHERE	(Guid = @Guid);
	END;


END;
GO
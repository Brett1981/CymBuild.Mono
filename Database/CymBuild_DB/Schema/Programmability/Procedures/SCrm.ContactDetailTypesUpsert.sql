SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCrm].[ContactDetailTypesUpsert] 
								@Name NVARCHAR(100),
								@Guid UNIQUEIDENTIFIER OUT
AS
BEGIN
	DECLARE	@IsInsert bit
	EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
							@SchemeName = N'SCrm',				-- nvarchar(255)
							@ObjectName = N'ContactDetailTypes',				-- nvarchar(255)
							@IncludeDefaultSecurity = 0,
							@IsInsert = @IsInsert OUTPUT	-- bit

	IF 
	 (
		@IsInsert = 1
	 )
	BEGIN
		INSERT	SCrm.ContactDetailTypes
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
		UPDATE	SCrm.ContactDetailTypes
		SET		Name = @Name
		WHERE	(Guid = @Guid);
	END;
END;

GO
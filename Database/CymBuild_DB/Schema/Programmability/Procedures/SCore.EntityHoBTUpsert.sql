SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO


CREATE PROCEDURE [SCore].[EntityHoBTUpsert]
	(	@SchemaName NVARCHAR(250),
		@ObjectName NVARCHAR(250),
		@ObjectType NVARCHAR(1),
		@IsMainHoBT BIT,
		@IsReadOnlyOffline BIT,
		@EntityTypeGuid UNIQUEIDENTIFIER,
		@Guid UNIQUEIDENTIFIER OUT
	)
AS
BEGIN
	SET NOCOUNT ON 

	DECLARE @EntityTypeId	 INT;

	SELECT	@EntityTypeId = et.ID
	FROM	SCore.EntityTypes AS et
	WHERE	(et.Guid = @EntityTypeGuid);

	DECLARE @IsInsert BIT = 0;
	EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
						@SchemeName = N'SCore',				-- nvarchar(255)
						@ObjectName = N'EntityHobts',				-- nvarchar(255)
						@IsInsert = @IsInsert OUTPUT	-- bit
	
	IF (@IsInsert = 1)
	BEGIN
		INSERT	SCore.EntityHobts
			 (RowStatus, Guid, SchemaName, ObjectName, EntityTypeID, ObjectType, IsMainHoBT, IsReadOnlyOffline)
		VALUES
			 (
				 1,
				 @Guid,
				 @SchemaName,
				 @ObjectName,
				 @EntityTypeId,
				 @ObjectType,
				 @IsMainHoBT,
				 @IsReadOnlyOffline
			 );
	END;
	ELSE
	BEGIN
		UPDATE	SCore.EntityHobts
		SET		SchemaName = @SchemaName,
				ObjectName = @ObjectName,
				ObjectType = @ObjectType,
				IsMainHoBT = @IsMainHoBT,
				IsReadOnlyOffline = @IsReadOnlyOffline
		WHERE	(Guid = @Guid);
	END;
END;
GO
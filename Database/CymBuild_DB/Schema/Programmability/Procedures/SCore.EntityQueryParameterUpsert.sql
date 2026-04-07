SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCore].[EntityQueryParameterUpsert]
	(	@Name NVARCHAR(250),
		@RowStatus TINYINT,
		@EntityQueryGuid UNIQUEIDENTIFIER,
		@EntityDataTypeGuid UNIQUEIDENTIFIER,
		@MappedEntityPropertyGuid UNIQUEIDENTIFIER,
		@DefaultValue NVARCHAR(100),
		@IsInput BIT,
		@IsOutput BIT,
		@IsReturnColumn BIT,
		@Guid UNIQUEIDENTIFIER OUT
	)
AS
BEGIN
	SET NOCOUNT ON 

	DECLARE @EntityDataTypeID		INT,
			@EntityQueryID			INT,
			@MappedEntityPropertyID INT;

	SELECT	@EntityDataTypeID = ID
	FROM	SCore.EntityDataTypes
	WHERE	(Guid = @EntityDataTypeGuid);

	SELECT	@EntityQueryID = ID
	FROM	SCore.EntityQueries
	WHERE	(Guid = @EntityQueryGuid);

	SELECT	@MappedEntityPropertyID = ID
	FROM	SCore.EntityProperties
	WHERE	(Guid = @MappedEntityPropertyGuid);


	DECLARE @IsInsert BIT = 0;
	EXEC SCore.UpsertDataObject @Guid = @Guid,							-- uniqueidentifier
								@SchemeName = N'SCore',					-- nvarchar(255)
								@ObjectName = N'EntityQueryParameters', -- nvarchar(255)
								@IsInsert = @IsInsert OUTPUT;			-- bit

	IF (@IsInsert = 1)
	BEGIN
		INSERT	SCore.EntityQueryParameters
			 (Guid,
			  Name,
			  RowStatus,
			  EntityQueryID,
			  EntityDataTypeID,
			  MappedEntityPropertyID,
			  DefaultValue,
			  IsInput,
			  IsOutput,
			  IsReturnColumn)
		VALUES
			 (
				 @Guid,
				 @Name,
				 1,
				 @EntityQueryID,
				 @EntityDataTypeID,
				 @MappedEntityPropertyID,
				 @DefaultValue,
				 @IsInput,
				 @IsOutput,
				 @IsReturnColumn
			 );
	END;
	ELSE
	BEGIN
		UPDATE	SCore.EntityQueryParameters
		SET		Name = @Name,
				RowStatus = @RowStatus,
				EntityQueryID = @EntityQueryID,
				EntityDataTypeID = @EntityDataTypeID,
				MappedEntityPropertyID = @MappedEntityPropertyID,
				DefaultValue = @DefaultValue,
				IsInput = @IsInput,
				IsOutput = @IsOutput,
				IsReturnColumn = @IsReturnColumn
		WHERE	(Guid = @Guid);
	END;
END;
GO
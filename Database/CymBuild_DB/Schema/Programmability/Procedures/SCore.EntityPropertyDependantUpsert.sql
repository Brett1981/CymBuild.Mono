SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE PROCEDURE [SCore].[EntityPropertyDependantUpsert]
	(	@ParentEntityPropertyGuid UNIQUEIDENTIFIER,
		@DependantEntityPropertyGuid UNIQUEIDENTIFIER,
		@Guid UNIQUEIDENTIFIER OUT
	)
AS
BEGIN
	SET NOCOUNT ON 

	DECLARE @ParentEntityPropertyID	   INT,
			@DependantEntityPropertyID INT;

	SELECT	@ParentEntityPropertyID = ID
	FROM	SCore.EntityProperties
	WHERE	(Guid = @ParentEntityPropertyGuid);

	SELECT	@DependantEntityPropertyID = ID
	FROM	SCore.EntityProperties
	WHERE	(Guid = @DependantEntityPropertyGuid);


	DECLARE @IsInsert BIT = 0;
	EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
						@SchemeName = N'SCore',			-- nvarchar(255)
						@ObjectName = N'EntityPropertyDependants',		-- nvarchar(255)
						@IsInsert = @IsInsert OUTPUT;	-- bit

	IF (@IsInsert = 1)
	BEGIN
		INSERT	SCore.EntityPropertyDependants
			 (Guid, RowStatus, ParentEntityPropertyID, DependantPropertyID)
		VALUES
			 (
				 @Guid,
				 1,
				 @ParentEntityPropertyID,
				 @DependantEntityPropertyID
			 );
	END;
	ELSE
	BEGIN
		UPDATE	SCore.EntityPropertyDependants
		SET		ParentEntityPropertyID = @ParentEntityPropertyID,
				DependantPropertyID = @DependantEntityPropertyID
		WHERE	(Guid = @Guid);
	END;
END;
GO
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCore].[EntityPropertyGroupUpsert]
	(	@Name NVARCHAR(250),
		@RowStatus TINYINT,
		@IsHidden BIT,
		@SortOrder INT,
		@LanguageLabelGuid UNIQUEIDENTIFIER,
		@EntityTypeGuid UNIQUEIDENTIFIER,
		@PropertyGroupLayoutGuid UNIQUEIDENTIFIER,
		@ShowOnMobile BIT,		
		@IsCollapsable BIT,
		@IsDefaultCollapsed BIT,
		@IsDefaultCollapsed_Mobile BIT,
		@Guid UNIQUEIDENTIFIER OUT
	)
AS
BEGIN
	SET NOCOUNT ON 

	DECLARE @EntityTypeID		   INT,
			@LanguageLabelID	   INT,
			@PropertyGroupLayoutID INT;

	SELECT	@EntityTypeID = ID
	FROM	SCore.EntityTypes
	WHERE	(Guid = @EntityTypeGuid);

	SELECT	@LanguageLabelID = ID
	FROM	SCore.LanguageLabels
	WHERE	(Guid = @LanguageLabelGuid);

	SELECT	@PropertyGroupLayoutID = ID
	FROM	SUserInterface.PropertyGroupLayouts
	WHERE	(Guid = @PropertyGroupLayoutGuid);

	DECLARE @IsInsert BIT = 0;
	EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
								@SchemeName = N'SCore',			-- nvarchar(255)
								@ObjectName = N'EntityPropertyGroups',		-- nvarchar(255)
								@IsInsert = @IsInsert OUTPUT;	-- bit

	IF (@IsInsert = 1)
	BEGIN
		SET @RowStatus = 1;

		INSERT	SCore.EntityPropertyGroups
			 (Guid, Name, RowStatus, IsHidden, SortOrder, LanguageLabelID, EntityTypeID, PropertyGroupLayoutID, ShowOnMobile, IsCollapsable, IsDefaultCollapsed, IsDefaultCollapsed_Mobile)
		VALUES
			 (
				 @Guid,
				 @Name,
				 @RowStatus,
				 @IsHidden,
				 @SortOrder,
				 @LanguageLabelID,
				 @EntityTypeID,
				 @PropertyGroupLayoutID,
				 @ShowOnMobile,
				 @IsCollapsable,
				 @IsDefaultCollapsed,
				 @IsDefaultCollapsed_Mobile
			 );


	END;
	ELSE
	BEGIN
		UPDATE	SCore.EntityPropertyGroups
		SET		Name = @Name,
				RowStatus = @RowStatus,
				IsHidden = @IsHidden,
				SortOrder = @SortOrder,
				LanguageLabelID = @LanguageLabelID,
				EntityTypeID = @EntityTypeID,
				PropertyGroupLayoutID = @PropertyGroupLayoutID,
				ShowOnMobile = @ShowOnMobile,
				IsCollapsable = @IsCollapsable,
				IsDefaultCollapsed = @IsDefaultCollapsed,
				IsDefaultCollapsed_Mobile = @IsDefaultCollapsed_Mobile
		WHERE	(Guid = @Guid);
	END;
END;
GO
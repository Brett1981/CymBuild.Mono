SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCore].[EntityPropertyUpsert]
	(	@Name NVARCHAR(250),
		@RowStatus TINYINT,
		@LanguageLabelGuid UNIQUEIDENTIFIER,
		@EntityHobtGuid UNIQUEIDENTIFIER,
		@EntityDataTypeGuid UNIQUEIDENTIFIER,
		@IsReadOnly BIT,
		@IsImmutable BIT,
		@IsUppercase BIT,
		@IsHidden BIT,
		@IsCompulsory BIT,
		@MaxLength INT,
		@Precision INT,
		@Scale INT,
		@DoNotTrackChanges BIT,
		@EntityPropertyGroupGuid UNIQUEIDENTIFIER,
		@SortOrder SMALLINT,
		@GroupSortOrder SMALLINT,
		@IsObjectLabel BIT,
		@DropDownListDefinitionGuid UNIQUEIDENTIFIER,
		@IsParentRelationship BIT,
		@IsIncludedInformation BIT,
		@IsLatitude BIT,
		@IsLongitude BIT,
		@FixDefaultValue NVARCHAR(50),
		@SqlDefaultValueStatement NVARCHAR(4000),
		@AllowBulkChange BIT,
		@IsVirtual BIT,
		@ShowOnMobile BIT,
		@IsAlwaysVisibleInGroup BIT,
		@IsAlwaysVisibleInGroup_Mobile BIT,
		@Guid UNIQUEIDENTIFIER OUT
	)
AS
BEGIN
	SET NOCOUNT ON 

	DECLARE @LanguageLabelID		  INT,
			@EntityHobtID			  INT,
			@EntityDateTypeID		  INT,
			@EntityPropertyGroupID	  INT,
			@DropDownListDefinitionID INT;

	IF (@LanguageLabelGuid = '00000000-0000-0000-0000-000000000000')
	BEGIN
		SET @LanguageLabelGuid = NEWID ();
	END;

	-- If the language label isn't set, create one based on the name. 
	SELECT	@LanguageLabelID = ID
	FROM	SCore.LanguageLabels
	WHERE	(Guid = @LanguageLabelGuid);

	IF (@LanguageLabelID = -1)
	BEGIN
		EXECUTE SCore.LanguageLabelUpsert @Name = @Name,
										  @Guid = @LanguageLabelGuid OUT;

		SELECT	@LanguageLabelID = ID
		FROM	SCore.LanguageLabels
		WHERE	(Guid = @LanguageLabelGuid);
	END;

	SELECT	@EntityDateTypeID = ID
	FROM	SCore.EntityDataTypes
	WHERE	(Guid = @EntityDataTypeGuid);

	SELECT	@EntityHobtID = ID
	FROM	SCore.EntityHobts
	WHERE	(Guid = @EntityHobtGuid);

	SELECT	@EntityPropertyGroupID = ID
	FROM	SCore.EntityPropertyGroups
	WHERE	(Guid = @EntityPropertyGroupGuid);

	SELECT	@DropDownListDefinitionID = ID
	FROM	SUserInterface.DropDownListDefinitions
	WHERE	(Guid = @DropDownListDefinitionGuid);

	DECLARE @IsInsert BIT = 0;
	EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
								@SchemeName = N'SCore',			-- nvarchar(255)
								@ObjectName = N'EntityProperties',		-- nvarchar(255)
								@IsInsert = @IsInsert OUTPUT;	-- bit

	IF (@IsInsert = 1)
	BEGIN
		INSERT	SCore.EntityProperties
			 (Guid,
			  Name,
			  RowStatus,
			  LanguageLabelID,
			  EntityHoBTID,
			  EntityDataTypeID,
			  IsReadOnly,
			  IsImmutable,
			  IsUppercase,
			  IsHidden,
			  IsCompulsory,
			  MaxLength,
			  Precision,
			  Scale,
			  DoNotTrackChanges,
			  EntityPropertyGroupID,
			  SortOrder,
			  GroupSortOrder,
			  IsObjectLabel,
			  DropDownListDefinitionID,
			  IsParentRelationship,
			  IsIncludedInformation,
			  IsLatitude,
			  IsLongitude,
			  FixedDefaultValue,
			  SqlDefaultValueStatement,
			  AllowBulkChange,
			  IsVirtual,
			  ShowOnMobile,
			  IsAlwaysVisibleInGroup,
			  IsAlwaysVisibleInGroup_Mobile)
		VALUES
			 (
				 @Guid,
				 @Name,
				 1,
				 @LanguageLabelID,
				 @EntityHobtID,
				 @EntityDateTypeID,
				 @IsReadOnly,
				 @IsImmutable,
				 @IsUppercase,
				 @IsHidden,
				 @IsCompulsory,
				 @MaxLength,
				 @Precision,
				 @Scale,
				 @DoNotTrackChanges,
				 @EntityPropertyGroupID,
				 @SortOrder,
				 @GroupSortOrder,
				 @IsObjectLabel,
				 @DropDownListDefinitionID,
				 @IsParentRelationship,
				 @IsIncludedInformation,
				 @IsLatitude,
				 @IsLongitude,
				 @FixDefaultValue,
				 @SqlDefaultValueStatement,
				 @AllowBulkChange,
				 @IsVirtual,
				 @ShowOnMobile,
				 @IsAlwaysVisibleInGroup,
				 @IsAlwaysVisibleInGroup_Mobile
			 );
	END;
	ELSE
	BEGIN
		UPDATE	SCore.EntityProperties
		SET		Name = @Name,
				RowStatus = @RowStatus,
				LanguageLabelID = @LanguageLabelID,
				EntityHoBTID = @EntityHobtID,
				EntityDataTypeID = @EntityDateTypeID,
				IsReadOnly = @IsReadOnly,
				IsImmutable = @IsImmutable,
				IsUppercase = @IsUppercase,
				IsHidden = @IsHidden,
				IsCompulsory = @IsCompulsory,
				MaxLength = @MaxLength,
				Precision = @Precision,
				Scale = @Scale,
				DoNotTrackChanges = @DoNotTrackChanges,
				EntityPropertyGroupID = @EntityPropertyGroupID,
				SortOrder = @SortOrder,
				GroupSortOrder = @GroupSortOrder,
				IsObjectLabel = @IsObjectLabel,
				DropDownListDefinitionID = @DropDownListDefinitionID,
				IsParentRelationship = @IsParentRelationship,
				IsIncludedInformation = @IsIncludedInformation,
				IsLongitude = @IsLongitude,
				IsLatitude = @IsLatitude,
				FixedDefaultValue = @FixDefaultValue,
				SqlDefaultValueStatement = @SqlDefaultValueStatement,
				AllowBulkChange = @AllowBulkChange,
				IsVirtual = @IsVirtual,
				ShowOnMobile = @ShowOnMobile,
				IsAlwaysVisibleInGroup = @IsAlwaysVisibleInGroup,
				IsAlwaysVisibleInGroup_Mobile = @IsAlwaysVisibleInGroup_Mobile
		WHERE	(Guid = @Guid);
	END;


END;
GO
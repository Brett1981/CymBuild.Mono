SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO



CREATE FUNCTION [SJob].[tvf_AssetMergeBatchValidate]
	(
		@SourceAssetGuid UNIQUEIDENTIFIER,
		@TargetAssetGuid UNIQUEIDENTIFIER,
		@CreatedByUserGuid UNIQUEIDENTIFIER,
		@CheckedByUserGuid UNIQUEIDENTIFIER,
		@IsComplete BIT,
		@Guid UNIQUEIDENTIFIER
	)
RETURNS @ValidationResult TABLE
	(
		ID INT IDENTITY(1, 1) NOT NULL,
		TargetGuid UNIQUEIDENTIFIER NOT NULL DEFAULT ('00000000-0000-0000-0000-000000000000'),
		TargetType CHAR(1) NOT NULL DEFAULT (''),
		IsReadOnly BIT NOT NULL DEFAULT ((0)),
		IsHidden BIT NOT NULL DEFAULT ((0)),
		IsInvalid BIT NOT NULL DEFAULT ((0)),
		[IsInformationOnly] [BIT] NOT NULL DEFAULT((0)),
		Message NVARCHAR(2000) NOT NULL DEFAULT ('')
	)
AS
BEGIN
	DECLARE @EntityPropertyGuid UNIQUEIDENTIFIER,
			@EntityTypeGuid UNIQUEIDENTIFIER,
			@CurrentUserGuid UNIQUEIDENTIFIER = SCore.GetCurrentUserGuid()

	SELECT	@EntityTypeGuid = et.Guid
	FROM	SCore.EntityTypes AS et
	WHERE	(et.Name = N'Asset Merge Batch')

	IF (@IsComplete = 1)
	BEGIN 
		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		VALUES
			 (
				 @EntityTypeGuid,
				 N'E',
				 1,
				 0,
				 0,
				 N''
			 );

		RETURN	
	END

	IF (@CreatedByUserGuid = @CurrentUserGuid)
	BEGIN 
		SELECT @EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'AssetMergeBatch', N'CheckedByUserId')

		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		VALUES
			 (
				 @EntityPropertyGuid,
				 N'P',
				 1,
				 0,
				 0,
				 N''
			 );
	END
	
	IF (@CreatedByUserGuid = @CheckedByUserGuid)
	BEGIN 
		SELECT @EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'AssetMergeBatch', N'CheckedByUserId')

		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		VALUES
			 (
				 @EntityPropertyGuid,
				 N'P',
				 0,
				 0,
				 1,
				 N'A different user must check the merge.'
			 );
	END
	
	IF (@TargetAssetGuid = @SourceAssetGuid)
	AND	(@SourceAssetGuid <> '00000000-0000-0000-0000-000000000000')
	BEGIN 
		SELECT @EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'AssetMergeBatch', N'SourceAssetId')

		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		VALUES
			 (
				 @EntityPropertyGuid,
				 N'P',
				 0,
				 0,
				 1,
				 N'The Source and Target Asset must be different.'
			 );

		SELECT @EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'AssetMergeBatch', N'TargetAssetId')

		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		VALUES
			 (
				 @EntityPropertyGuid,
				 N'P',
				 0,
				 0,
				 1,
				 N'The Source and Target Asset must be different.'
			 );
	END

	IF (EXISTS 
			(
				SELECT	1
				FROM	SCrm.AccountMergeBatch
				WHERE	(IsComplete = 1)
					AND	(Guid = @Guid)
			)
		)
	BEGIN 
		SELECT @EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'AssetMergeBatch', N'TargetAssetId')

		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		VALUES
			 (
				 @EntityPropertyGuid,
				 N'P',
				 1,
				 0,
				 1,
				 N''
			 );

		SELECT @EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'AssetMergeBatch', N'SourceAssetId')

		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		VALUES
			 (
				 @EntityPropertyGuid,
				 N'P',
				 1,
				 0,
				 1,
				 N''
			 );

		SELECT @EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SJob', N'AssetMergeBatch', N'CheckedByUserId')

		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		VALUES
			 (
				 @EntityPropertyGuid,
				 N'P',
				 1,
				 0,
				 1,
				 N''
			 );
	END
	
	RETURN;
END;

GO
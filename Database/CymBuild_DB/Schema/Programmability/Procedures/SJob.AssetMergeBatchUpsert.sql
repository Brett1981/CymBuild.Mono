SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO




CREATE PROCEDURE [SJob].[AssetMergeBatchUpsert]
	(	@SourceAssetGuid UNIQUEIDENTIFIER,
		@TargetAssetGuid UNIQUEIDENTIFIER,
		@CreatedByUserGuid UNIQUEIDENTIFIER,
		@CheckedByUserGuid UNIQUEIDENTIFIER,
		@Guid UNIQUEIDENTIFIER
	)
AS
BEGIN
	DECLARE @SourceAssetId INT,
			@TargetAssetId INT,
			@CreatedByUserId INT,
			@CheckedByUserId INT;

	SELECT	@SourceAssetId = ID
	FROM	SJob.Assets
	WHERE	(Guid = @SourceAssetGuid);

	SELECT	@TargetAssetId = ID
	FROM	Sjob.Assets
	WHERE	(Guid = @TargetAssetGuid);

	SELECT	@CreatedByUserId = ID
	FROM	SCore.Identities
	WHERE	(Guid = @CreatedByUserGuid);

	SELECT	@CheckedByUserId = ID
	FROM	SCore.Identities
	WHERE	(Guid = @CheckedByUserGuid);

	DECLARE @IsInsert BIT
    EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
							@IncludeDefaultSecurity = 0,
							@SchemeName = N'SJob',				-- nvarchar(255)
							@ObjectName = N'AssetMergeBatch',				-- nvarchar(255)
							@IsInsert = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
    BEGIN
		INSERT	SJob.AssetMergeBatch
			 (RowStatus, Guid, SourceAssetId, TargetAssetId, CreatedByUserId, CheckedByUserId, IsComplete)
		VALUES
			 (
				 1,					-- RowStatus - tinyint
				 @Guid,				-- Guid - uniqueidentifier
				 @SourceAssetId,	-- SourceAssetId - int
				 @TargetAssetId,	-- TargetAssetId - int
				 @CreatedByUserId,	-- CreatedByUserId - int
				 @CheckedByUserId,	-- CheckedByUserId - int
				 0					-- IsComplete - bit
			 );

	END;
	ELSE
	BEGIN
		UPDATE	SJob.AssetMergeBatch
		SET		SourceAssetId = @SourceAssetId,
				TargetAssetId = @TargetAssetId,
				CheckedByUserId = @CheckedByUserId
		WHERE	(Guid = @Guid);
	END;

	IF (@CheckedByUserId > -1)
	BEGIN
		EXEC SJob.MergeAssets @FromAssetGuid = @SourceAssetGuid,	-- uniqueidentifier
								@ToAssetGuid = @TargetAssetGuid;	-- uniqueidentifier

		UPDATE	SJob.AssetMergeBatch
		SET		IsComplete = 1
		WHERE	(Guid = @Guid);	
	END;

END;
GO
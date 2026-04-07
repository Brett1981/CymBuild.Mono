SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO





CREATE PROCEDURE [SJob].[AssetPossibleDuplicatesUpsert]
	(	@IsDifferent BIT,
		@IsDuplicate BIT,
		@Guid UNIQUEIDENTIFIER
	)
AS
BEGIN
	DECLARE @SourceAssetId INT,
			@TargetAssetId INT,
			@CreatedByUserId INT,
			@SourceDifferent BIT,
			@SourceDuplicate BIT;

	SELECT @CreatedByUserId = SCore.GetCurrentUserId()

	SELECT	@SourceAssetId = apd.SourceAssetId,
			@TargetAssetId = apd.TargetAssetID,
			@SourceDifferent = apd.IsDifferent,
			@SourceDuplicate = apd.IsDuplicate
	FROM	SJob.AssetPossibleDuplicates AS apd
	WHERE	(apd.Guid = @Guid)

	IF (@SourceDuplicate = 1) 
	BEGIN 
		-- Nothing to do
		RETURN
	END

	IF (@IsDifferent = 1 AND @IsDuplicate = 1)
	BEGIN 
		;THROW 60000, N'A suggestion cannot be different and a duplicate.', 1
	END

	UPDATE	SJob.AssetPossibleDuplicates
	SET		IsDifferent = @IsDifferent,
			IsDuplicate = @IsDuplicate
	WHERE	(Guid = @Guid)

	IF (@IsDuplicate = 1) 
	BEGIN 
		/* Create the merge batch record. */
		DECLARE @IsInsert BIT
		DECLARE	@MergeBatchGuid UNIQUEIDENTIFIER = NEWID()
		EXEC SCore.UpsertDataObject @Guid = @MergeBatchGuid,					-- uniqueidentifier
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
					 @MergeBatchGuid,				-- Guid - uniqueidentifier
					 @SourceAssetId,	-- SourceAssetId - int
					 @TargetAssetId,	-- TargetAssetId - int
					 @CreatedByUserId,	-- CreatedByUserId - int
					 ((-1)),	-- CheckedByUserId - int
					 0					-- IsComplete - bit
				 );

		END;
	END;

END;
GO
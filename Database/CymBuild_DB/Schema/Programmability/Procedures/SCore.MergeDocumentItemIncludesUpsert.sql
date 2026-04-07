SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO


CREATE PROCEDURE [SCore].[MergeDocumentItemIncludesUpsert] 
										   @MergeDocumentItemGuid UNIQUEIDENTIFIER,
										   @SortOrder INT,
										   @SourceDocumentEntityPropertyGuid UNIQUEIDENTIFIER,
										   @SourceSharePointItemEntityPropertyGuid UNIQUEIDENTIFIER,
										   @IncludedMergeDocumentGuid UNIQUEIDENTIFIER,
										   @Guid UNIQUEIDENTIFIER OUT
AS
BEGIN
	DECLARE @MergeDocumentItemID		INT,
			@SourceDocumentEntityPropertyID INT,
			@SourceSharePointItemEntityPropertyID INT,
			@IncludedMergeDocumentID	INT;

	SELECT	@MergeDocumentItemID = ID
	FROM	SCore.MergeDocumentItems AS mdi
	WHERE	(Guid = @MergeDocumentItemGuid);

	SELECT	@SourceDocumentEntityPropertyID = ID
	FROM	SCore.EntityProperties AS ep
	WHERE	(Guid = @SourceDocumentEntityPropertyGuid);

	SELECT	@SourceSharePointItemEntityPropertyID = ID
	FROM	SCore.EntityProperties AS ep
	WHERE	(Guid = @SourceSharePointItemEntityPropertyGuid);

	SELECT	@IncludedMergeDocumentID = ID
	FROM	SCore.MergeDocuments AS md
	WHERE	(Guid = @IncludedMergeDocumentGuid);


	DECLARE @IsInsert BIT = 0;
	EXEC SCore.UpsertDataObject @Guid = @Guid,						-- uniqueidentifier
								@SchemeName = N'SCore',				-- nvarchar(255)
								@ObjectName = N'MergeDocumentItemIncludes',	-- nvarchar(255)
								@IsInsert = @IsInsert OUTPUT;		-- bit

	IF (@IsInsert = 1)
	BEGIN
		INSERT	SCore.MergeDocumentItemIncludes
			 (Guid,
			  RowStatus,
			  MergeDocumentItemId,
			  SortOrder,
			  SourceDocumentEntityPropertyId,
			  SourceSharePointItemEntityPropertyId,
			  IncludedMergeDocumentId)
		VALUES
			 (
				 @Guid,	-- Guid - uniqueidentifier
				 1,	-- RowStatus - tinyint
				 @MergeDocumentItemID,	-- MergeDocumentItemId - int
				 @SortOrder,	-- SortOrder - int
				 @SourceDocumentEntityPropertyID,	-- SourceDocumentEntityPropertyId - int
				 @SourceSharePointItemEntityPropertyID,	-- SourceSharePointItemEntityPropertyId - int
				 @IncludedMergeDocumentID	-- IncludedMergeDocumentId - int
			 )

	END;
	ELSE
	BEGIN
		UPDATE	SCore.MergeDocumentItemIncludes
		SET		MergeDocumentItemId = @MergeDocumentItemID,
				SortOrder = @SortOrder,
				SourceDocumentEntityPropertyId = @SourceDocumentEntityPropertyID,
				SourceSharePointItemEntityPropertyId = @SourceSharePointItemEntityPropertyID,
				IncludedMergeDocumentId = @IncludedMergeDocumentID
		WHERE	(Guid = @Guid);
	END;
END;

GO
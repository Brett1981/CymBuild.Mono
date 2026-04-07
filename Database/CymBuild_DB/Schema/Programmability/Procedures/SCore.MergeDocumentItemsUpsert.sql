SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCore].[MergeDocumentItemsUpsert] 
										   @MergeDocumentGuid UNIQUEIDENTIFIER,
										   @MergeDocumentItemTypeGuid UNIQUEIDENTIFIER,
										   @BookmarkName NVARCHAR(50),
										   @EntityTypeGuid UNIQUEIDENTIFIER,
										   @SubFolderPath NVARCHAR(200),
										   @ImageColumns INT,
										   @Guid UNIQUEIDENTIFIER OUT
AS
BEGIN
	DECLARE @MergeDocumentID		INT,
			@MergeDocumentItemTypeID INT,
			@EntityTypeID	INT;

	SELECT	@MergeDocumentID = ID
	FROM	SCore.MergeDocuments AS md
	WHERE	(Guid = @MergeDocumentGuid);

	SELECT	@MergeDocumentItemTypeID = ID
	FROM	SCore.MergeDocumentItemTypes AS mdit
	WHERE	(Guid = @MergeDocumentItemTypeGuid);

	SELECT	@EntityTypeID = ID
	FROM	SCore.EntityTypes
	WHERE	(Guid = @EntityTypeGuid);

	DECLARE @IsInsert BIT = 0;
	EXEC SCore.UpsertDataObject @Guid = @Guid,						-- uniqueidentifier
								@SchemeName = N'SCore',				-- nvarchar(255)
								@ObjectName = N'MergeDocumentItems',	-- nvarchar(255)
								@IncludeDefaultSecurity = 0, -- bit
								@IsInsert = @IsInsert OUTPUT;		-- bit

	IF (@IsInsert = 1)
	BEGIN
		INSERT	SCore.MergeDocumentItems
			 (RowStatus, Guid, MergeDocumentId, MergeDocumentItemTypeId, BookmarkName, EntityTypeId, SubFolderPath, ImageColumns)
		VALUES
			 (
				 1,		-- RowStatus - tinyint
				 @Guid, -- Guid - uniqueidentifier
				 @MergeDocumentID,
				 @MergeDocumentItemTypeID,
				 @BookmarkName,
				 @EntityTypeID,
				 @SubFolderPath, 
				 @ImageColumns
			 );
	END;
	ELSE
	BEGIN
		UPDATE	SCore.MergeDocumentItems
		SET		MergeDocumentId = @MergeDocumentID,
				MergeDocumentItemTypeId = @MergeDocumentItemTypeID,
				BookmarkName = @BookmarkName,
				EntityTypeId = @EntityTypeID,
				SubFolderPath = @SubFolderPath,
				ImageColumns = @ImageColumns
		WHERE	(Guid = @Guid);
	END;
END;

GO
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCore].[MergeDocumentsUpsert] @Name NVARCHAR(250),
										   @FilenameTemplate NVARCHAR(250),
										   @EntityTypeGuid UNIQUEIDENTIFIER,
										   @SharepointSiteGuid UNIQUEIDENTIFIER,
										   @DocumentId NVARCHAR(500),
										   @LinkedEntityTypeGuid UNIQUEIDENTIFIER,
										   @AllowPDFOutputOnly BIT, 
										   @AllowExcelOutputOnly BIT, 
										   @ProduceOneOutputPerRow BIT,
										   @Guid UNIQUEIDENTIFIER OUT
AS
BEGIN
	DECLARE @EntityTypeID		INT,
			@LinkedEntityTypeID INT,
			@SharepointSiteId	INT;

	SELECT	@EntityTypeID = ID
	FROM	SCore.EntityTypes
	WHERE	(Guid = @EntityTypeGuid);

	SELECT	@LinkedEntityTypeID = ID
	FROM	SCore.EntityTypes
	WHERE	(Guid = @LinkedEntityTypeGuid);

	SELECT	@SharepointSiteId = ID
	FROM	SCore.SharepointSites
	WHERE	(Guid = @SharepointSiteGuid);

	DECLARE @IsInsert BIT = 0;
	EXEC SCore.UpsertDataObject @Guid = @Guid,						-- uniqueidentifier
								@SchemeName = N'SCore',				-- nvarchar(255)
								@ObjectName = N'MergeDocuments',	-- nvarchar(255)
								@IncludeDefaultSecurity = 0,
								@IsInsert = @IsInsert OUTPUT;		-- bit

	IF (@IsInsert = 1)
	BEGIN
		INSERT	SCore.MergeDocuments
			 (RowStatus, Guid, Name, FilenameTemplate, EntityTypeId, SharepointSiteId, DocumentId, LinkedEntityTypeId, AllowPDFOutputOnly, AllowExcelOutputOnly, ProduceOneOutputPerRow)
		VALUES
			 (
				 1,		-- RowStatus - tinyint
				 @Guid, -- Guid - uniqueidentifier
				 @Name,
				 @FilenameTemplate,
				 @EntityTypeID,
				 @SharepointSiteId,
				 @DocumentId,
				 @LinkedEntityTypeID,
				 @AllowPDFOutputOnly,
				 @AllowExcelOutputOnly,
				 @ProduceOneOutputPerRow
			 );
	END;
	ELSE
	BEGIN
		UPDATE	SCore.MergeDocuments
		SET		Name = @Name,
				FilenameTemplate = @FilenameTemplate,
				EntityTypeId = @EntityTypeID,
				SharepointSiteId = @SharepointSiteId,
				DocumentId = @DocumentId,
				LinkedEntityTypeId = @LinkedEntityTypeID,
				AllowPDFOutputOnly = @AllowPDFOutputOnly,
				AllowExcelOutputOnly = @AllowExcelOutputOnly,
				ProduceOneOutputPerRow = @ProduceOneOutputPerRow
		WHERE	(Guid = @Guid);
	END;
END;

GO
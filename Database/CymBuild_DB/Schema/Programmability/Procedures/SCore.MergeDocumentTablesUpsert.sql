SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCore].[MergeDocumentTablesUpsert] 
										   @MergeDocumentGuid UNIQUEIDENTIFIER,
										   @TableName NVARCHAR(50),
										   @LinkedEntityTypeGuid UNIQUEIDENTIFIER,
										   @Guid UNIQUEIDENTIFIER OUT
AS
BEGIN
	DECLARE @MergeDocumentID		INT,
			@LinkedEntityTypeID INT;

	SELECT	@MergeDocumentID = ID
	FROM	SCore.MergeDocuments md
	WHERE	(Guid = @MergeDocumentGuid);

	SELECT	@LinkedEntityTypeID = ID
	FROM	SCore.EntityTypes
	WHERE	(Guid = @LinkedEntityTypeGuid);

	DECLARE @IsInsert BIT = 0;
	EXEC SCore.UpsertDataObject @Guid = @Guid,						-- uniqueidentifier
								@SchemeName = N'SCore',				-- nvarchar(255)
								@ObjectName = N'MergeDocumentTables',	-- nvarchar(255)
								@IncludeDefaultSecurity = 0,
								@IsInsert = @IsInsert OUTPUT;		-- bit

	IF (@IsInsert = 1)
	BEGIN
		INSERT SCore.MergeDocumentTables 
	(
		RowStatus,
		Guid,
		MergeDocumentId,
		TableName,
		LinkedEntityTypeId
	)
VALUES
		(
			1,
			@Guid,
			@MergeDocumentID,
			@TableName,
			@LinkedEntityTypeID
		);
	END;
	ELSE
	BEGIN
		UPDATE	SCore.MergeDocumentTables
		SET		MergeDocumentId = @MergeDocumentID,
				TableName = @TableName,
				LinkedEntityTypeId = @LinkedEntityTypeID
		WHERE	(Guid = @Guid);
	END;
END;

GO
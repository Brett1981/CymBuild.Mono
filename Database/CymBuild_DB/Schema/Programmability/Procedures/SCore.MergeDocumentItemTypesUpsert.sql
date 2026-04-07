SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCore].[MergeDocumentItemTypesUpsert] 
										   @Name NVARCHAR(250),
										   @IsImageType BIT,
										   @Guid UNIQUEIDENTIFIER OUT
AS
BEGIN

	DECLARE @IsInsert BIT = 0;
	EXEC SCore.UpsertDataObject @Guid = @Guid,						-- uniqueidentifier
								@SchemeName = N'SCore',				-- nvarchar(255)
								@ObjectName = N'MergeDocumentItemTypes',	-- nvarchar(255)
								@IncludeDefaultSecurity = 0, -- bit
								@IsInsert = @IsInsert OUTPUT;		-- bit

	IF (@IsInsert = 1)
	BEGIN
		INSERT	SCore.MergeDocumentItemTypes
			 (RowStatus, Guid, Name, IsImageType)
		VALUES
			 (
				 1,		-- RowStatus - tinyint
				 @Guid, -- Guid - uniqueidentifier
				 @Name,
				 @IsImageType
			 );
	END;
	ELSE
	BEGIN
		UPDATE	SCore.MergeDocumentItemTypes
		SET		Name = @Name,
				IsImageType = @IsImageType
		WHERE	(Guid = @Guid);
	END;
END;

GO
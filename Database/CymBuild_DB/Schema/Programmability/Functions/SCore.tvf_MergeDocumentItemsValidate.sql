SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[tvf_MergeDocumentItemsValidate]
	(
		@MergeDocumentItemTypeId UNIQUEIDENTIFIER,
		@EntityTypeId UNIQUEIDENTIFIER, 
		@SubFolderPath NVARCHAR(MAX),
		@ImageColumns INT
	)
RETURNS @ValidationResult TABLE
	(
		ID INT IDENTITY(1, 1) NOT NULL,
		TargetGuid UNIQUEIDENTIFIER NOT NULL DEFAULT ('00000000-0000-0000-0000-000000000000'),
		TargetType CHAR(1) NOT NULL DEFAULT (''),
		IsReadOnly BIT NOT NULL DEFAULT ((0)),
		IsHidden BIT NOT NULL DEFAULT ((0)),
		IsInvalid BIT NOT NULL DEFAULT ((0)),
		IsInformationOnly BIT NOT NULL DEFAULT ((0)),
		Message NVARCHAR(2000) NOT NULL DEFAULT ('')
	)
AS
BEGIN
	
	-- Declare all possible types as variables for readability.
	DECLARE @DataTableType		UNIQUEIDENTIFIER	= '9F69CA42-52C1-44BD-A0DE-E9601664B5DC';
	DECLARE @ImageTableType		UNIQUEIDENTIFIER	= '94ABFB52-CBA2-4748-8F60-9A67A3F292D1';
	DECLARE @IncludesTableType  UNIQUEIDENTIFIER	= '16AC0BAB-D41C-4EDC-AC09-7BD871DB57B6'; 
	DECLARE @SignatureTableType UNIQUEIDENTIFIER    = '169566F4-9DA7-4B2A-A06B-3CD6AF6BEE5F';
	


	/*
		Data Table Item Type.

		Compulsory: Bookmark control name, merge document item type
		Hide: Image columns, Subfolder;
		 
	*/
	IF(@MergeDocumentItemTypeId = @DataTableType)
		BEGIN
			
			IF(@EntityTypeId = '00000000-0000-0000-0000-000000000000')
			BEGIN
				INSERT	@ValidationResult
					 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
				SELECT	epfvv.Guid,
						N'P',
						0,
						0,
						1,
						N'Entity type must be selected for Data Table Item type.'
				FROM	SCore.EntityPropertiesForValidationV AS epfvv
				WHERE	(epfvv.[Schema] = N'SCore')
					AND (epfvv.Hobt		= N'MergeDocumentItems')
					AND (epfvv.Name = N'EntityTypeId');
			END;


			INSERT	@ValidationResult
				 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
			SELECT	epfvv.Guid,
					N'P',
					0,
					1,
					0,
					N''
			FROM	SCore.EntityPropertiesForValidationV AS epfvv
			WHERE	(epfvv.[Schema] = N'SCore')
				AND (epfvv.Hobt		= N'MergeDocumentItems')
				AND (epfvv.Name IN (N'SubFolderPath', N'ImageColumns'));
		END;

	
	--Image Item Type.
	IF(@MergeDocumentItemTypeId = @ImageTableType)
		BEGIN
			IF(@SubFolderPath = '')
				BEGIN
					INSERT	@ValidationResult
							 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
						SELECT	epfvv.Guid,
								N'P',
								0,
								0,
								1,
								N'Subfolder Path must be provided for Image Table. (e.g. Activities)'
						FROM	SCore.EntityPropertiesForValidationV AS epfvv
						WHERE	(epfvv.[Schema] = N'SCore')
							AND (epfvv.Hobt		= N'MergeDocumentItems')
							AND (epfvv.Name = N'SubFolderPath');
				END;

			INSERT	@ValidationResult
				 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
			SELECT	epfvv.Guid,
					N'P',
					0,
					1,
					0,
					N''
			FROM	SCore.EntityPropertiesForValidationV AS epfvv
			WHERE	(epfvv.[Schema] = N'SCore')
				AND (epfvv.Hobt		= N'MergeDocumentItems')
				AND (epfvv.Name IN (N'EntityTypeId'));
		END;
	
	
	--Includes Item Type.
	IF(@MergeDocumentItemTypeId = @IncludesTableType)
		BEGIN

		INSERT	@ValidationResult
				 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
			SELECT	epfvv.Guid,
					N'P',
					0,
					1,
					0,
					N''
			FROM	SCore.EntityPropertiesForValidationV AS epfvv
			WHERE	(epfvv.[Schema] = N'SCore')
				AND (epfvv.Hobt		= N'MergeDocumentItems')
				AND (epfvv.Name IN (N'ImageColumns', N'SubFolderPath'));
		END;

	--Signature Item Type.
	IF(@MergeDocumentItemTypeId = @SignatureTableType)
		BEGIN

			IF(@EntityTypeId <> 'b123cd82-291e-4dd2-8bb4-c9e51302786d')
			BEGIN 
				INSERT	@ValidationResult
					 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
				SELECT	epfvv.Guid,
						N'P',
						0,
						0,
						1,
						N'For type "Signature", the entity type must be set to "Identities".'
				FROM	SCore.EntityPropertiesForValidationV AS epfvv
				WHERE	(epfvv.[Schema] = N'SCore')
					AND (epfvv.Hobt		= N'MergeDocumentItems')
					AND (epfvv.Name = N'EntityTypeId');
			END;

			INSERT	@ValidationResult
					 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
				SELECT	epfvv.Guid,
						N'P',
						0,
						1,
						0,
						N''
				FROM	SCore.EntityPropertiesForValidationV AS epfvv
				WHERE	(epfvv.[Schema] = N'SCore')
					AND (epfvv.Hobt		= N'MergeDocumentItems')
					AND (epfvv.Name IN (N'ImageColumns', N'SubFolderPath'));
		END;

	RETURN;
END;
GO
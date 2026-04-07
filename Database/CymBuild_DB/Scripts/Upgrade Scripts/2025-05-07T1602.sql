/*
Script created by SQL Prompt version 10.16.11.16409 from Red Gate Software Ltd at 07/05/2025 16:02:33
Run this script on Concursus_Dev to perform the Smart Rename refactoring.

Please back up your database before running this script.
*/
-- Summary for the smart rename:
--
-- Action:
-- Drop foreign key [FK_Properties_Properties] from table [SJob].[Assets]
-- Alter table [SJob].[Assets]
-- Alter procedure [SJob].[AssetsUpsert]
-- Refresh view [SJob].[Jobs_DWETL]
-- Refresh view [SJob].[Activity_Table_MergeInfo]
-- Refresh view [SSop].[Quotes_DWETL]
-- Refresh view [SSop].[Enquiry_MergeInfo]
-- Refresh view [SSop].[Quote_MergeInfo]
-- Refresh view [SJob].[Jobs_Read]
-- Refresh view [SJob].[Activity_MergeInfo]
-- Refresh view [SJob].[Job_MergeInfo]
-- Add foreign key to [SJob].[Assets]
-- Alter trigger [SJob].[tg_Properties_RecordHistory] on [SJob].[Assets]
--
-- No warnings
SET NUMERIC_ROUNDABORT OFF
GO
SET ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, ARITHABORT, QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
SET XACT_ABORT ON
GO
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE
GO
BEGIN TRANSACTION
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Dropping foreign keys from [SJob].[Assets]'
GO
ALTER TABLE [SJob].[Assets] DROP CONSTRAINT [FK_Properties_Properties]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SJob].[Assets]'
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
EXEC sp_rename N'[SJob].[Assets].[ParentPropertyID]', N'ParentAssetID', N'COLUMN'
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SJob].[AssetsUpsert]'
GO

CREATE OR ALTER PROCEDURE SJob.AssetsUpsert
	(	@ParentAssetGuid UNIQUEIDENTIFIER,
		@Name NVARCHAR(100),
		@Number NVARCHAR(50),
		@AddressLine1 NVARCHAR(50),
		@AddressLine2 NVARCHAR(50),
		@AddressLine3 NVARCHAR(50),
		@Town NVARCHAR(50),
		@CountyGuid UNIQUEIDENTIFIER,
		@Postcode NVARCHAR(50),
		@CountryGuid UNIQUEIDENTIFIER,
		@LocalAuthorityAccountGuid UNIQUEIDENTIFIER,
		@FireAuthorityAccountGuid UNIQUEIDENTIFIER,
		@WaterAuthorityAccountGuid UNIQUEIDENTIFIER,
		@Latitude DECIMAL(9, 6),
		@Longitude DECIMAL(9, 6),
		@IsHighRiskBuilding BIT,
		@IsComplexBuilding BIT,
		@BuildingHeightInMetres DECIMAL(9,2),
		@OwnerAccountGuid UNIQUEIDENTIFIER,
		@Guid UNIQUEIDENTIFIER
	)
AS
BEGIN
	DECLARE @ParentAssetID		 INT		  = -1,
			@LocalAuthorityAccountID INT,
			@FireAuthorityAccountID	 INT,
			@WaterAuthorityAccountID INT,
			@OwnerAccountID INT,	
			@FormattedAddressComma	 NVARCHAR(600),
			@FormattedAddressCR		 NVARCHAR(600),
			@IsInsert				 BIT		  = 0,
			@UPRN					 INT,
			@CountyID				 INT,
			@CountyName				 NVARCHAR(50),
			@CountryID				 INT;

	SELECT	@ParentAssetID = ID
	FROM	SJob.Assets
	WHERE	(Guid = @ParentAssetGuid);

	SELECT	@LocalAuthorityAccountID = ID
	FROM	SCrm.Accounts
	WHERE	(Guid = @LocalAuthorityAccountGuid);

	SELECT	@FireAuthorityAccountID = ID
	FROM	SCrm.Accounts
	WHERE	(Guid = @FireAuthorityAccountGuid);

	SELECT	@WaterAuthorityAccountID = ID
	FROM	SCrm.Accounts
	WHERE	(Guid = @WaterAuthorityAccountGuid);

	SELECT	@OwnerAccountID = ID
	FROM	SCrm.Accounts
	WHERE	(Guid = @OwnerAccountGuid);

	SELECT	@CountyID	= ID,
			@CountyName = Name
	FROM	SCrm.Counties
	WHERE	(Guid = @CountyGuid);

	SELECT	@CountryID = ID
	FROM	SCrm.Countries
	WHERE	(Guid = @CountryGuid);

	SELECT	@FormattedAddressComma = SCore.FormatAddress (	 N'',
															 @Number,
															 @AddressLine1,
															 @AddressLine2,
															 @AddressLine3,
															 @Town,
															 @CountyName,
															 @Postcode,
															 N', '
														 ),
			@FormattedAddressCR	   = SCore.FormatAddress (	 N'',
															 @Number,
															 @AddressLine1,
															 @AddressLine2,
															 @AddressLine3,
															 @Town,
															 @CountyName,
															 @Postcode,
															 CHAR (13)
														 );

    EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
							@SchemeName = N'SJob',				-- nvarchar(255)
							@ObjectName = N'Properties',				-- nvarchar(255)
							@IncludeDefaultSecurity = 0,
							@IsInsert = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
    BEGIN

		INSERT	SJob.Assets
			 (RowStatus,
			  Guid,
			  ParentAssetID,
			  Name,
			  Number,
			  AddressLine1,
			  AddressLine2,
			  AddressLine3,
			  Town,
			  CountyId,
			  Postcode,
			  CountryId,
			  LocalAuthorityAccountID,
			  WaterAuthorityAccountID,
			  FireAuthorityAccountID,
			  FormattedAddressComma,
			  FormattedAddressCR,
			  Latitude,
			  Longitude,
			  IsHighRiskBuilding,
			  IsComplexBuilding,
			  BuildingHeightInMetres,
			  OwnerAccountId)
		VALUES
			 (
				 0,
				 @Guid,
				 @ParentAssetID,
				 @Name,
				 @Number,
				 @AddressLine1,
				 @AddressLine2,
				 @AddressLine3,
				 @Town,
				 @CountyID,
				 @Postcode,
				 @CountryID,
				 @LocalAuthorityAccountID,
				 @WaterAuthorityAccountID,
				 @FireAuthorityAccountID,
				 @FormattedAddressComma,
				 @FormattedAddressCR,
				 @Latitude,
				 @Longitude,
				 @IsHighRiskBuilding,
				 @IsComplexBuilding,
				 @BuildingHeightInMetres,
				 @OwnerAccountID
			 );
	END;
	ELSE
	BEGIN
		UPDATE	SJob.Assets
		SET		ParentAssetID = @ParentAssetID,
				Name = @Name,
				Number = @Number,
				AddressLine1 = @AddressLine1,
				AddressLine2 = @AddressLine2,
				AddressLine3 = @AddressLine3,
				Town = @Town,
				CountyId = @CountyID,
				Postcode = @Postcode,
				@CountryID = @CountryID,
				LocalAuthorityAccountID = @LocalAuthorityAccountID,
				WaterAuthorityAccountID = @WaterAuthorityAccountID,
				FireAuthorityAccountID = @FireAuthorityAccountID,
				FormattedAddressComma = @FormattedAddressComma,
				FormattedAddressCR = @FormattedAddressCR,
				Latitude = @Latitude,
				Longitude = @Longitude,
				IsHighRiskBuilding = @IsHighRiskBuilding,
				IsComplexBuilding = @IsComplexBuilding,
				BuildingHeightInMetres = @BuildingHeightInMetres,
				OwnerAccountId = @OwnerAccountID
		WHERE	(Guid = @Guid);
	END;

	IF (@IsInsert = 1)
	BEGIN
		SELECT	@UPRN = NEXT VALUE FOR SJob.UPRN;

		UPDATE	SJob.Assets
		SET		UPRN = @UPRN,
				RowStatus = 1
		WHERE	(Guid = @Guid);
	END;

	/* Tempoary addition until have have the System Bus */

	DECLARE @FilingObjectName NVARCHAR(250),
			@FilingLocation	  NVARCHAR(MAX);

	SELECT	@FilingLocation =
			(
				SELECT ss.SiteIdentifier,
					spf.FolderPath
				FROM	SCore.ObjectSharePointFolder AS spf
				JOIN	SCore.SharepointSites ss ON (ss.ID = spf.SharepointSiteId)
				WHERE	(spf.ObjectGuid = @Guid)
				FOR JSON PATH
			);

	SELECT	@FilingObjectName = p.Name + N' ' + p.FormattedAddressComma,
			@UPRN			  = p.UPRN
	FROM	SJob.Assets AS p
	WHERE	(p.Guid = @Guid);

	EXEC SOffice.TargetObjectUpsert @EntityTypeGuid = N'2cfbff39-93cd-436b-b8ca-b2fcf7609707',	-- uniqueidentifier
									@RecordGuid = @Guid,										-- uniqueidentifier
									@Number = @UPRN,										-- bigint
									@Name = @FilingObjectName,									-- nvarchar(250)
									@FilingLocation = @FilingLocation

END;
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Refreshing [SJob].[Jobs_DWETL]'
GO
EXEC sp_refreshview N'[SJob].[Jobs_DWETL]'
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Refreshing [SJob].[Activity_Table_MergeInfo]'
GO
EXEC sp_refreshview N'[SJob].[Activity_Table_MergeInfo]'
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Refreshing [SSop].[Quotes_DWETL]'
GO
EXEC sp_refreshview N'[SSop].[Quotes_DWETL]'
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Refreshing [SSop].[Enquiry_MergeInfo]'
GO
EXEC sp_refreshview N'[SSop].[Enquiry_MergeInfo]'
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Refreshing [SSop].[Quote_MergeInfo]'
GO
EXEC sp_refreshview N'[SSop].[Quote_MergeInfo]'
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Refreshing [SJob].[Jobs_Read]'
GO
EXEC sp_refreshview N'[SJob].[Jobs_Read]'
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Refreshing [SJob].[Activity_MergeInfo]'
GO
EXEC sp_refreshview N'[SJob].[Activity_MergeInfo]'
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Refreshing [SJob].[Job_MergeInfo]'
GO
EXEC sp_refreshview N'[SJob].[Job_MergeInfo]'
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Adding foreign keys to [SJob].[Assets]'
GO
ALTER TABLE [SJob].[Assets] ADD CONSTRAINT [FK_Properties_Properties] FOREIGN KEY ([ParentAssetID]) REFERENCES [SJob].[Assets] ([ID])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering trigger [SJob].[tg_Properties_RecordHistory] on [SJob].[Assets]'
GO
ALTER TRIGGER SJob.tg_Properties_RecordHistory
   ON  [SJob].[Assets]	
   AFTER INSERT, UPDATE
AS 
BEGIN
	SET NOCOUNT ON;

    IF (ISNULL(CONVERT(int, SESSION_CONTEXT(N'S_disable_triggers')), 0) = 1)
    BEGIN 
        RETURN
    END

	IF (EXISTS
			(
				SELECT	1
				FROM	Inserted
				WHERE	(ID = -1) 
			)
		)
	BEGIN 
		;THROW 60000, N'Data integrity exception: Attempt to alter -1 record', 1
	END

    DECLARE	@PreviousValue NVARCHAR(MAX),
			@NewValue NVARCHAR(MAX),
			@UserID INT = 0,
			@SchemaName NVARCHAR(250) = N'SJob',
			@TableName NVARCHAR(250) = N'Properties',
			@ColumnName NVARCHAR(250),
			@MaxInsertedID BIGINT,
			@CurrentInsertedID BIGINT,
			@CurrentInsertedGuid UNIQUEIDENTIFIER

	SELECT @UserID = ISNULL(CONVERT(int, SESSION_CONTEXT(N'user_id')), -1)

	SELECT	@MaxInsertedID = MAX([ID]),
			@CurrentInsertedID = -1
	FROM	Inserted

	WHILE	(@CurrentInsertedID < @MaxInsertedID)
	BEGIN 
		SELECT	TOP(1) @CurrentInsertedID = i.[ID],
				@CurrentInsertedGuid = i.Guid
		FROM	Inserted i
		WHERE	(i.[ID] > @CurrentInsertedID)
			ORDER BY i.[ID]
		
		
		
		IF (NOT EXISTS 
				(
					SELECT	1
					FROM 	deleted d
					WHERE	(d.[ID] = @CurrentInsertedID)
				)
			)
		BEGIN 
				
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, N'', N'', SYSTEM_USER, -1)
	
			RETURN 
		END
		
		SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RowStatus]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RowStatus]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RowStatus] IS DISTINCT FROM i.[RowStatus])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 248)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[UPRN]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[UPRN]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[UPRN] IS DISTINCT FROM i.[UPRN])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'UPRN', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 251)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.ParentAssetID), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.ParentAssetID), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.ParentAssetID IS DISTINCT FROM i.ParentAssetID)


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ParentPropertyID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 252)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[CreatedDate]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[CreatedDate]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[CreatedDate] IS DISTINCT FROM i.[CreatedDate])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'CreatedDate', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 253)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Name]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Name]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Name] IS DISTINCT FROM i.[Name])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Name', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 254)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Number]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Number]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Number] IS DISTINCT FROM i.[Number])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Number', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 255)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[AddressLine1]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[AddressLine1]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[AddressLine1] IS DISTINCT FROM i.[AddressLine1])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'AddressLine1', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 256)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[AddressLine2]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[AddressLine2]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[AddressLine2] IS DISTINCT FROM i.[AddressLine2])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'AddressLine2', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 257)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[AddressLine3]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[AddressLine3]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[AddressLine3] IS DISTINCT FROM i.[AddressLine3])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'AddressLine3', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 258)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Town]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Town]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Town] IS DISTINCT FROM i.[Town])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Town', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 259)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Postcode]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Postcode]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Postcode] IS DISTINCT FROM i.[Postcode])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Postcode', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 261)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[LocalAuthorityAccountID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[LocalAuthorityAccountID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[LocalAuthorityAccountID] IS DISTINCT FROM i.[LocalAuthorityAccountID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'LocalAuthorityAccountID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 262)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[FireAuthorityAccountID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[FireAuthorityAccountID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[FireAuthorityAccountID] IS DISTINCT FROM i.[FireAuthorityAccountID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'FireAuthorityAccountID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 263)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[WaterAuthorityAccountID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[WaterAuthorityAccountID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[WaterAuthorityAccountID] IS DISTINCT FROM i.[WaterAuthorityAccountID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'WaterAuthorityAccountID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 264)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[FormattedAddressComma]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[FormattedAddressComma]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[FormattedAddressComma] IS DISTINCT FROM i.[FormattedAddressComma])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'FormattedAddressComma', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 265)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[FormattedAddressCR]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[FormattedAddressCR]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[FormattedAddressCR] IS DISTINCT FROM i.[FormattedAddressCR])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'FormattedAddressCR', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 266)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Latitude]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Latitude]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Latitude] IS DISTINCT FROM i.[Latitude])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Latitude', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 267)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Longitude]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Longitude]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Longitude] IS DISTINCT FROM i.[Longitude])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Longitude', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 268)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[BuildingHeightInMetres]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[BuildingHeightInMetres]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[BuildingHeightInMetres] IS DISTINCT FROM i.[BuildingHeightInMetres])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'BuildingHeightInMetres', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1027)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[CountryId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[CountryId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[CountryId] IS DISTINCT FROM i.[CountryId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'CountryId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1028)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[CountyId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[CountyId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[CountyId] IS DISTINCT FROM i.[CountyId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'CountyId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1029)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[IsComplexBuilding]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[IsComplexBuilding]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[IsComplexBuilding] IS DISTINCT FROM i.[IsComplexBuilding])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsComplexBuilding', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1030)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[IsHighRiskBuilding]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[IsHighRiskBuilding]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[IsHighRiskBuilding] IS DISTINCT FROM i.[IsHighRiskBuilding])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsHighRiskBuilding', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1031)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ListLabel]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ListLabel]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ListLabel] IS DISTINCT FROM i.[ListLabel])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ListLabel', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1675)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[OwnerAccountId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[OwnerAccountId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[OwnerAccountId] IS DISTINCT FROM i.[OwnerAccountId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'OwnerAccountId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1676)
			END 
			
			
			END
		END
		
		
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
COMMIT TRANSACTION
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
-- This statement writes to the SQL Server Log so SQL Monitor can show this deployment.
IF HAS_PERMS_BY_NAME(N'sys.xp_logevent', N'OBJECT', N'EXECUTE') = 1
BEGIN
    DECLARE @databaseName AS nvarchar(2048), @eventMessage AS nvarchar(2048)
    SET @databaseName = REPLACE(REPLACE(DB_NAME(), N'\', N'\\'), N'"', N'\"')
    SET @eventMessage = N'Redgate SQL Compare: { "deployment": { "description": "Redgate SQL Compare deployed to ' + @databaseName + N'", "database": "' + @databaseName + N'" }}'
    EXECUTE sys.xp_logevent 55000, @eventMessage
END
GO
DECLARE @Success AS BIT
SET @Success = 1
SET NOEXEC OFF
IF (@Success = 1) PRINT 'The database update succeeded'
ELSE BEGIN
	IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
	PRINT 'The database update failed'
END
GO

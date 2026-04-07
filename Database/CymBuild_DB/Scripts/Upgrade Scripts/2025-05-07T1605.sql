/*
Script created by SQL Prompt version 10.16.11.16409 from Red Gate Software Ltd at 07/05/2025 16:03:59
Run this script on Concursus_Dev to perform the Smart Rename refactoring.

Please back up your database before running this script.
*/
-- Summary for the smart rename:
--
-- Action:
-- Drop foreign key [FK_Properties_Accounts] from table [SJob].[Assets]
-- Drop foreign key [FK_Properties_Accounts1] from table [SJob].[Assets]
-- Drop foreign key [FK_Properties_Accounts2] from table [SJob].[Assets]
-- Drop foreign key [FK_Properties_Accounts3] from table [SJob].[Assets]
-- Drop foreign key [FK_Properties_Counties] from table [SJob].[Assets]
-- Drop foreign key [FK_Properties_Countries] from table [SJob].[Assets]
-- Drop foreign key [FK_Properties_DataObjects] from table [SJob].[Assets]
-- Drop foreign key [FK_Properties_Properties] from table [SJob].[Assets]
-- Drop foreign key [FK_Properties_RowStatus] from table [SJob].[Assets]
-- Drop foreign key [FK_Jobs_Properties] from table [SJob].[Jobs]
-- Drop foreign key [FK_Enquiries_Properties] from table [SSop].[Enquiries]
-- Drop foreign key [FK_Quotes_Properties] from table [SSop].[Quotes]
-- Drop primary key [PK_Properties] from table [SJob].[Assets]
-- Drop default DEFAULT_Properties_RowStatus from column [RowStatus] on table [SJob].[Assets]
-- Drop default DEFAULT_Properties_Guid from column [Guid] on table [SJob].[Assets]
-- Drop default DEFAULT_Properties_UPRN from column [UPRN] on table [SJob].[Assets]
-- Drop default DEFAULT_Properties_ParentPropertyID from column [ParentAssetID] on table [SJob].[Assets]
-- Drop default DEFAULT_Properties_CreatedDate from column [CreatedDate] on table [SJob].[Assets]
-- Drop default DEFAULT_Properties_Name from column [Name] on table [SJob].[Assets]
-- Drop default DEFAULT_Properties_Number from column [Number] on table [SJob].[Assets]
-- Drop default DEFAULT_Properties_AddressLine1 from column [AddressLine1] on table [SJob].[Assets]
-- Drop default DEFAULT_Properties_AddressLine2 from column [AddressLine2] on table [SJob].[Assets]
-- Drop default DEFAULT_Properties_AddressLine3 from column [AddressLine3] on table [SJob].[Assets]
-- Drop default DEFAULT_Properties_Town from column [Town] on table [SJob].[Assets]
-- Drop default DEFAULT_Properties_Postcode from column [Postcode] on table [SJob].[Assets]
-- Drop default DEFAULT_Properties_LocalAuthorityAccountID from column [LocalAuthorityAccountID] on table [SJob].[Assets]
-- Drop default DEFAULT_Properties_FireAuthorityAccountID from column [FireAuthorityAccountID] on table [SJob].[Assets]
-- Drop default DEFAULT_Properties_WaterAuthorityAccountID from column [WaterAuthorityAccountID] on table [SJob].[Assets]
-- Drop default DEFAULT_Properties_FormattedAddressComma from column [FormattedAddressComma] on table [SJob].[Assets]
-- Drop default DEFAULT_Properties_FormattedAddressCR from column [FormattedAddressCR] on table [SJob].[Assets]
-- Drop default DEFAULT_Properties_Latitude from column [Latitude] on table [SJob].[Assets]
-- Drop default DEFAULT_Properties_Longitude from column [Longitude] on table [SJob].[Assets]
-- Drop default DF_Properties_IsHighRiskBuilding from column [IsHighRiskBuilding] on table [SJob].[Assets]
-- Drop default DF_Properties_IsComplexBuilding from column [IsComplexBuilding] on table [SJob].[Assets]
-- Drop default DF_Properties_BuildingHeightInMetres from column [BuildingHeightInMetres] on table [SJob].[Assets]
-- Drop default DF_Properties_CountyId from column [CountyId] on table [SJob].[Assets]
-- Drop default DF_Properties_CountryId from column [CountryId] on table [SJob].[Assets]
-- Drop default DF_Properties_OwnerAccountId from column [OwnerAccountId] on table [SJob].[Assets]
-- Drop default DF__Propertie__Legac__1078CCC7 from column [LegacySystemID] on table [SJob].[Assets]
-- Drop index [IX_UPRN_List] from [SJob].[Assets]
-- Drop index [IX_UQ_Properties_Guid] from [SJob].[Assets]
-- Drop index [IX_UQ_Properties_URPN] from [SJob].[Assets]
-- Drop trigger [SJob].[tg_Properties_RecordHistory] from [SJob].[Assets]
-- Rebuild table [SJob].[Assets]
-- Create primary key [PK_Properties] on [SJob].[Assets]
-- Create index [IX_UQ_Properties_Guid] on [SJob].[Assets]
-- Create index [IX_UPRN_List] on [SJob].[Assets]
-- Create index [IX_UQ_Properties_URPN] on [SJob].[Assets]
-- Create trigger [SJob].[tg_Properties_RecordHistory] on [SJob].[Assets]
-- Alter procedure [SJob].[AssetsUpsert]
-- Alter function [SJob].[tvf_Assets]
-- Alter function [SSop].[tvf_Enquiries]
-- Alter function [SSop].[tvf_OpenEnquiries]
-- Add foreign key to [SJob].[Assets]
-- Add foreign key to [SJob].[Assets]
-- Add foreign key to [SJob].[Assets]
-- Add foreign key to [SJob].[Assets]
-- Add foreign key to [SJob].[Assets]
-- Add foreign key to [SJob].[Assets]
-- Add foreign key to [SJob].[Assets]
-- Add foreign key to [SJob].[Assets]
-- Add foreign key to [SJob].[Assets]
-- Add foreign key to [SSop].[Enquiries]
-- Add foreign key to [SJob].[Jobs]
-- Add foreign key to [SSop].[Quotes]
-- Disable foreign key [FK_Properties_DataObjects] on table [SJob].[Assets]
--
-- Warnings:
-- Medium: Cannot alter column [ListLabel] AS ((CONVERT([nvarchar](100),[Uprn],(0))+N' - ')+[FormattedAddressComma]) PERSISTED to [ListLabel] AS ((CONVERT([nvarchar](100),AssetNumber,(0))+N' - ')+[FormattedAddressComma]) PERSISTED on table [SJob].[Assets]. The table must be rebuilt. The data in the table apart from dropped columns will be preserved.
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
ALTER TABLE [SJob].[Assets] DROP CONSTRAINT [FK_Properties_Accounts]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
ALTER TABLE [SJob].[Assets] DROP CONSTRAINT [FK_Properties_Accounts1]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
ALTER TABLE [SJob].[Assets] DROP CONSTRAINT [FK_Properties_Accounts2]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
ALTER TABLE [SJob].[Assets] DROP CONSTRAINT [FK_Properties_Accounts3]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
ALTER TABLE [SJob].[Assets] DROP CONSTRAINT [FK_Properties_Counties]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
ALTER TABLE [SJob].[Assets] DROP CONSTRAINT [FK_Properties_Countries]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
ALTER TABLE [SJob].[Assets] DROP CONSTRAINT [FK_Properties_DataObjects]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
ALTER TABLE [SJob].[Assets] DROP CONSTRAINT [FK_Properties_Properties]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
ALTER TABLE [SJob].[Assets] DROP CONSTRAINT [FK_Properties_RowStatus]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Dropping foreign keys from [SJob].[Jobs]'
GO
ALTER TABLE [SJob].[Jobs] DROP CONSTRAINT [FK_Jobs_Properties]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Dropping foreign keys from [SSop].[Enquiries]'
GO
ALTER TABLE [SSop].[Enquiries] DROP CONSTRAINT [FK_Enquiries_Properties]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Dropping foreign keys from [SSop].[Quotes]'
GO
ALTER TABLE [SSop].[Quotes] DROP CONSTRAINT [FK_Quotes_Properties]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Dropping constraints from [SJob].[Assets]'
GO
ALTER TABLE [SJob].[Assets] DROP CONSTRAINT [PK_Properties]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Dropping constraints from [SJob].[Assets]'
GO
ALTER TABLE [SJob].[Assets] DROP CONSTRAINT [DEFAULT_Properties_RowStatus]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Dropping constraints from [SJob].[Assets]'
GO
ALTER TABLE [SJob].[Assets] DROP CONSTRAINT [DEFAULT_Properties_Guid]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Dropping constraints from [SJob].[Assets]'
GO
ALTER TABLE [SJob].[Assets] DROP CONSTRAINT [DEFAULT_Properties_UPRN]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Dropping constraints from [SJob].[Assets]'
GO
ALTER TABLE [SJob].[Assets] DROP CONSTRAINT [DEFAULT_Properties_ParentPropertyID]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Dropping constraints from [SJob].[Assets]'
GO
ALTER TABLE [SJob].[Assets] DROP CONSTRAINT [DEFAULT_Properties_CreatedDate]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Dropping constraints from [SJob].[Assets]'
GO
ALTER TABLE [SJob].[Assets] DROP CONSTRAINT [DEFAULT_Properties_Name]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Dropping constraints from [SJob].[Assets]'
GO
ALTER TABLE [SJob].[Assets] DROP CONSTRAINT [DEFAULT_Properties_Number]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Dropping constraints from [SJob].[Assets]'
GO
ALTER TABLE [SJob].[Assets] DROP CONSTRAINT [DEFAULT_Properties_AddressLine1]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Dropping constraints from [SJob].[Assets]'
GO
ALTER TABLE [SJob].[Assets] DROP CONSTRAINT [DEFAULT_Properties_AddressLine2]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Dropping constraints from [SJob].[Assets]'
GO
ALTER TABLE [SJob].[Assets] DROP CONSTRAINT [DEFAULT_Properties_AddressLine3]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Dropping constraints from [SJob].[Assets]'
GO
ALTER TABLE [SJob].[Assets] DROP CONSTRAINT [DEFAULT_Properties_Town]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Dropping constraints from [SJob].[Assets]'
GO
ALTER TABLE [SJob].[Assets] DROP CONSTRAINT [DEFAULT_Properties_Postcode]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Dropping constraints from [SJob].[Assets]'
GO
ALTER TABLE [SJob].[Assets] DROP CONSTRAINT [DEFAULT_Properties_LocalAuthorityAccountID]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Dropping constraints from [SJob].[Assets]'
GO
ALTER TABLE [SJob].[Assets] DROP CONSTRAINT [DEFAULT_Properties_FireAuthorityAccountID]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Dropping constraints from [SJob].[Assets]'
GO
ALTER TABLE [SJob].[Assets] DROP CONSTRAINT [DEFAULT_Properties_WaterAuthorityAccountID]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Dropping constraints from [SJob].[Assets]'
GO
ALTER TABLE [SJob].[Assets] DROP CONSTRAINT [DEFAULT_Properties_FormattedAddressComma]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Dropping constraints from [SJob].[Assets]'
GO
ALTER TABLE [SJob].[Assets] DROP CONSTRAINT [DEFAULT_Properties_FormattedAddressCR]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Dropping constraints from [SJob].[Assets]'
GO
ALTER TABLE [SJob].[Assets] DROP CONSTRAINT [DEFAULT_Properties_Latitude]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Dropping constraints from [SJob].[Assets]'
GO
ALTER TABLE [SJob].[Assets] DROP CONSTRAINT [DEFAULT_Properties_Longitude]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Dropping constraints from [SJob].[Assets]'
GO
ALTER TABLE [SJob].[Assets] DROP CONSTRAINT [DF_Properties_IsHighRiskBuilding]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Dropping constraints from [SJob].[Assets]'
GO
ALTER TABLE [SJob].[Assets] DROP CONSTRAINT [DF_Properties_IsComplexBuilding]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Dropping constraints from [SJob].[Assets]'
GO
ALTER TABLE [SJob].[Assets] DROP CONSTRAINT [DF_Properties_BuildingHeightInMetres]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Dropping constraints from [SJob].[Assets]'
GO
ALTER TABLE [SJob].[Assets] DROP CONSTRAINT [DF_Properties_CountyId]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Dropping constraints from [SJob].[Assets]'
GO
ALTER TABLE [SJob].[Assets] DROP CONSTRAINT [DF_Properties_CountryId]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Dropping constraints from [SJob].[Assets]'
GO
ALTER TABLE [SJob].[Assets] DROP CONSTRAINT [DF_Properties_OwnerAccountId]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Dropping constraints from [SJob].[Assets]'
GO
ALTER TABLE [SJob].[Assets] DROP CONSTRAINT [DF__Propertie__Legac__4106F589]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Dropping index [IX_UPRN_List] from [SJob].[Assets]'
GO
DROP INDEX [IX_UPRN_List] ON [SJob].[Assets]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Dropping index [IX_UQ_Properties_Guid] from [SJob].[Assets]'
GO
DROP INDEX [IX_UQ_Properties_Guid] ON [SJob].[Assets]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Dropping index [IX_UQ_Properties_URPN] from [SJob].[Assets]'
GO
DROP INDEX [IX_UQ_Properties_URPN] ON [SJob].[Assets]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Dropping trigger [SJob].[tg_Properties_RecordHistory] from [SJob].[Assets]'
GO
DROP TRIGGER [SJob].[tg_Properties_RecordHistory]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Rebuilding [SJob].[Assets]'
GO
CREATE TABLE [SJob].[RG_Recovery_1_Assets]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[RowStatus] [tinyint] NOT NULL CONSTRAINT [DEFAULT_Properties_RowStatus] DEFAULT ((0)),
[RowVersion] [timestamp] NOT NULL,
[Guid] [uniqueidentifier] NOT NULL ROWGUIDCOL CONSTRAINT [DEFAULT_Properties_Guid] DEFAULT (newid()),
[AssetNumber] [int] NOT NULL CONSTRAINT [DEFAULT_Properties_UPRN] DEFAULT ((0)),
[ParentAssetID] [int] NOT NULL CONSTRAINT [DEFAULT_Properties_ParentPropertyID] DEFAULT ((-1)),
[CreatedDate] [datetime2] NOT NULL CONSTRAINT [DEFAULT_Properties_CreatedDate] DEFAULT (getutcdate()),
[Name] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DEFAULT_Properties_Name] DEFAULT (''),
[Number] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DEFAULT_Properties_Number] DEFAULT (''),
[AddressLine1] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DEFAULT_Properties_AddressLine1] DEFAULT (''),
[AddressLine2] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DEFAULT_Properties_AddressLine2] DEFAULT (''),
[AddressLine3] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DEFAULT_Properties_AddressLine3] DEFAULT (''),
[Town] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DEFAULT_Properties_Town] DEFAULT (''),
[Postcode] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DEFAULT_Properties_Postcode] DEFAULT (''),
[LocalAuthorityAccountID] [int] NOT NULL CONSTRAINT [DEFAULT_Properties_LocalAuthorityAccountID] DEFAULT ((-1)),
[FireAuthorityAccountID] [int] NOT NULL CONSTRAINT [DEFAULT_Properties_FireAuthorityAccountID] DEFAULT ((-1)),
[WaterAuthorityAccountID] [int] NOT NULL CONSTRAINT [DEFAULT_Properties_WaterAuthorityAccountID] DEFAULT ((-1)),
[FormattedAddressComma] [nvarchar] (600) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DEFAULT_Properties_FormattedAddressComma] DEFAULT (''),
[FormattedAddressCR] [nvarchar] (600) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DEFAULT_Properties_FormattedAddressCR] DEFAULT (''),
[Latitude] [decimal] (9, 6) NOT NULL CONSTRAINT [DEFAULT_Properties_Latitude] DEFAULT ((0)),
[Longitude] [decimal] (9, 6) NOT NULL CONSTRAINT [DEFAULT_Properties_Longitude] DEFAULT ((0)),
[IsHighRiskBuilding] [bit] NOT NULL CONSTRAINT [DF_Properties_IsHighRiskBuilding] DEFAULT ((0)),
[IsComplexBuilding] [bit] NOT NULL CONSTRAINT [DF_Properties_IsComplexBuilding] DEFAULT ((0)),
[BuildingHeightInMetres] [decimal] (9, 2) NOT NULL CONSTRAINT [DF_Properties_BuildingHeightInMetres] DEFAULT ((0)),
[CountyId] [int] NOT NULL CONSTRAINT [DF_Properties_CountyId] DEFAULT ((-1)),
[CountryId] [int] NOT NULL CONSTRAINT [DF_Properties_CountryId] DEFAULT ((-1)),
[ListLabel] AS ((CONVERT([nvarchar](100),AssetNumber,(0))+N' - ')+[FormattedAddressComma]) PERSISTED,
[OwnerAccountId] [int] NOT NULL CONSTRAINT [DF_Properties_OwnerAccountId] DEFAULT ((-1)),
[LegacyID] [int] NULL,
[LegacySystemID] [int] NOT NULL CONSTRAINT [DF__Propertie__Legac__1078CCC7] DEFAULT ((-1))
) ON [PRIMARY]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
SET IDENTITY_INSERT [SJob].[RG_Recovery_1_Assets] ON
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
INSERT INTO [SJob].[RG_Recovery_1_Assets]([ID], [RowStatus], [Guid], [AssetNumber], [ParentAssetID], [CreatedDate], [Name], [Number], [AddressLine1], [AddressLine2], [AddressLine3], [Town], [Postcode], [LocalAuthorityAccountID], [FireAuthorityAccountID], [WaterAuthorityAccountID], [FormattedAddressComma], [FormattedAddressCR], [Latitude], [Longitude], [IsHighRiskBuilding], [IsComplexBuilding], [BuildingHeightInMetres], [CountyId], [CountryId], [OwnerAccountId], [LegacyID], [LegacySystemID]) SELECT [ID], [RowStatus], [Guid], [UPRN], [ParentAssetID], [CreatedDate], [Name], [Number], [AddressLine1], [AddressLine2], [AddressLine3], [Town], [Postcode], [LocalAuthorityAccountID], [FireAuthorityAccountID], [WaterAuthorityAccountID], [FormattedAddressComma], [FormattedAddressCR], [Latitude], [Longitude], [IsHighRiskBuilding], [IsComplexBuilding], [BuildingHeightInMetres], [CountyId], [CountryId], [OwnerAccountId], [LegacyID], [LegacySystemID] FROM [SJob].[Assets]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
SET IDENTITY_INSERT [SJob].[RG_Recovery_1_Assets] OFF
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
DECLARE @idVal BIGINT
SELECT @idVal = IDENT_CURRENT(N'[SJob].[Assets]')
IF @idVal IS NOT NULL
    DBCC CHECKIDENT(N'[SJob].[RG_Recovery_1_Assets]', RESEED, @idVal)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
DROP TABLE [SJob].[Assets]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
EXEC sp_rename N'[SJob].[RG_Recovery_1_Assets]', N'Assets', N'OBJECT'
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating primary key [PK_Properties] on [SJob].[Assets]'
GO
ALTER TABLE [SJob].[Assets] ADD CONSTRAINT [PK_Properties] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR=80) ON [PRIMARY]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating index [IX_UQ_Properties_Guid] on [SJob].[Assets]'
GO
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_Properties_Guid] ON [SJob].[Assets] ([Guid]) WITH (FILLFACTOR=80) ON [PRIMARY]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating index [IX_UPRN_List] on [SJob].[Assets]'
GO
CREATE NONCLUSTERED INDEX [IX_UPRN_List] ON [SJob].[Assets] ([Guid], [AssetNumber], [RowStatus]) INCLUDE ([ListLabel]) WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254)) WITH (FILLFACTOR=80) ON [PRIMARY]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating index [IX_UQ_Properties_URPN] on [SJob].[Assets]'
GO
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_Properties_URPN] ON [SJob].[Assets] ([AssetNumber]) WHERE ([RowStatus]<>(0)) WITH (FILLFACTOR=80) ON [PRIMARY]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating trigger [SJob].[tg_Properties_RecordHistory] on [SJob].[Assets]'
GO
CREATE TRIGGER SJob.tg_Properties_RecordHistory
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.AssetNumber), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.AssetNumber), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.AssetNumber IS DISTINCT FROM i.AssetNumber)


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
PRINT N'Altering [SJob].[AssetsUpsert]'
GO

ALTER PROCEDURE SJob.AssetsUpsert
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
		SET		AssetNumber = @UPRN,
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
			@UPRN			  = p.AssetNumber
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
PRINT N'Altering [SJob].[tvf_Assets]'
GO


CREATE OR ALTER FUNCTION SJob.tvf_Assets
	(
		@UserId INT
	)
RETURNS TABLE
       --WITH SCHEMABINDING
AS
RETURN SELECT		prop.ID,
					prop.RowStatus,
					prop.Guid,
					prop.AssetNumber AS UPRN,
					prop.FormattedAddressComma,
					prop.Name,
					la.Name AS LocalAuthority,
					oa.Name AS OwnerAccount
	   FROM			SJob.Assets				  AS prop
	   JOIN			SCrm.Accounts AS la ON (la.ID = prop.LocalAuthorityAccountID)
	   JOIN			SCrm.Accounts AS oa ON (oa.ID = prop.OwnerAccountID)
	   WHERE		(prop.ID > 0)
				AND (prop.RowStatus NOT IN (0, 254))
				AND	(EXISTS
			(
					SELECT
							1
					FROM
							SCore.ObjectSecurityForUser_CanRead(prop.Guid, @UserId) oscr
			)
		)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SSop].[tvf_Enquiries]'
GO





ALTER FUNCTION SSop.tvf_Enquiries
(
	@UserId INT
)
RETURNS TABLE
     --WITH SCHEMABINDING
AS RETURN	
SELECT  e.ID,
        e.RowStatus,
        e.RowVersion,
        e.Guid,
		CASE WHEN e.Revision = 0 THEN e.Number ELSE (e.Number + N' (' + CONVERT(NVARCHAR(2), e.Revision) + N') ') END AS Number,
		e.ExternalReference,
		LEFT(e.DescriptionOfWorks, 200) AS DescriptionOfWorks, 
		CASE WHEN client.Name <> N'' THEN client.Name ELSE e.ClientName END + N' / ' + CASE WHEN agent.Name <> N'' THEN agent.Name ELSE e.AgentName END  AS ClientAgentAccount,
		CASE WHEN uprn.AssetNumber > 0 THEN uprn.FormattedAddressComma ELSE e.PropertyNameNumber + N' ' + e.PropertyAddressLine1 END AS Property,
		uprn.AssetNumber AS UPRN,
		ecf.EnquiryStatus,
		ISNULL(p.IsSubjectToNDA, e.IsSubjectToNDA) AS IsSubjectToNDA,
		CASE WHEN ServiceTypes.Name IS NULL THEN N'Multi Discipline' ELSE ServiceTypes.Name END AS Disciplines,
		org.Name AS OrgUnit,
		e.Date 
FROM    SSop.Enquiries e
JOIN	SSop.Enquiry_CalculatedFields AS ecf ON (ecf.ID = e.ID)
JOIN	SCrm.Accounts client ON (client.ID = e.ClientAccountID)
JOIN	SCrm.Accounts agent ON (agent.ID = e.AgentAccountId)
JOIN	SJob.Assets uprn ON (uprn.ID = e.PropertyId)
JOIN	SSop.Projects AS p ON (p.ID = e.ProjectId)
JOIN	SCore.OrganisationalUnits AS org ON (org.ID = e.OrganisationalUnitID)
OUTER APPLY (
	SELECT	jt.Name
	FROM	SJob.JobTypes AS jt
	JOIN	SSop.EnquiryServices AS es ON (es.JobTypeId = jt.ID)
	WHERE	(es.EnquiryId = e.ID)
		AND	(es.RowStatus NOT IN (0, 254))
		AND	(NOT EXISTS
				(
					SELECT	1
					FROM	SSop.EnquiryServices es2 
					WHERE	(es2.ID <> es.ID)
						AND	(es2.EnquiryId = es.EnquiryId)
						AND	(es2.RowStatus NOT IN (0, 254))
				)
			)
) AS ServiceTypes
WHERE   (e.RowStatus NOT IN (0, 254))
	AND	(e.ID > 0)
AND	(EXISTS
			(
		SELECT
				1
		FROM
				SCore.ObjectSecurityForUser_CanRead(e.Guid, @UserId) oscr
			)
		)

GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SSop].[tvf_OpenEnquiries]'
GO








ALTER FUNCTION SSop.tvf_OpenEnquiries
(
	@UserId INT
)
RETURNS TABLE
     --WITH SCHEMABINDING
AS RETURN	
SELECT  e.ID,
        e.RowStatus,
        e.RowVersion,
        e.Guid,
		e.Number,
		e.QuotingDeadlineDate,
		e.ExternalReference,
		LEFT(e.DescriptionOfWorks, 200) AS DescriptionOfWorks, 
		CASE WHEN client.Name <> N'' THEN client.Name ELSE e.ClientName END + N' / ' + CASE WHEN agent.Name <> N'' THEN agent.Name ELSE e.AgentName END  AS ClientAgentAccount,
		CASE WHEN uprn.AssetNumber > 0 THEN uprn.FormattedAddressComma ELSE e.PropertyNameNumber + N' ' + e.PropertyAddressLine1 END AS Property,
		ecf.EnquiryStatus
FROM    SSop.Enquiries e
JOIN	SSop.Enquiry_CalculatedFields AS ecf ON (ecf.ID = e.ID)
JOIN	SCrm.Accounts client ON (client.ID = e.ClientAccountID)
JOIN	SCrm.Accounts agent ON (agent.ID = e.AgentAccountId)
JOIN	SJob.Assets uprn ON (uprn.ID = e.PropertyId)
WHERE   (e.RowStatus NOT IN (0, 254))
	AND	(e.ID > 0)
AND	(EXISTS
			(
		SELECT
				1
		FROM
				SCore.ObjectSecurityForUser_CanRead(e.Guid, @UserId) oscr
			)
		)
	AND	(e.DeclinedToQuoteDate IS NULL)
	AND	(EXISTS
			(
				SELECT	1
				FROM	SSop.EnquiryServices es 
				WHERE	(es.EnquiryId = e.ID)
					AND	(es.RowStatus NOT IN (0, 254))
					AND	(es.QuoteId < 0)
			)
		)
	AND	(e.Date > DATEADD(MONTH, -6, GETDATE()))
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Adding foreign keys to [SJob].[Assets]'
GO
ALTER TABLE [SJob].[Assets] WITH NOCHECK  ADD CONSTRAINT [FK_Properties_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Adding foreign keys to [SJob].[Assets]'
GO
ALTER TABLE [SJob].[Assets] ADD CONSTRAINT [FK_Properties_Accounts] FOREIGN KEY ([LocalAuthorityAccountID]) REFERENCES [SCrm].[Accounts] ([ID])
GO
ALTER TABLE [SJob].[Assets] ADD CONSTRAINT [FK_Properties_Accounts1] FOREIGN KEY ([FireAuthorityAccountID]) REFERENCES [SCrm].[Accounts] ([ID])
GO
ALTER TABLE [SJob].[Assets] ADD CONSTRAINT [FK_Properties_Accounts2] FOREIGN KEY ([WaterAuthorityAccountID]) REFERENCES [SCrm].[Accounts] ([ID])
GO
ALTER TABLE [SJob].[Assets] ADD CONSTRAINT [FK_Properties_Accounts3] FOREIGN KEY ([OwnerAccountId]) REFERENCES [SCrm].[Accounts] ([ID])
GO
ALTER TABLE [SJob].[Assets] ADD CONSTRAINT [FK_Properties_Counties] FOREIGN KEY ([CountyId]) REFERENCES [SCrm].[Counties] ([ID])
GO
ALTER TABLE [SJob].[Assets] ADD CONSTRAINT [FK_Properties_Countries] FOREIGN KEY ([CountryId]) REFERENCES [SCrm].[Countries] ([ID])
GO
ALTER TABLE [SJob].[Assets] ADD CONSTRAINT [FK_Properties_Properties] FOREIGN KEY ([ParentAssetID]) REFERENCES [SJob].[Assets] ([ID])
GO
ALTER TABLE [SJob].[Assets] ADD CONSTRAINT [FK_Properties_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Adding foreign keys to [SSop].[Enquiries]'
GO
ALTER TABLE [SSop].[Enquiries] ADD CONSTRAINT [FK_Enquiries_Properties] FOREIGN KEY ([PropertyId]) REFERENCES [SJob].[Assets] ([ID])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Adding foreign keys to [SJob].[Jobs]'
GO
ALTER TABLE [SJob].[Jobs] ADD CONSTRAINT [FK_Jobs_Properties] FOREIGN KEY ([UprnID]) REFERENCES [SJob].[Assets] ([ID])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Adding foreign keys to [SSop].[Quotes]'
GO
ALTER TABLE [SSop].[Quotes] ADD CONSTRAINT [FK_Quotes_Properties] FOREIGN KEY ([UprnId]) REFERENCES [SJob].[Assets] ([ID])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Disabling constraints on [SJob].[Assets]'
GO
ALTER TABLE [SJob].[Assets] NOCHECK CONSTRAINT [FK_Properties_DataObjects]
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

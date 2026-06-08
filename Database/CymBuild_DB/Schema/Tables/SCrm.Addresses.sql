PRINT (N'Create table [SCrm].[Addresses]')
GO
CREATE TABLE [SCrm].[Addresses] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Addresses_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_Addresses_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [AddressNumber] [int] NOT NULL CONSTRAINT [DF_Addresses_AddressNumber] DEFAULT (0),
  [Name] [nvarchar](100) NOT NULL CONSTRAINT [DF_Addresses_Name] DEFAULT (''),
  [Number] [nvarchar](50) NOT NULL CONSTRAINT [DF_Addresses_Number] DEFAULT (''),
  [AddressLine1] [nvarchar](255) NOT NULL CONSTRAINT [DF_Addresses_AddressLine1] DEFAULT (''),
  [AddressLine2] [nvarchar](255) NOT NULL CONSTRAINT [DF_Addresses_AddressLine2] DEFAULT (''),
  [AddressLine3] [nvarchar](255) NOT NULL CONSTRAINT [DF_Addresses_AddressLine3] DEFAULT (''),
  [Town] [nvarchar](255) NOT NULL CONSTRAINT [DF_Addresses_Town] DEFAULT (''),
  [CountyID] [int] NOT NULL CONSTRAINT [DF_Addresses_CountyID] DEFAULT (-1),
  [Postcode] [nvarchar](50) NOT NULL CONSTRAINT [DF_Addresses_Postcode] DEFAULT (''),
  [CountryID] [int] NOT NULL CONSTRAINT [DF_Addresses_CountryID] DEFAULT (-1),
  [LegacyID] [int] NULL,
  [FormattedAddressCR] [nvarchar](600) NOT NULL CONSTRAINT [DF_Addresses_FormattedAddressCR] DEFAULT (''),
  [FormattedAddressComma] [nvarchar](600) NOT NULL CONSTRAINT [DF_Addresses_FormattedAddressComma] DEFAULT (''),
  [LegacySystemID] [int] NOT NULL DEFAULT (-1)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK__Addresse__3214EC2799120222] on table [SCrm].[Addresses]')
GO
ALTER TABLE [SCrm].[Addresses] WITH NOCHECK
  ADD CONSTRAINT [PK__Addresse__3214EC2799120222] PRIMARY KEY CLUSTERED ([ID])
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Addresses_DDL] on table [SCrm].[Addresses]')
GO
CREATE INDEX [IX_Addresses_DDL]
  ON [SCrm].[Addresses] ([FormattedAddressComma], [RowStatus])
  INCLUDE ([Guid])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_Addresses_Guid] on table [SCrm].[Addresses]')
GO
CREATE UNIQUE INDEX [IX_UQ_Addresses_Guid]
  ON [SCrm].[Addresses] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_Addresses_RecordHistory] on table [SCrm].[Addresses]')
GO
CREATE TRIGGER [SCrm].[tg_Addresses_RecordHistory]
   ON  [SCrm].[Addresses]	
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
			@SchemaName NVARCHAR(250) = N'SCrm',
			@TableName NVARCHAR(250) = N'Addresses',
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
				VALUES(1, @SchemaName, @TableName, N'AddressLine1', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 187)
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
				VALUES(1, @SchemaName, @TableName, N'AddressLine2', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 188)
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
				VALUES(1, @SchemaName, @TableName, N'AddressLine3', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 189)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[AddressNumber]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[AddressNumber]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[AddressNumber] IS DISTINCT FROM i.[AddressNumber])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'AddressNumber', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 184)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[CountryID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[CountryID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[CountryID] IS DISTINCT FROM i.[CountryID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'CountryID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 193)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[CountyID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[CountyID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[CountyID] IS DISTINCT FROM i.[CountyID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'CountyID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 191)
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
				VALUES(1, @SchemaName, @TableName, N'FormattedAddressComma', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 957)
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
				VALUES(1, @SchemaName, @TableName, N'FormattedAddressCR', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 958)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[LegacyID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[LegacyID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[LegacyID] IS DISTINCT FROM i.[LegacyID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'LegacyID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 959)
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
				VALUES(1, @SchemaName, @TableName, N'Name', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 185)
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
				VALUES(1, @SchemaName, @TableName, N'Number', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 186)
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
				VALUES(1, @SchemaName, @TableName, N'Postcode', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 192)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 181)
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
				VALUES(1, @SchemaName, @TableName, N'Town', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 190)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_Addresses_Counties] on table [SCrm].[Addresses]')
GO
ALTER TABLE [SCrm].[Addresses] WITH NOCHECK
  ADD CONSTRAINT [FK_Addresses_Counties] FOREIGN KEY ([CountyID]) REFERENCES [SCrm].[Counties] ([ID])
GO

PRINT (N'Create foreign key [FK_Addresses_Countries] on table [SCrm].[Addresses]')
GO
ALTER TABLE [SCrm].[Addresses] WITH NOCHECK
  ADD CONSTRAINT [FK_Addresses_Countries] FOREIGN KEY ([CountryID]) REFERENCES [SCrm].[Countries] ([ID])
GO

PRINT (N'Create foreign key [FK_Addresses_DataObjects] on table [SCrm].[Addresses]')
GO
ALTER TABLE [SCrm].[Addresses] WITH NOCHECK
  ADD CONSTRAINT [FK_Addresses_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid]) ON DELETE CASCADE
GO

PRINT (N'Disable foreign key [FK_Addresses_DataObjects] on table [SCrm].[Addresses]')
GO
ALTER TABLE [SCrm].[Addresses]
  NOCHECK CONSTRAINT [FK_Addresses_DataObjects]
GO

PRINT (N'Create foreign key [FK_Addresses_RowStatus] on table [SCrm].[Addresses]')
GO
ALTER TABLE [SCrm].[Addresses] WITH NOCHECK
  ADD CONSTRAINT [FK_Addresses_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
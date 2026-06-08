PRINT (N'Create table [SCrm].[Contacts]')
GO
CREATE TABLE [SCrm].[Contacts] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Contacts_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_Contacts_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [PrimaryAccountID] [int] NOT NULL CONSTRAINT [DF_Contacts_AccountID] DEFAULT (-1),
  [PrimaryAddressID] [int] NOT NULL CONSTRAINT [DF_Contacts_PrimaryAddressID] DEFAULT (-1),
  [FirstName] [nvarchar](250) NOT NULL CONSTRAINT [DF_Contacts_FirstName] DEFAULT (N''),
  [Initials] [nvarchar](10) NOT NULL CONSTRAINT [DF_Contacts_Initials] DEFAULT (''),
  [Surname] [nvarchar](250) NOT NULL CONSTRAINT [DF_Contacts_Surname] DEFAULT (N''),
  [PostNominals] [nvarchar](250) NOT NULL CONSTRAINT [DF_Contacts_PostNominals] DEFAULT (''),
  [TitleId] [smallint] NOT NULL CONSTRAINT [DF_Contacts_TitleID] DEFAULT (-1),
  [DisplayName] [nvarchar](250) NOT NULL CONSTRAINT [DF_Contacts_DisplayName] DEFAULT (N''),
  [IsPerson] [bit] NOT NULL CONSTRAINT [DF_Contacts_IsPerson] DEFAULT (0),
  [PositionID] [int] NOT NULL CONSTRAINT [DF_Contacts_PositionID] DEFAULT (-1),
  [LegacyID] [int] NULL,
  [LegacySystemID] [int] NOT NULL DEFAULT (-1)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_Contacts] on table [SCrm].[Contacts]')
GO
ALTER TABLE [SCrm].[Contacts] WITH NOCHECK
  ADD CONSTRAINT [PK_Contacts] PRIMARY KEY CLUSTERED ([ID])
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Contacts_DDL] on table [SCrm].[Contacts]')
GO
CREATE INDEX [IX_Contacts_DDL]
  ON [SCrm].[Contacts] ([DisplayName], [RowStatus])
  INCLUDE ([Guid])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UX_Contacts_Guid] on table [SCrm].[Contacts]')
GO
CREATE UNIQUE INDEX [IX_UX_Contacts_Guid]
  ON [SCrm].[Contacts] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_Contacts_RecordHistory] on table [SCrm].[Contacts]')
GO
CREATE TRIGGER [SCrm].[tg_Contacts_RecordHistory]
   ON  [SCrm].[Contacts]	
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
			@TableName NVARCHAR(250) = N'Contacts',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[DisplayName]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[DisplayName]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[DisplayName] IS DISTINCT FROM i.[DisplayName])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'DisplayName', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 221)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[FirstName]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[FirstName]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[FirstName] IS DISTINCT FROM i.[FirstName])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'FirstName', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 218)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Initials]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Initials]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Initials] IS DISTINCT FROM i.[Initials])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Initials', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 785)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[IsPerson]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[IsPerson]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[IsPerson] IS DISTINCT FROM i.[IsPerson])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsPerson', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 222)
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
				VALUES(1, @SchemaName, @TableName, N'LegacyID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 786)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[PositionID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[PositionID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[PositionID] IS DISTINCT FROM i.[PositionID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'PositionID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 223)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[PostNominals]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[PostNominals]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[PostNominals] IS DISTINCT FROM i.[PostNominals])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'PostNominals', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 787)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[PrimaryAccountID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[PrimaryAccountID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[PrimaryAccountID] IS DISTINCT FROM i.[PrimaryAccountID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'PrimaryAccountID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 788)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[PrimaryAddressID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[PrimaryAddressID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[PrimaryAddressID] IS DISTINCT FROM i.[PrimaryAddressID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'PrimaryAddressID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 217)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 213)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Surname]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Surname]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Surname] IS DISTINCT FROM i.[Surname])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Surname', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 219)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[TitleId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[TitleId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[TitleId] IS DISTINCT FROM i.[TitleId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'TitleId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 220)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_Contacts_Accounts] on table [SCrm].[Contacts]')
GO
ALTER TABLE [SCrm].[Contacts] WITH NOCHECK
  ADD CONSTRAINT [FK_Contacts_Accounts] FOREIGN KEY ([PrimaryAccountID]) REFERENCES [SCrm].[Accounts] ([ID])
GO

PRINT (N'Create foreign key [FK_Contacts_Addresses] on table [SCrm].[Contacts]')
GO
ALTER TABLE [SCrm].[Contacts] WITH NOCHECK
  ADD CONSTRAINT [FK_Contacts_Addresses] FOREIGN KEY ([PrimaryAddressID]) REFERENCES [SCrm].[Addresses] ([ID])
GO

PRINT (N'Create foreign key [FK_Contacts_ContactPositions] on table [SCrm].[Contacts]')
GO
ALTER TABLE [SCrm].[Contacts] WITH NOCHECK
  ADD CONSTRAINT [FK_Contacts_ContactPositions] FOREIGN KEY ([PositionID]) REFERENCES [SCrm].[ContactPositions] ([ID])
GO

PRINT (N'Create foreign key [FK_Contacts_ContactTitles] on table [SCrm].[Contacts]')
GO
ALTER TABLE [SCrm].[Contacts] WITH NOCHECK
  ADD CONSTRAINT [FK_Contacts_ContactTitles] FOREIGN KEY ([TitleId]) REFERENCES [SCrm].[ContactTitles] ([ID])
GO

PRINT (N'Create foreign key [FK_Contacts_DataObjects] on table [SCrm].[Contacts]')
GO
ALTER TABLE [SCrm].[Contacts] WITH NOCHECK
  ADD CONSTRAINT [FK_Contacts_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid]) ON DELETE CASCADE
GO

PRINT (N'Disable foreign key [FK_Contacts_DataObjects] on table [SCrm].[Contacts]')
GO
ALTER TABLE [SCrm].[Contacts]
  NOCHECK CONSTRAINT [FK_Contacts_DataObjects]
GO

PRINT (N'Create foreign key [FK_Contacts_RowStatus] on table [SCrm].[Contacts]')
GO
ALTER TABLE [SCrm].[Contacts] WITH NOCHECK
  ADD CONSTRAINT [FK_Contacts_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_Contacts_RowStatus1] on table [SCrm].[Contacts]')
GO
ALTER TABLE [SCrm].[Contacts] WITH NOCHECK
  ADD CONSTRAINT [FK_Contacts_RowStatus1] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
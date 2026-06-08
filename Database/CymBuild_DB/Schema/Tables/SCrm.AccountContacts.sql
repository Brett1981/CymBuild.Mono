PRINT (N'Create table [SCrm].[AccountContacts]')
GO
CREATE TABLE [SCrm].[AccountContacts] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_AccountContacts_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_AccountContacts_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [AccountID] [int] NOT NULL CONSTRAINT [DF_AccountContacts_AccountID] DEFAULT (-1),
  [ContactID] [int] NOT NULL CONSTRAINT [DF_AccountContacts_ContactID] DEFAULT (-1),
  [PrimaryAccountAddressID] [int] NOT NULL CONSTRAINT [DF_AccountContacts_PrimaryAccountAddressID] DEFAULT (-1)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_AccountContacts] on table [SCrm].[AccountContacts]')
GO
ALTER TABLE [SCrm].[AccountContacts] WITH NOCHECK
  ADD CONSTRAINT [PK_AccountContacts] PRIMARY KEY CLUSTERED ([ID])
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_AccountContacts_Account] on table [SCrm].[AccountContacts]')
GO
CREATE UNIQUE INDEX [IX_AccountContacts_Account]
  ON [SCrm].[AccountContacts] ([AccountID], [ContactID], [RowStatus])
  INCLUDE ([Guid])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_AccountContacts_Guid] on table [SCrm].[AccountContacts]')
GO
CREATE UNIQUE INDEX [IX_UQ_AccountContacts_Guid]
  ON [SCrm].[AccountContacts] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_AccountContacts_RecordHistory] on table [SCrm].[AccountContacts]')
GO
CREATE TRIGGER [SCrm].[tg_AccountContacts_RecordHistory]
   ON  [SCrm].[AccountContacts]	
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
			@TableName NVARCHAR(250) = N'AccountContacts',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[AccountID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[AccountID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[AccountID] IS DISTINCT FROM i.[AccountID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'AccountID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 514)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ContactID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ContactID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ContactID] IS DISTINCT FROM i.[ContactID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ContactID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 515)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[PrimaryAccountAddressID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[PrimaryAccountAddressID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[PrimaryAccountAddressID] IS DISTINCT FROM i.[PrimaryAccountAddressID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'PrimaryAccountAddressID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 518)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 519)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_AccountContacts_AccountAddresses] on table [SCrm].[AccountContacts]')
GO
ALTER TABLE [SCrm].[AccountContacts] WITH NOCHECK
  ADD CONSTRAINT [FK_AccountContacts_AccountAddresses] FOREIGN KEY ([PrimaryAccountAddressID]) REFERENCES [SCrm].[AccountAddresses] ([ID])
GO

PRINT (N'Create foreign key [FK_AccountContacts_Accounts] on table [SCrm].[AccountContacts]')
GO
ALTER TABLE [SCrm].[AccountContacts] WITH NOCHECK
  ADD CONSTRAINT [FK_AccountContacts_Accounts] FOREIGN KEY ([AccountID]) REFERENCES [SCrm].[Accounts] ([ID]) ON DELETE CASCADE
GO

PRINT (N'Create foreign key [FK_AccountContacts_Contacts] on table [SCrm].[AccountContacts]')
GO
ALTER TABLE [SCrm].[AccountContacts] WITH NOCHECK
  ADD CONSTRAINT [FK_AccountContacts_Contacts] FOREIGN KEY ([ContactID]) REFERENCES [SCrm].[Contacts] ([ID])
GO

PRINT (N'Create foreign key [FK_AccountContacts_DataObjects] on table [SCrm].[AccountContacts]')
GO
ALTER TABLE [SCrm].[AccountContacts] WITH NOCHECK
  ADD CONSTRAINT [FK_AccountContacts_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_AccountContacts_DataObjects] on table [SCrm].[AccountContacts]')
GO
ALTER TABLE [SCrm].[AccountContacts]
  NOCHECK CONSTRAINT [FK_AccountContacts_DataObjects]
GO

PRINT (N'Create foreign key [FK_AccountContacts_RowStatus] on table [SCrm].[AccountContacts]')
GO
ALTER TABLE [SCrm].[AccountContacts] WITH NOCHECK
  ADD CONSTRAINT [FK_AccountContacts_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
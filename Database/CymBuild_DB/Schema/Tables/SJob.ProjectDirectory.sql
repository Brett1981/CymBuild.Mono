PRINT (N'Create table [SJob].[ProjectDirectory]')
GO
CREATE TABLE [SJob].[ProjectDirectory] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_ProjectDirectory_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_ProjectDirectory_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [JobID] [int] NOT NULL CONSTRAINT [DF_ProjectDirectory_JobId] DEFAULT (-1),
  [ProjectID] [int] NOT NULL CONSTRAINT [DF_ProjectDirectory_ProjectID] DEFAULT (-1),
  [ProjectDirectoryRoleID] [int] NOT NULL CONSTRAINT [DF_ProjectDirectory_ProjectDirectoryRoleID] DEFAULT (-1),
  [AccountID] [int] NOT NULL CONSTRAINT [DF_ProjectDirectory_AccountId] DEFAULT (-1),
  [ContactID] [int] NOT NULL CONSTRAINT [DF_ProjectDirectory_ContactId] DEFAULT (-1)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_ProjectDirectory] on table [SJob].[ProjectDirectory]')
GO
ALTER TABLE [SJob].[ProjectDirectory] WITH NOCHECK
  ADD CONSTRAINT [PK_ProjectDirectory] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create index [IX_ProjectDirectory_Job] on table [SJob].[ProjectDirectory]')
GO
CREATE INDEX [IX_ProjectDirectory_Job]
  ON [SJob].[ProjectDirectory] ([JobID])
  INCLUDE ([ProjectDirectoryRoleID])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SJob_ProjectDirectory_1302037659] on table [SJob].[ProjectDirectory]')
GO
CREATE INDEX [IX_SJob_ProjectDirectory_1302037659]
  ON [SJob].[ProjectDirectory] ([RowStatus])
  INCLUDE ([RowVersion], [Guid], [ProjectID], [ProjectDirectoryRoleID], [AccountID], [ContactID])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SJob_ProjectDirectory_1881690932] on table [SJob].[ProjectDirectory]')
GO
CREATE INDEX [IX_SJob_ProjectDirectory_1881690932]
  ON [SJob].[ProjectDirectory] ([RowStatus])
  INCLUDE ([Guid], [ProjectID])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SJob_ProjectDirectory_1970593348] on table [SJob].[ProjectDirectory]')
GO
CREATE INDEX [IX_SJob_ProjectDirectory_1970593348]
  ON [SJob].[ProjectDirectory] ([ProjectID])
  INCLUDE ([RowStatus], [Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SJob_ProjectDirectory_674987717] on table [SJob].[ProjectDirectory]')
GO
CREATE INDEX [IX_SJob_ProjectDirectory_674987717]
  ON [SJob].[ProjectDirectory] ([ProjectID])
  INCLUDE ([RowStatus], [RowVersion], [Guid], [ProjectDirectoryRoleID], [AccountID], [ContactID])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_ProjectDirectory_RecordHistory] on table [SJob].[ProjectDirectory]')
GO
CREATE TRIGGER [SJob].[tg_ProjectDirectory_RecordHistory]
   ON  [SJob].[ProjectDirectory]	
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
			@TableName NVARCHAR(250) = N'ProjectDirectory',
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
				VALUES(1, @SchemaName, @TableName, N'AccountID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 470)
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
				VALUES(1, @SchemaName, @TableName, N'ContactID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 475)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[JobID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[JobID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[JobID] IS DISTINCT FROM i.[JobID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'JobID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 469)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ProjectDirectoryRoleID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ProjectDirectoryRoleID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ProjectDirectoryRoleID] IS DISTINCT FROM i.[ProjectDirectoryRoleID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ProjectDirectoryRoleID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 474)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ProjectID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ProjectID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ProjectID] IS DISTINCT FROM i.[ProjectID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ProjectID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1822)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 472)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_ProjectDirectory_Accounts] on table [SJob].[ProjectDirectory]')
GO
ALTER TABLE [SJob].[ProjectDirectory] WITH NOCHECK
  ADD CONSTRAINT [FK_ProjectDirectory_Accounts] FOREIGN KEY ([AccountID]) REFERENCES [SCrm].[Accounts] ([ID])
GO

PRINT (N'Create foreign key [FK_ProjectDirectory_Contacts] on table [SJob].[ProjectDirectory]')
GO
ALTER TABLE [SJob].[ProjectDirectory] WITH NOCHECK
  ADD CONSTRAINT [FK_ProjectDirectory_Contacts] FOREIGN KEY ([ContactID]) REFERENCES [SCrm].[Contacts] ([ID])
GO

PRINT (N'Create foreign key [FK_ProjectDirectory_DataObjects] on table [SJob].[ProjectDirectory]')
GO
ALTER TABLE [SJob].[ProjectDirectory] WITH NOCHECK
  ADD CONSTRAINT [FK_ProjectDirectory_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_ProjectDirectory_DataObjects] on table [SJob].[ProjectDirectory]')
GO
ALTER TABLE [SJob].[ProjectDirectory]
  NOCHECK CONSTRAINT [FK_ProjectDirectory_DataObjects]
GO

PRINT (N'Create foreign key [FK_ProjectDirectory_Jobs] on table [SJob].[ProjectDirectory]')
GO
ALTER TABLE [SJob].[ProjectDirectory] WITH NOCHECK
  ADD CONSTRAINT [FK_ProjectDirectory_Jobs] FOREIGN KEY ([JobID]) REFERENCES [SJob].[Jobs] ([ID]) ON DELETE CASCADE
GO

PRINT (N'Create foreign key [FK_ProjectDirectory_ProjectDirectoryRoles] on table [SJob].[ProjectDirectory]')
GO
ALTER TABLE [SJob].[ProjectDirectory] WITH NOCHECK
  ADD CONSTRAINT [FK_ProjectDirectory_ProjectDirectoryRoles] FOREIGN KEY ([ProjectDirectoryRoleID]) REFERENCES [SJob].[ProjectDirectoryRoles] ([ID])
GO

PRINT (N'Create foreign key [FK_ProjectDirectory_RowStatus] on table [SJob].[ProjectDirectory]')
GO
ALTER TABLE [SJob].[ProjectDirectory] WITH NOCHECK
  ADD CONSTRAINT [FK_ProjectDirectory_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
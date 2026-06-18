PRINT (N'Create table [SCore].[ObjectSharePointFolder]')
GO
CREATE TABLE [SCore].[ObjectSharePointFolder] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_ObjectSharePointFolder_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_ObjectSharePointFolder_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [ObjectGuid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_ObjectSharePointFolder_RecordGuid] DEFAULT ('00000000-0000-0000-0000-000000000000'),
  [SharepointSiteId] [int] NOT NULL CONSTRAINT [DF_ObjectSharePointFolder_SharepointSiteId] DEFAULT (-1),
  [FolderPath] [nvarchar](500) NOT NULL CONSTRAINT [DF_ObjectSharePointFolder_FolderPath] DEFAULT ('')
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_ObjectSharePointFolder] on table [SCore].[ObjectSharePointFolder]')
GO
ALTER TABLE [SCore].[ObjectSharePointFolder] WITH NOCHECK
  ADD CONSTRAINT [PK_ObjectSharePointFolder] PRIMARY KEY CLUSTERED ([ID]) WITH (PAD_INDEX = ON, FILLFACTOR = 90)
GO

PRINT (N'Create index [IX_UQ_ObjectSharePointFolder_Guid] on table [SCore].[ObjectSharePointFolder]')
GO
CREATE UNIQUE INDEX [IX_UQ_ObjectSharePointFolder_Guid]
  ON [SCore].[ObjectSharePointFolder] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_ObjectSharePointFolder_ObjectGuid] on table [SCore].[ObjectSharePointFolder]')
GO
CREATE UNIQUE INDEX [IX_UQ_ObjectSharePointFolder_ObjectGuid]
  ON [SCore].[ObjectSharePointFolder] ([ObjectGuid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_ObjectSharePointFolder_RecordHistory] on table [SCore].[ObjectSharePointFolder]')
GO
CREATE TRIGGER [SCore].[tg_ObjectSharePointFolder_RecordHistory]
   ON  [SCore].[ObjectSharePointFolder]	
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
			@SchemaName NVARCHAR(250) = N'SCore',
			@TableName NVARCHAR(250) = N'ObjectSharePointFolder',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[FolderPath]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[FolderPath]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[FolderPath] IS DISTINCT FROM i.[FolderPath])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'FolderPath', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1294)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ObjectGuid]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ObjectGuid]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ObjectGuid] IS DISTINCT FROM i.[ObjectGuid])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ObjectGuid', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1292)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1289)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[SharepointSiteId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[SharepointSiteId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[SharepointSiteId] IS DISTINCT FROM i.[SharepointSiteId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'SharepointSiteId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1293)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_ObjectSharePointFolder_DataObjects] on table [SCore].[ObjectSharePointFolder]')
GO
ALTER TABLE [SCore].[ObjectSharePointFolder] WITH NOCHECK
  ADD CONSTRAINT [FK_ObjectSharePointFolder_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid]) ON DELETE CASCADE
GO

PRINT (N'Disable foreign key [FK_ObjectSharePointFolder_DataObjects] on table [SCore].[ObjectSharePointFolder]')
GO
ALTER TABLE [SCore].[ObjectSharePointFolder]
  NOCHECK CONSTRAINT [FK_ObjectSharePointFolder_DataObjects]
GO

PRINT (N'Create foreign key [FK_ObjectSharePointFolder_SharepointSites] on table [SCore].[ObjectSharePointFolder]')
GO
ALTER TABLE [SCore].[ObjectSharePointFolder] WITH NOCHECK
  ADD CONSTRAINT [FK_ObjectSharePointFolder_SharepointSites] FOREIGN KEY ([SharepointSiteId]) REFERENCES [SCore].[SharepointSites] ([ID])
GO
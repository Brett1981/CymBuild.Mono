PRINT (N'Create table [SCore].[RecentItems]')
GO
CREATE TABLE [SCore].[RecentItems] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_RecentItems_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_RecentItems_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Datetime] [datetime2] NOT NULL CONSTRAINT [DF_RecentItems_Datetime] DEFAULT (getutcdate()),
  [UserID] [int] NOT NULL CONSTRAINT [DF_RecentItems_UserID] DEFAULT (-1),
  [EntityTypeID] [int] NOT NULL CONSTRAINT [DF_RecentItems_EntityTypeID] DEFAULT (-1),
  [RecordGuid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_RecentItems_RecordGuid] DEFAULT ('00000000-0000-0000-0000-000000000000'),
  [Label] [nvarchar](100) NOT NULL CONSTRAINT [DF_RecentItems_Label] DEFAULT ('')
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_RecentItems] on table [SCore].[RecentItems]')
GO
ALTER TABLE [SCore].[RecentItems] WITH NOCHECK
  ADD CONSTRAINT [PK_RecentItems] PRIMARY KEY CLUSTERED ([ID]) WITH (PAD_INDEX = ON, FILLFACTOR = 90)
GO

PRINT (N'Create index [IX_RecentItems_Record] on table [SCore].[RecentItems]')
GO
CREATE INDEX [IX_RecentItems_Record]
  ON [SCore].[RecentItems] ([UserID], [RowStatus])
  INCLUDE ([RowVersion], [Guid], [Datetime], [EntityTypeID], [RecordGuid], [Label])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SCore_RecentItems_2040210241] on table [SCore].[RecentItems]')
GO
CREATE INDEX [IX_SCore_RecentItems_2040210241]
  ON [SCore].[RecentItems] ([UserID], [Datetime])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SCore_RecentItems_510103601] on table [SCore].[RecentItems]')
GO
CREATE INDEX [IX_SCore_RecentItems_510103601]
  ON [SCore].[RecentItems] ([UserID], [RecordGuid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_RecentItems_RecordHistory] on table [SCore].[RecentItems]')
GO
CREATE TRIGGER [SCore].[tg_RecentItems_RecordHistory]
   ON  [SCore].[RecentItems]	
   AFTER UPDATE
AS 
BEGIN
	SET NOCOUNT ON;

    IF (ISNULL(CONVERT(int, SESSION_CONTEXT(N'S_disable_triggers')), 0) = 1)
    BEGIN 
        RETURN
    END

    DECLARE	@PreviousValue NVARCHAR(MAX),
			@NewValue NVARCHAR(MAX),
			@UserID INT = 0,
			@SchemaName NVARCHAR(250) = N'SCore',
			@TableName NVARCHAR(250) = N'RecentItems',
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1280)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Datetime]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Datetime]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Datetime] IS DISTINCT FROM i.[Datetime])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Datetime', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1283)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[UserID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[UserID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[UserID] IS DISTINCT FROM i.[UserID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'UserID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1284)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[EntityTypeID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[EntityTypeID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[EntityTypeID] IS DISTINCT FROM i.[EntityTypeID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'EntityTypeID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1285)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RecordGuid]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RecordGuid]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RecordGuid] IS DISTINCT FROM i.[RecordGuid])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RecordGuid', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1286)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Label]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Label]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Label] IS DISTINCT FROM i.[Label])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Label', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1287)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_RecentItems_DataObjects] on table [SCore].[RecentItems]')
GO
ALTER TABLE [SCore].[RecentItems] WITH NOCHECK
  ADD CONSTRAINT [FK_RecentItems_DataObjects] FOREIGN KEY ([RecordGuid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_RecentItems_DataObjects] on table [SCore].[RecentItems]')
GO
ALTER TABLE [SCore].[RecentItems]
  NOCHECK CONSTRAINT [FK_RecentItems_DataObjects]
GO

PRINT (N'Create foreign key [FK_RecentItems_EntityTypes] on table [SCore].[RecentItems]')
GO
ALTER TABLE [SCore].[RecentItems] WITH NOCHECK
  ADD CONSTRAINT [FK_RecentItems_EntityTypes] FOREIGN KEY ([EntityTypeID]) REFERENCES [SCore].[EntityTypes] ([ID])
GO

PRINT (N'Create foreign key [FK_RecentItems_Identities] on table [SCore].[RecentItems]')
GO
ALTER TABLE [SCore].[RecentItems] WITH NOCHECK
  ADD CONSTRAINT [FK_RecentItems_Identities] FOREIGN KEY ([UserID]) REFERENCES [SCore].[Identities] ([ID])
GO
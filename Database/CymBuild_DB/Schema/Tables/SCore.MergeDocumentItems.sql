PRINT (N'Create table [SCore].[MergeDocumentItems]')
GO
CREATE TABLE [SCore].[MergeDocumentItems] (
  [ID] [int] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_Merge DocumentItems_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Merge DocumentItems_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [MergeDocumentId] [int] NOT NULL CONSTRAINT [DF_Merge DocumentItems_MergeDocumentId] DEFAULT (-1),
  [MergeDocumentItemTypeId] [smallint] NOT NULL CONSTRAINT [DF_Merge DocumentItems_MergeDocumentItemTypeId] DEFAULT (-1),
  [BookmarkName] [nvarchar](50) NOT NULL CONSTRAINT [DF_Merge DocumentItems_BookmarkName] DEFAULT (''),
  [EntityTypeId] [int] NOT NULL CONSTRAINT [DF_Merge DocumentItems_EntityType] DEFAULT (-1),
  [SubFolderPath] [nvarchar](200) NOT NULL CONSTRAINT [DF_Merge DocumentItems_SubFolderPath] DEFAULT (''),
  [ImageColumns] [int] NOT NULL CONSTRAINT [DF_Merge DocumentItems_ImageColumns] DEFAULT (0)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_MergeDocumentItems] on table [SCore].[MergeDocumentItems]')
GO
ALTER TABLE [SCore].[MergeDocumentItems] WITH NOCHECK
  ADD CONSTRAINT [PK_MergeDocumentItems] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_UQ_MergeDocumentItems_BookmarkName] on table [SCore].[MergeDocumentItems]')
GO
CREATE UNIQUE INDEX [IX_UQ_MergeDocumentItems_BookmarkName]
  ON [SCore].[MergeDocumentItems] ([MergeDocumentId], [BookmarkName], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_MergeDocumentItems_Guid] on table [SCore].[MergeDocumentItems]')
GO
CREATE UNIQUE INDEX [IX_UQ_MergeDocumentItems_Guid]
  ON [SCore].[MergeDocumentItems] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_MergeDocumentItems_RecordHistory] on table [SCore].[MergeDocumentItems]')
GO
CREATE TRIGGER [SCore].[tg_MergeDocumentItems_RecordHistory]
   ON  [SCore].[MergeDocumentItems]	
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
			@TableName NVARCHAR(250) = N'MergeDocumentItems',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[BookmarkName]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[BookmarkName]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[BookmarkName] IS DISTINCT FROM i.[BookmarkName])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'BookmarkName', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1795)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[EntityTypeId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[EntityTypeId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[EntityTypeId] IS DISTINCT FROM i.[EntityTypeId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'EntityTypeId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1796)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ImageColumns]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ImageColumns]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ImageColumns] IS DISTINCT FROM i.[ImageColumns])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ImageColumns', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1798)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[MergeDocumentId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[MergeDocumentId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[MergeDocumentId] IS DISTINCT FROM i.[MergeDocumentId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'MergeDocumentId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1793)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[MergeDocumentItemTypeId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[MergeDocumentItemTypeId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[MergeDocumentItemTypeId] IS DISTINCT FROM i.[MergeDocumentItemTypeId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'MergeDocumentItemTypeId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1794)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1791)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[SubFolderPath]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[SubFolderPath]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[SubFolderPath] IS DISTINCT FROM i.[SubFolderPath])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'SubFolderPath', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1797)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_MergeDocumentItems_EntityTypes] on table [SCore].[MergeDocumentItems]')
GO
ALTER TABLE [SCore].[MergeDocumentItems] WITH NOCHECK
  ADD CONSTRAINT [FK_MergeDocumentItems_EntityTypes] FOREIGN KEY ([EntityTypeId]) REFERENCES [SCore].[EntityTypes] ([ID])
GO

PRINT (N'Create foreign key [FK_MergeDocumentItems_MergeDocumentItemTypes] on table [SCore].[MergeDocumentItems]')
GO
ALTER TABLE [SCore].[MergeDocumentItems] WITH NOCHECK
  ADD CONSTRAINT [FK_MergeDocumentItems_MergeDocumentItemTypes] FOREIGN KEY ([MergeDocumentItemTypeId]) REFERENCES [SCore].[MergeDocumentItemTypes] ([ID])
GO

PRINT (N'Create foreign key [FK_MergeDocumentItems_MergeDocuments] on table [SCore].[MergeDocumentItems]')
GO
ALTER TABLE [SCore].[MergeDocumentItems] WITH NOCHECK
  ADD CONSTRAINT [FK_MergeDocumentItems_MergeDocuments] FOREIGN KEY ([MergeDocumentId]) REFERENCES [SCore].[MergeDocuments] ([ID])
GO
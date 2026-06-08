PRINT (N'Create table [SCore].[MergeDocumentItemIncludes]')
GO
CREATE TABLE [SCore].[MergeDocumentItemIncludes] (
  [ID] [int] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_MergeDocumentItemIncludes_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_MergeDocumentItemIncludes_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [MergeDocumentItemId] [int] NOT NULL CONSTRAINT [DF_MergeDocumentItemIncludes_MergeDocumentItemId] DEFAULT (-1),
  [SortOrder] [int] NOT NULL CONSTRAINT [DF_MergeDocumentItemIncludes_SortOrder] DEFAULT (0),
  [SourceDocumentEntityPropertyId] [int] NOT NULL CONSTRAINT [DF_MergeDocumentItemIncludes_SourceDocumentEntityPropertyId] DEFAULT (-1),
  [SourceSharePointItemEntityPropertyId] [int] NOT NULL CONSTRAINT [DF_MergeDocumentItemIncludes_SourceSharePointItemEntityPropertyId] DEFAULT (-1),
  [IncludedMergeDocumentId] [int] NOT NULL CONSTRAINT [DF_MergeDocumentItemIncludes_IncludedMergeDocumentId] DEFAULT (-1)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_MergeDocumentItemIncludes] on table [SCore].[MergeDocumentItemIncludes]')
GO
ALTER TABLE [SCore].[MergeDocumentItemIncludes] WITH NOCHECK
  ADD CONSTRAINT [PK_MergeDocumentItemIncludes] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create index [IX_UQ_MergeDocumentItemIncludes_Guid] on table [SCore].[MergeDocumentItemIncludes]')
GO
CREATE UNIQUE INDEX [IX_UQ_MergeDocumentItemIncludes_Guid]
  ON [SCore].[MergeDocumentItemIncludes] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_MergeDocumentItemIncludes_RecordHistory] on table [SCore].[MergeDocumentItemIncludes]')
GO
CREATE TRIGGER [SCore].[tg_MergeDocumentItemIncludes_RecordHistory]
   ON  [SCore].[MergeDocumentItemIncludes]	
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
			@TableName NVARCHAR(250) = N'MergeDocumentItemIncludes',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[IncludedMergeDocumentId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[IncludedMergeDocumentId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[IncludedMergeDocumentId] IS DISTINCT FROM i.[IncludedMergeDocumentId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IncludedMergeDocumentId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1807)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[MergeDocumentItemId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[MergeDocumentItemId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[MergeDocumentItemId] IS DISTINCT FROM i.[MergeDocumentItemId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'MergeDocumentItemId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1803)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1801)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[SortOrder]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[SortOrder]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[SortOrder] IS DISTINCT FROM i.[SortOrder])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'SortOrder', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1804)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[SourceDocumentEntityPropertyId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[SourceDocumentEntityPropertyId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[SourceDocumentEntityPropertyId] IS DISTINCT FROM i.[SourceDocumentEntityPropertyId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'SourceDocumentEntityPropertyId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1805)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[SourceSharePointItemEntityPropertyId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[SourceSharePointItemEntityPropertyId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[SourceSharePointItemEntityPropertyId] IS DISTINCT FROM i.[SourceSharePointItemEntityPropertyId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'SourceSharePointItemEntityPropertyId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1806)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_MergeDocumentItemIncludes_EntityProperties] on table [SCore].[MergeDocumentItemIncludes]')
GO
ALTER TABLE [SCore].[MergeDocumentItemIncludes] WITH NOCHECK
  ADD CONSTRAINT [FK_MergeDocumentItemIncludes_EntityProperties] FOREIGN KEY ([SourceDocumentEntityPropertyId]) REFERENCES [SCore].[EntityProperties] ([ID])
GO

PRINT (N'Create foreign key [FK_MergeDocumentItemIncludes_EntityProperties1] on table [SCore].[MergeDocumentItemIncludes]')
GO
ALTER TABLE [SCore].[MergeDocumentItemIncludes] WITH NOCHECK
  ADD CONSTRAINT [FK_MergeDocumentItemIncludes_EntityProperties1] FOREIGN KEY ([SourceSharePointItemEntityPropertyId]) REFERENCES [SCore].[EntityProperties] ([ID])
GO

PRINT (N'Create foreign key [FK_MergeDocumentItemIncludes_MergeDocumentItems] on table [SCore].[MergeDocumentItemIncludes]')
GO
ALTER TABLE [SCore].[MergeDocumentItemIncludes] WITH NOCHECK
  ADD CONSTRAINT [FK_MergeDocumentItemIncludes_MergeDocumentItems] FOREIGN KEY ([MergeDocumentItemId]) REFERENCES [SCore].[MergeDocumentItems] ([ID])
GO

PRINT (N'Create foreign key [FK_MergeDocumentItemIncludes_MergeDocuments] on table [SCore].[MergeDocumentItemIncludes]')
GO
ALTER TABLE [SCore].[MergeDocumentItemIncludes] WITH NOCHECK
  ADD CONSTRAINT [FK_MergeDocumentItemIncludes_MergeDocuments] FOREIGN KEY ([IncludedMergeDocumentId]) REFERENCES [SCore].[MergeDocuments] ([ID])
GO
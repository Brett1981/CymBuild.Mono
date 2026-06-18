PRINT (N'Create table [SCore].[MergeDocumentTables]')
GO
CREATE TABLE [SCore].[MergeDocumentTables] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_MergeDocumentTables_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_MergeDocumentTables_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [MergeDocumentId] [int] NOT NULL CONSTRAINT [DF_MergeDocumentTables_MergeDocumentId] DEFAULT (-1),
  [TableName] [nvarchar](50) NOT NULL CONSTRAINT [DF_MergeDocumentTables_TableName] DEFAULT (''),
  [LinkedEntityTypeId] [int] NOT NULL CONSTRAINT [DF_MergeDocumentTables_LinkedEntityTypeId] DEFAULT (-1)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_MergeDocumentTables] on table [SCore].[MergeDocumentTables]')
GO
ALTER TABLE [SCore].[MergeDocumentTables] WITH NOCHECK
  ADD CONSTRAINT [PK_MergeDocumentTables] PRIMARY KEY CLUSTERED ([ID])
GO

PRINT (N'Create unique key [UQ__MergeDocumentTables_Guid] on table [SCore].[MergeDocumentTables]')
GO
ALTER TABLE [SCore].[MergeDocumentTables] WITH NOCHECK
  ADD CONSTRAINT [UQ__MergeDocumentTables_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 90)
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_MergeDocumentTables_RecordHistory] on table [SCore].[MergeDocumentTables]')
GO
CREATE TRIGGER [SCore].[tg_MergeDocumentTables_RecordHistory]
   ON  [SCore].[MergeDocumentTables]	
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
			@TableName NVARCHAR(250) = N'MergeDocumentTables',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[LinkedEntityTypeId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[LinkedEntityTypeId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[LinkedEntityTypeId] IS DISTINCT FROM i.[LinkedEntityTypeId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'LinkedEntityTypeId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1599)
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
				VALUES(1, @SchemaName, @TableName, N'MergeDocumentId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1597)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1594)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[TableName]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[TableName]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[TableName] IS DISTINCT FROM i.[TableName])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'TableName', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1598)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_MergeDocumentTables_DataObjects] on table [SCore].[MergeDocumentTables]')
GO
ALTER TABLE [SCore].[MergeDocumentTables] WITH NOCHECK
  ADD CONSTRAINT [FK_MergeDocumentTables_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_MergeDocumentTables_DataObjects] on table [SCore].[MergeDocumentTables]')
GO
ALTER TABLE [SCore].[MergeDocumentTables]
  NOCHECK CONSTRAINT [FK_MergeDocumentTables_DataObjects]
GO

PRINT (N'Create foreign key [FK_MergeDocumentTables_EntityTypes] on table [SCore].[MergeDocumentTables]')
GO
ALTER TABLE [SCore].[MergeDocumentTables] WITH NOCHECK
  ADD CONSTRAINT [FK_MergeDocumentTables_EntityTypes] FOREIGN KEY ([LinkedEntityTypeId]) REFERENCES [SCore].[EntityTypes] ([ID])
GO

PRINT (N'Create foreign key [FK_MergeDocumentTables_MergeDocuments] on table [SCore].[MergeDocumentTables]')
GO
ALTER TABLE [SCore].[MergeDocumentTables] WITH NOCHECK
  ADD CONSTRAINT [FK_MergeDocumentTables_MergeDocuments] FOREIGN KEY ([MergeDocumentId]) REFERENCES [SCore].[MergeDocuments] ([ID]) ON DELETE CASCADE
GO

PRINT (N'Create foreign key [FK_MergeDocumentTables_RowStatus] on table [SCore].[MergeDocumentTables]')
GO
ALTER TABLE [SCore].[MergeDocumentTables] WITH NOCHECK
  ADD CONSTRAINT [FK_MergeDocumentTables_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
PRINT (N'Create table [SJob].[AssetPossibleDuplicates]')
GO
CREATE TABLE [SJob].[AssetPossibleDuplicates] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_AssetPossibleDuplicates_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_AssetPossibleDuplicates_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [SourceAssetID] [int] NOT NULL CONSTRAINT [DF_AssetPossibleDuplicates_SourceAssetID] DEFAULT (-1),
  [TargetAssetID] [int] NOT NULL CONSTRAINT [DF_AssetPossibleDuplicates_TargetAssetID] DEFAULT (-1),
  [IsDifferent] [bit] NOT NULL CONSTRAINT [DF_Table_1_Ignore] DEFAULT (0),
  [IsDuplicate] [bit] NOT NULL CONSTRAINT [DF_AssetPossibleDuplicates_IsComplete] DEFAULT (0)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_AssetPossibleDuplicates] on table [SJob].[AssetPossibleDuplicates]')
GO
ALTER TABLE [SJob].[AssetPossibleDuplicates] WITH NOCHECK
  ADD CONSTRAINT [PK_AssetPossibleDuplicates] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create index [IX_UQ_AssetPossibleDuplicates] on table [SJob].[AssetPossibleDuplicates]')
GO
CREATE UNIQUE INDEX [IX_UQ_AssetPossibleDuplicates]
  ON [SJob].[AssetPossibleDuplicates] ([SourceAssetID], [TargetAssetID])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_AssetPossibleDuplicates_RecordHistory] on table [SJob].[AssetPossibleDuplicates]')
GO
CREATE TRIGGER [SJob].[tg_AssetPossibleDuplicates_RecordHistory]
   ON  [SJob].[AssetPossibleDuplicates]	
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
			@TableName NVARCHAR(250) = N'AssetPossibleDuplicates',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[IsDifferent]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[IsDifferent]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[IsDifferent] IS DISTINCT FROM i.[IsDifferent])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsDifferent', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2147)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[IsDuplicate]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[IsDuplicate]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[IsDuplicate] IS DISTINCT FROM i.[IsDuplicate])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsDuplicate', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2148)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2142)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[SourceAssetID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[SourceAssetID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[SourceAssetID] IS DISTINCT FROM i.[SourceAssetID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'SourceAssetID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2145)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[TargetAssetID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[TargetAssetID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[TargetAssetID] IS DISTINCT FROM i.[TargetAssetID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'TargetAssetID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2146)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_AssetPossibleDuplicates_Assets] on table [SJob].[AssetPossibleDuplicates]')
GO
ALTER TABLE [SJob].[AssetPossibleDuplicates] WITH NOCHECK
  ADD CONSTRAINT [FK_AssetPossibleDuplicates_Assets] FOREIGN KEY ([SourceAssetID]) REFERENCES [SJob].[Assets] ([ID])
GO

PRINT (N'Create foreign key [FK_AssetPossibleDuplicates_Assets1] on table [SJob].[AssetPossibleDuplicates]')
GO
ALTER TABLE [SJob].[AssetPossibleDuplicates] WITH NOCHECK
  ADD CONSTRAINT [FK_AssetPossibleDuplicates_Assets1] FOREIGN KEY ([TargetAssetID]) REFERENCES [SJob].[Assets] ([ID])
GO
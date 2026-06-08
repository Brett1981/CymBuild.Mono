PRINT (N'Create table [SJob].[AssetMergeBatch]')
GO
CREATE TABLE [SJob].[AssetMergeBatch] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_AssetMergeBatch_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_AssetMergeBatch_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [SourceAssetId] [int] NOT NULL CONSTRAINT [DF_AssetMergeBatch_SourceAssetId] DEFAULT (-1),
  [TargetAssetId] [int] NOT NULL CONSTRAINT [DF_AssetMergeBatch_TargetAssetId] DEFAULT (-1),
  [CreatedByUserId] [int] NOT NULL CONSTRAINT [DF_AssetMergeBatch_CreatedByUserId] DEFAULT (-1),
  [CheckedByUserId] [int] NOT NULL CONSTRAINT [DF_AssetMergeBatch_CheckedByUserId] DEFAULT (-1),
  [IsComplete] [bit] NOT NULL CONSTRAINT [DF_AssetMergeBatch_IsComplete] DEFAULT (0)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_AssetMergeBatch] on table [SJob].[AssetMergeBatch]')
GO
ALTER TABLE [SJob].[AssetMergeBatch] WITH NOCHECK
  ADD CONSTRAINT [PK_AssetMergeBatch] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_AssetMergeBatch_RecordHistory] on table [SJob].[AssetMergeBatch]')
GO
CREATE TRIGGER [SJob].[tg_AssetMergeBatch_RecordHistory]
   ON  [SJob].[AssetMergeBatch]	
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
			@TableName NVARCHAR(250) = N'AssetMergeBatch',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[CheckedByUserId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[CheckedByUserId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[CheckedByUserId] IS DISTINCT FROM i.[CheckedByUserId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'CheckedByUserId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2111)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[CreatedByUserId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[CreatedByUserId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[CreatedByUserId] IS DISTINCT FROM i.[CreatedByUserId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'CreatedByUserId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2110)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[IsComplete]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[IsComplete]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[IsComplete] IS DISTINCT FROM i.[IsComplete])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsComplete', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2112)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2105)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[SourceAssetId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[SourceAssetId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[SourceAssetId] IS DISTINCT FROM i.[SourceAssetId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'SourceAssetId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2108)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[TargetAssetId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[TargetAssetId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[TargetAssetId] IS DISTINCT FROM i.[TargetAssetId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'TargetAssetId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2109)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_AssetMergeBatch_Accounts] on table [SJob].[AssetMergeBatch]')
GO
ALTER TABLE [SJob].[AssetMergeBatch] WITH NOCHECK
  ADD CONSTRAINT [FK_AssetMergeBatch_Accounts] FOREIGN KEY ([SourceAssetId]) REFERENCES [SJob].[Assets] ([ID])
GO

PRINT (N'Create foreign key [FK_AssetMergeBatch_Accounts1] on table [SJob].[AssetMergeBatch]')
GO
ALTER TABLE [SJob].[AssetMergeBatch] WITH NOCHECK
  ADD CONSTRAINT [FK_AssetMergeBatch_Accounts1] FOREIGN KEY ([TargetAssetId]) REFERENCES [SJob].[Assets] ([ID])
GO

PRINT (N'Create foreign key [FK_AssetMergeBatch_DataObjects] on table [SJob].[AssetMergeBatch]')
GO
ALTER TABLE [SJob].[AssetMergeBatch] WITH NOCHECK
  ADD CONSTRAINT [FK_AssetMergeBatch_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_AssetMergeBatch_DataObjects] on table [SJob].[AssetMergeBatch]')
GO
ALTER TABLE [SJob].[AssetMergeBatch]
  NOCHECK CONSTRAINT [FK_AssetMergeBatch_DataObjects]
GO

PRINT (N'Create foreign key [FK_AssetMergeBatch_Identities] on table [SJob].[AssetMergeBatch]')
GO
ALTER TABLE [SJob].[AssetMergeBatch] WITH NOCHECK
  ADD CONSTRAINT [FK_AssetMergeBatch_Identities] FOREIGN KEY ([CreatedByUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_AssetMergeBatch_Identities1] on table [SJob].[AssetMergeBatch]')
GO
ALTER TABLE [SJob].[AssetMergeBatch] WITH NOCHECK
  ADD CONSTRAINT [FK_AssetMergeBatch_Identities1] FOREIGN KEY ([CheckedByUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_AssetMergeBatch_RowStatus] on table [SJob].[AssetMergeBatch]')
GO
ALTER TABLE [SJob].[AssetMergeBatch] WITH NOCHECK
  ADD CONSTRAINT [FK_AssetMergeBatch_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
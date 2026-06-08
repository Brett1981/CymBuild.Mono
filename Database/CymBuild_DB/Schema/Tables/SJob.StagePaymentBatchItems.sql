PRINT (N'Create table [SJob].[StagePaymentBatchItems]')
GO
CREATE TABLE [SJob].[StagePaymentBatchItems] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_StagePaymentBatchItems_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_StagePaymentBatchItems_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [StagePaymentBatchId] [int] NOT NULL CONSTRAINT [DF_StagePaymentBatchItems_StagePaymentBatchId] DEFAULT (-1),
  [JobPaymentStageId] [int] NOT NULL CONSTRAINT [DF_StagePaymentBatchItems_JobPaymentStageId] DEFAULT (-1)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_StagePaymentBatchItems] on table [SJob].[StagePaymentBatchItems]')
GO
ALTER TABLE [SJob].[StagePaymentBatchItems] WITH NOCHECK
  ADD CONSTRAINT [PK_StagePaymentBatchItems] PRIMARY KEY CLUSTERED ([ID])
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_StagePaymentBatchItems_RecordHistory] on table [SJob].[StagePaymentBatchItems]')
GO
CREATE TRIGGER [SJob].[tg_StagePaymentBatchItems_RecordHistory]
   ON  [SJob].[StagePaymentBatchItems]	
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
			@TableName NVARCHAR(250) = N'StagePaymentBatchItems',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[JobPaymentStageId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[JobPaymentStageId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[JobPaymentStageId] IS DISTINCT FROM i.[JobPaymentStageId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'JobPaymentStageId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1614)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1610)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[StagePaymentBatchId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[StagePaymentBatchId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[StagePaymentBatchId] IS DISTINCT FROM i.[StagePaymentBatchId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'StagePaymentBatchId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1613)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_StagePaymentBatchItems_DataObjects] on table [SJob].[StagePaymentBatchItems]')
GO
ALTER TABLE [SJob].[StagePaymentBatchItems] WITH NOCHECK
  ADD CONSTRAINT [FK_StagePaymentBatchItems_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_StagePaymentBatchItems_DataObjects] on table [SJob].[StagePaymentBatchItems]')
GO
ALTER TABLE [SJob].[StagePaymentBatchItems]
  NOCHECK CONSTRAINT [FK_StagePaymentBatchItems_DataObjects]
GO

PRINT (N'Create foreign key [FK_StagePaymentBatchItems_JobPaymentStages] on table [SJob].[StagePaymentBatchItems]')
GO
ALTER TABLE [SJob].[StagePaymentBatchItems] WITH NOCHECK
  ADD CONSTRAINT [FK_StagePaymentBatchItems_JobPaymentStages] FOREIGN KEY ([JobPaymentStageId]) REFERENCES [SJob].[JobPaymentStages] ([ID])
GO

PRINT (N'Create foreign key [FK_StagePaymentBatchItems_RowStatus] on table [SJob].[StagePaymentBatchItems]')
GO
ALTER TABLE [SJob].[StagePaymentBatchItems] WITH NOCHECK
  ADD CONSTRAINT [FK_StagePaymentBatchItems_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_StagePaymentBatchItems_StagePaymentBatch] on table [SJob].[StagePaymentBatchItems]')
GO
ALTER TABLE [SJob].[StagePaymentBatchItems] WITH NOCHECK
  ADD CONSTRAINT [FK_StagePaymentBatchItems_StagePaymentBatch] FOREIGN KEY ([StagePaymentBatchId]) REFERENCES [SJob].[StagePaymentBatch] ([ID])
GO
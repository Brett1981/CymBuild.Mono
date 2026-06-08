PRINT (N'Create table [SFin].[TransactionAllocations]')
GO
CREATE TABLE [SFin].[TransactionAllocations] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DEFAULT_TransactionAllocations_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_TransactionAllocations_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [SourceTransactionID] [bigint] NOT NULL CONSTRAINT [DF_TransactionAllocations_TransactionTypeID] DEFAULT (-1),
  [TargetTransactionID] [bigint] NOT NULL CONSTRAINT [DF_TransactionAllocations_AccountID] DEFAULT (-1),
  [AllocatedAmount] [decimal](9, 2) NOT NULL CONSTRAINT [DF_TransactionAllocations_AllocatedAmount] DEFAULT (0)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_TransactionAllocations] on table [SFin].[TransactionAllocations]')
GO
ALTER TABLE [SFin].[TransactionAllocations] WITH NOCHECK
  ADD CONSTRAINT [PK_TransactionAllocations] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_TransactionAllocations_SourceTransactionId] on table [SFin].[TransactionAllocations]')
GO
CREATE INDEX [IX_TransactionAllocations_SourceTransactionId]
  ON [SFin].[TransactionAllocations] ([SourceTransactionID], [AllocatedAmount], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_TransactionAllocations_TargetTransactionId] on table [SFin].[TransactionAllocations]')
GO
CREATE INDEX [IX_TransactionAllocations_TargetTransactionId]
  ON [SFin].[TransactionAllocations] ([TargetTransactionID], [AllocatedAmount], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_TransactionAllocations_Guid] on table [SFin].[TransactionAllocations]')
GO
CREATE UNIQUE INDEX [IX_UQ_TransactionAllocations_Guid]
  ON [SFin].[TransactionAllocations] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_TransactionAllocations_RecordHistory] on table [SFin].[TransactionAllocations]')
GO
CREATE TRIGGER [SFin].[tg_TransactionAllocations_RecordHistory]
   ON  [SFin].[TransactionAllocations]	
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
			@SchemaName NVARCHAR(250) = N'SFin',
			@TableName NVARCHAR(250) = N'TransactionAllocations',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[AllocatedAmount]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[AllocatedAmount]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[AllocatedAmount] IS DISTINCT FROM i.[AllocatedAmount])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'AllocatedAmount', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 734)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 737)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[SourceTransactionID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[SourceTransactionID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[SourceTransactionID] IS DISTINCT FROM i.[SourceTransactionID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'SourceTransactionID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 739)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[TargetTransactionID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[TargetTransactionID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[TargetTransactionID] IS DISTINCT FROM i.[TargetTransactionID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'TargetTransactionID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 740)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_TransactionAllocations_DataObjects] on table [SFin].[TransactionAllocations]')
GO
ALTER TABLE [SFin].[TransactionAllocations] WITH NOCHECK
  ADD CONSTRAINT [FK_TransactionAllocations_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_TransactionAllocations_DataObjects] on table [SFin].[TransactionAllocations]')
GO
ALTER TABLE [SFin].[TransactionAllocations]
  NOCHECK CONSTRAINT [FK_TransactionAllocations_DataObjects]
GO

PRINT (N'Create foreign key [FK_TransactionAllocations_RowStatus] on table [SFin].[TransactionAllocations]')
GO
ALTER TABLE [SFin].[TransactionAllocations] WITH NOCHECK
  ADD CONSTRAINT [FK_TransactionAllocations_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_TransactionAllocations_Transactions] on table [SFin].[TransactionAllocations]')
GO
ALTER TABLE [SFin].[TransactionAllocations] WITH NOCHECK
  ADD CONSTRAINT [FK_TransactionAllocations_Transactions] FOREIGN KEY ([SourceTransactionID]) REFERENCES [SFin].[Transactions] ([ID]) ON DELETE CASCADE
GO

PRINT (N'Create foreign key [FK_TransactionAllocations_Transactions1] on table [SFin].[TransactionAllocations]')
GO
ALTER TABLE [SFin].[TransactionAllocations] WITH NOCHECK
  ADD CONSTRAINT [FK_TransactionAllocations_Transactions1] FOREIGN KEY ([TargetTransactionID]) REFERENCES [SFin].[Transactions] ([ID])
GO
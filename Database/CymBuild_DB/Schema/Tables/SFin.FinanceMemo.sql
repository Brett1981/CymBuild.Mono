PRINT (N'Create table [SFin].[FinanceMemo]')
GO
PRINT (N'Create table [SFin].[FinanceMemo]')
GO
CREATE TABLE [SFin].[FinanceMemo] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_FinanceMemo_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_FinanceMemo_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [TransactionID] [bigint] NOT NULL CONSTRAINT [DF_FinanceMemo_TransactionID] DEFAULT (-1),
  [AccountID] [int] NOT NULL CONSTRAINT [DF_FinanceMemo_AccountID] DEFAULT (-1),
  [JobID] [int] NOT NULL CONSTRAINT [DF_FinanceMemo_JobID] DEFAULT (-1),
  [Memo] [nvarchar](max) NOT NULL CONSTRAINT [DF_FinanceMemo_Memo] DEFAULT (''),
  [CreatedDateTimeUTC] [datetime2] NOT NULL CONSTRAINT [DF_FinanceMemo_CreatedDateTime] DEFAULT (getutcdate()),
  [CreatedByUserId] [int] NOT NULL CONSTRAINT [DF_FinanceMemo_CreatedByUserId] DEFAULT (-1),
  [LegacyId] [bigint] NULL,
  [LegacySystemID] [int] NOT NULL DEFAULT (-1)
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_FinanceMemo] on table [SFin].[FinanceMemo]')
GO
ALTER TABLE [SFin].[FinanceMemo] WITH NOCHECK
  ADD CONSTRAINT [PK_FinanceMemo] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_FinanceMemo_AccountId] on table [SFin].[FinanceMemo]')
GO
CREATE INDEX [IX_FinanceMemo_AccountId]
  ON [SFin].[FinanceMemo] ([RowStatus], [AccountID])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_FinanceMemo_JobId] on table [SFin].[FinanceMemo]')
GO
CREATE INDEX [IX_FinanceMemo_JobId]
  ON [SFin].[FinanceMemo] ([JobID], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_FinanceMemo_TransactionID] on table [SFin].[FinanceMemo]')
GO
CREATE INDEX [IX_FinanceMemo_TransactionID]
  ON [SFin].[FinanceMemo] ([TransactionID])
  INCLUDE ([RowStatus], [RowVersion], [Guid], [AccountID], [JobID], [Memo], [CreatedDateTimeUTC], [CreatedByUserId])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_FinanceMemo_Guid] on table [SFin].[FinanceMemo]')
GO
CREATE UNIQUE INDEX [IX_UQ_FinanceMemo_Guid]
  ON [SFin].[FinanceMemo] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_FinanceMemo_RecordHistory] on table [SFin].[FinanceMemo]')
GO
CREATE TRIGGER [SFin].[tg_FinanceMemo_RecordHistory]
   ON  [SFin].[FinanceMemo]	
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
			@TableName NVARCHAR(250) = N'FinanceMemo',
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
				VALUES(1, @SchemaName, @TableName, N'AccountID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1162)
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
				VALUES(1, @SchemaName, @TableName, N'CreatedByUserId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1163)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[CreatedDateTimeUTC]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[CreatedDateTimeUTC]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[CreatedDateTimeUTC] IS DISTINCT FROM i.[CreatedDateTimeUTC])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'CreatedDateTimeUTC', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1164)
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
				VALUES(1, @SchemaName, @TableName, N'JobID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1167)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[LegacyId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[LegacyId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[LegacyId] IS DISTINCT FROM i.[LegacyId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'LegacyId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1168)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Memo]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Memo]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Memo] IS DISTINCT FROM i.[Memo])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Memo', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1169)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1170)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[TransactionID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[TransactionID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[TransactionID] IS DISTINCT FROM i.[TransactionID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'TransactionID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1172)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_FinanceMemo_Accounts] on table [SFin].[FinanceMemo]')
GO
ALTER TABLE [SFin].[FinanceMemo] WITH NOCHECK
  ADD CONSTRAINT [FK_FinanceMemo_Accounts] FOREIGN KEY ([AccountID]) REFERENCES [SCrm].[Accounts] ([ID])
GO

PRINT (N'Create foreign key [FK_FinanceMemo_DataObjects] on table [SFin].[FinanceMemo]')
GO
ALTER TABLE [SFin].[FinanceMemo] WITH NOCHECK
  ADD CONSTRAINT [FK_FinanceMemo_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_FinanceMemo_DataObjects] on table [SFin].[FinanceMemo]')
GO
ALTER TABLE [SFin].[FinanceMemo]
  NOCHECK CONSTRAINT [FK_FinanceMemo_DataObjects]
GO

PRINT (N'Create foreign key [FK_FinanceMemo_Identities] on table [SFin].[FinanceMemo]')
GO
ALTER TABLE [SFin].[FinanceMemo] WITH NOCHECK
  ADD CONSTRAINT [FK_FinanceMemo_Identities] FOREIGN KEY ([CreatedByUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_FinanceMemo_Jobs] on table [SFin].[FinanceMemo]')
GO
ALTER TABLE [SFin].[FinanceMemo] WITH NOCHECK
  ADD CONSTRAINT [FK_FinanceMemo_Jobs] FOREIGN KEY ([JobID]) REFERENCES [SJob].[Jobs] ([ID])
GO

PRINT (N'Create foreign key [FK_FinanceMemo_RowStatus] on table [SFin].[FinanceMemo]')
GO
ALTER TABLE [SFin].[FinanceMemo] WITH NOCHECK
  ADD CONSTRAINT [FK_FinanceMemo_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_FinanceMemo_Transactions] on table [SFin].[FinanceMemo]')
GO
ALTER TABLE [SFin].[FinanceMemo] WITH NOCHECK
  ADD CONSTRAINT [FK_FinanceMemo_Transactions] FOREIGN KEY ([TransactionID]) REFERENCES [SFin].[Transactions] ([ID])
GO
PRINT (N'Create table [SJob].[JobPaymentStages]')
GO
CREATE TABLE [SJob].[JobPaymentStages] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_JobPaymentStages_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_JobPaymentStages_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [JobId] [int] NOT NULL CONSTRAINT [DF_JobPaymentStages_JobId] DEFAULT (-1),
  [StagedDate] [date] NULL,
  [AfterStageId] [int] NOT NULL CONSTRAINT [DF_JobPaymentStages_AfterStageId] DEFAULT (-1),
  [Value] [decimal](18, 2) NOT NULL CONSTRAINT [DF_JobPaymentStages_Value] DEFAULT (0)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_JobPaymentStages] on table [SJob].[JobPaymentStages]')
GO
ALTER TABLE [SJob].[JobPaymentStages] WITH NOCHECK
  ADD CONSTRAINT [PK_JobPaymentStages] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 90)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_JobPaymentStage_Job] on table [SJob].[JobPaymentStages]')
GO
CREATE INDEX [IX_JobPaymentStage_Job]
  ON [SJob].[JobPaymentStages] ([JobId], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_JobPaymentStages_Guid] on table [SJob].[JobPaymentStages]')
GO
CREATE UNIQUE INDEX [IX_UQ_JobPaymentStages_Guid]
  ON [SJob].[JobPaymentStages] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_JobPaymentStages_RecordHistory] on table [SJob].[JobPaymentStages]')
GO
CREATE TRIGGER [SJob].[tg_JobPaymentStages_RecordHistory]
   ON  [SJob].[JobPaymentStages]	
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
			@TableName NVARCHAR(250) = N'JobPaymentStages',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[AfterStageId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[AfterStageId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[AfterStageId] IS DISTINCT FROM i.[AfterStageId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'AfterStageId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1627)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[JobId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[JobId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[JobId] IS DISTINCT FROM i.[JobId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'JobId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1625)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1622)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[StagedDate]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[StagedDate]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[StagedDate] IS DISTINCT FROM i.[StagedDate])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'StagedDate', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1626)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Value]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Value]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Value] IS DISTINCT FROM i.[Value])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Value', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1628)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_JobPaymentStages_DataObjects] on table [SJob].[JobPaymentStages]')
GO
ALTER TABLE [SJob].[JobPaymentStages] WITH NOCHECK
  ADD CONSTRAINT [FK_JobPaymentStages_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_JobPaymentStages_DataObjects] on table [SJob].[JobPaymentStages]')
GO
ALTER TABLE [SJob].[JobPaymentStages]
  NOCHECK CONSTRAINT [FK_JobPaymentStages_DataObjects]
GO

PRINT (N'Create foreign key [FK_JobPaymentStages_Jobs] on table [SJob].[JobPaymentStages]')
GO
ALTER TABLE [SJob].[JobPaymentStages] WITH NOCHECK
  ADD CONSTRAINT [FK_JobPaymentStages_Jobs] FOREIGN KEY ([JobId]) REFERENCES [SJob].[Jobs] ([ID])
GO

PRINT (N'Create foreign key [FK_JobPaymentStages_RibaStages] on table [SJob].[JobPaymentStages]')
GO
ALTER TABLE [SJob].[JobPaymentStages] WITH NOCHECK
  ADD CONSTRAINT [FK_JobPaymentStages_RibaStages] FOREIGN KEY ([AfterStageId]) REFERENCES [SJob].[RibaStages] ([ID])
GO

PRINT (N'Create foreign key [FK_JobPaymentStages_RowStatus] on table [SJob].[JobPaymentStages]')
GO
ALTER TABLE [SJob].[JobPaymentStages] WITH NOCHECK
  ADD CONSTRAINT [FK_JobPaymentStages_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
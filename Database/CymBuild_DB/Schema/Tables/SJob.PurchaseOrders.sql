PRINT (N'Create table [SJob].[PurchaseOrders]')
GO
PRINT (N'Create table [SJob].[PurchaseOrders]')
GO
CREATE TABLE [SJob].[PurchaseOrders] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_PurchaseOrders_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_PurchaseOrders_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Number] [nvarchar](15) NOT NULL CONSTRAINT [DF_PurchaseOrders_Number] DEFAULT (''),
  [Description] [nvarchar](max) NOT NULL CONSTRAINT [DF_PurchaseOrders_Description] DEFAULT (''),
  [StageId] [int] NOT NULL CONSTRAINT [DF_PurchaseOrders_StageId] DEFAULT (-1),
  [SiteId] [int] NOT NULL CONSTRAINT [DF_PurchaseOrders_SiteId] DEFAULT (-1),
  [Value] [decimal](19, 2) NOT NULL CONSTRAINT [DF_PurchaseOrders_Value] DEFAULT (0.0),
  [DateReceived] [date] NULL,
  [ValidUntilDate] [date] NULL,
  [ActivityId] [bigint] NOT NULL CONSTRAINT [DF_PurchaseOrders_ActivityId] DEFAULT (-1),
  [JobId] [int] NOT NULL CONSTRAINT [DF_PurchaseOrders_JobId] DEFAULT (-1)
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_PurchaseOrders] on table [SJob].[PurchaseOrders]')
GO
ALTER TABLE [SJob].[PurchaseOrders] WITH NOCHECK
  ADD CONSTRAINT [PK_PurchaseOrders] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_PurchaseOrders_RecordHistory] on table [SJob].[PurchaseOrders]')
GO
CREATE TRIGGER [SJob].[tg_PurchaseOrders_RecordHistory]
   ON  [SJob].[PurchaseOrders]	
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
			@TableName NVARCHAR(250) = N'PurchaseOrders',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ActivityId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ActivityId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ActivityId] IS DISTINCT FROM i.[ActivityId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ActivityId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2546)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[DateReceived]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[DateReceived]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[DateReceived] IS DISTINCT FROM i.[DateReceived])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'DateReceived', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2549)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Description]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Description]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Description] IS DISTINCT FROM i.[Description])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Description', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2544)
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
				VALUES(1, @SchemaName, @TableName, N'JobId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2555)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Number]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Number]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Number] IS DISTINCT FROM i.[Number])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Number', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2554)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2545)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[SiteId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[SiteId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[SiteId] IS DISTINCT FROM i.[SiteId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'SiteId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2550)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[StageId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[StageId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[StageId] IS DISTINCT FROM i.[StageId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'StageId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2551)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ValidUntilDate]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ValidUntilDate]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ValidUntilDate] IS DISTINCT FROM i.[ValidUntilDate])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ValidUntilDate', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2553)
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
				VALUES(1, @SchemaName, @TableName, N'Value', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2548)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_PurchaseOrders_ActivityId] on table [SJob].[PurchaseOrders]')
GO
ALTER TABLE [SJob].[PurchaseOrders] WITH NOCHECK
  ADD CONSTRAINT [FK_PurchaseOrders_ActivityId] FOREIGN KEY ([ActivityId]) REFERENCES [SJob].[Activities] ([ID])
GO

PRINT (N'Create foreign key [FK_PurchaseOrders_DataObjects] on table [SJob].[PurchaseOrders]')
GO
ALTER TABLE [SJob].[PurchaseOrders] WITH NOCHECK
  ADD CONSTRAINT [FK_PurchaseOrders_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_PurchaseOrders_DataObjects] on table [SJob].[PurchaseOrders]')
GO
ALTER TABLE [SJob].[PurchaseOrders]
  NOCHECK CONSTRAINT [FK_PurchaseOrders_DataObjects]
GO

PRINT (N'Create foreign key [FK_PurchaseOrders_JobId] on table [SJob].[PurchaseOrders]')
GO
ALTER TABLE [SJob].[PurchaseOrders] WITH NOCHECK
  ADD CONSTRAINT [FK_PurchaseOrders_JobId] FOREIGN KEY ([JobId]) REFERENCES [SJob].[Jobs] ([ID])
GO

PRINT (N'Create foreign key [FK_PurchaseOrders_RowStatus] on table [SJob].[PurchaseOrders]')
GO
ALTER TABLE [SJob].[PurchaseOrders] WITH NOCHECK
  ADD CONSTRAINT [FK_PurchaseOrders_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_PurchaseOrders_SiteId] on table [SJob].[PurchaseOrders]')
GO
ALTER TABLE [SJob].[PurchaseOrders] WITH NOCHECK
  ADD CONSTRAINT [FK_PurchaseOrders_SiteId] FOREIGN KEY ([SiteId]) REFERENCES [SJob].[Assets] ([ID])
GO

PRINT (N'Create foreign key [FK_PurchaseOrders_StageId] on table [SJob].[PurchaseOrders]')
GO
ALTER TABLE [SJob].[PurchaseOrders] WITH NOCHECK
  ADD CONSTRAINT [FK_PurchaseOrders_StageId] FOREIGN KEY ([StageId]) REFERENCES [SJob].[RibaStages] ([ID])
GO
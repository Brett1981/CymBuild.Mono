PRINT (N'Create table [SFin].[TransactionDetails]')
GO
CREATE TABLE [SFin].[TransactionDetails] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DEFAULT_TransactionDetails_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_TransactionDetails_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [TransactionID] [bigint] NOT NULL CONSTRAINT [DF_TransactionDetails_TransactionID] DEFAULT (-1),
  [MilestoneID] [bigint] NOT NULL CONSTRAINT [DF_TransactionDetails_MilestoneID] DEFAULT (-1),
  [ActivityID] [bigint] NOT NULL CONSTRAINT [DF_TransactionDetails_ActivityID] DEFAULT (-1),
  [Net] [decimal](9, 2) NOT NULL CONSTRAINT [DF_TransactionDetails_Net] DEFAULT (0),
  [Vat] [decimal](9, 2) NOT NULL CONSTRAINT [DF_TransactionDetails_Vat] DEFAULT (0),
  [Gross] [decimal](9, 2) NOT NULL CONSTRAINT [DF_TransactionDetails_Gross] DEFAULT (0),
  [VatRate] [decimal](9, 2) NOT NULL CONSTRAINT [DF_TransactionDetails_VatRate] DEFAULT (0),
  [Description] [nvarchar](2000) NOT NULL CONSTRAINT [DF_TransactionDetails_Description] DEFAULT (''),
  [LegacyId] [decimal](18, 2) NULL,
  [JobPaymentStageId] [int] NOT NULL CONSTRAINT [DF_TransactionDetails_JobPaymentStageId] DEFAULT (-1),
  [InvoiceRequestItemId] [bigint] NOT NULL CONSTRAINT [DF_TransactionDetails_InvoiceRequestId] DEFAULT (-1),
  [LegacySystemID] [int] NOT NULL DEFAULT (-1),
  [RIBAStageId] [int] NULL,
  [Qty] [decimal](18, 4) NOT NULL CONSTRAINT [DF_SFin_TransactionDetails_Qty] DEFAULT (1),
  [VatCodeID] [int] NOT NULL CONSTRAINT [DF_TransactionDetails_VatCodeID] DEFAULT (1)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_TransactionDetails] on table [SFin].[TransactionDetails]')
GO
ALTER TABLE [SFin].[TransactionDetails] WITH NOCHECK
  ADD CONSTRAINT [PK_TransactionDetails] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create index [IX_SFin_TransactionDetails_1424475993] on table [SFin].[TransactionDetails]')
GO
CREATE INDEX [IX_SFin_TransactionDetails_1424475993]
  ON [SFin].[TransactionDetails] ([RowStatus])
  INCLUDE ([TransactionID], [InvoiceRequestItemId])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SFin_TransactionDetails_19823120] on table [SFin].[TransactionDetails]')
GO
CREATE INDEX [IX_SFin_TransactionDetails_19823120]
  ON [SFin].[TransactionDetails] ([RowStatus], [TransactionID], [Gross])
  INCLUDE ([MilestoneID])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SFin_TransactionDetails_2029117089] on table [SFin].[TransactionDetails]')
GO
CREATE INDEX [IX_SFin_TransactionDetails_2029117089]
  ON [SFin].[TransactionDetails] ([RowStatus])
  INCLUDE ([InvoiceRequestItemId])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SFin_TransactionDetails_2086222523] on table [SFin].[TransactionDetails]')
GO
CREATE INDEX [IX_SFin_TransactionDetails_2086222523]
  ON [SFin].[TransactionDetails] ([RowStatus])
  INCLUDE ([TransactionID], [Gross])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SFin_TransactionDetails_370948510] on table [SFin].[TransactionDetails]')
GO
CREATE INDEX [IX_SFin_TransactionDetails_370948510]
  ON [SFin].[TransactionDetails] ([MilestoneID])
  INCLUDE ([TransactionID])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SFin_TransactionDetails_732729915] on table [SFin].[TransactionDetails]')
GO
CREATE INDEX [IX_SFin_TransactionDetails_732729915]
  ON [SFin].[TransactionDetails] ([RowStatus])
  INCLUDE ([ActivityID])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_TransactionDetail_TransactionId] on table [SFin].[TransactionDetails]')
GO
CREATE INDEX [IX_TransactionDetail_TransactionId]
  ON [SFin].[TransactionDetails] ([TransactionID], [RowStatus])
  INCLUDE ([Gross], [Net], [Vat])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_TransactionDetails_ActivityId] on table [SFin].[TransactionDetails]')
GO
CREATE INDEX [IX_TransactionDetails_ActivityId]
  ON [SFin].[TransactionDetails] ([ActivityID], [RowStatus])
  INCLUDE ([Net], [TransactionID])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_TransactionDetails_InvoiceRequestItem] on table [SFin].[TransactionDetails]')
GO
CREATE INDEX [IX_TransactionDetails_InvoiceRequestItem]
  ON [SFin].[TransactionDetails] ([InvoiceRequestItemId])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_TransactionDetails_Guid] on table [SFin].[TransactionDetails]')
GO
CREATE UNIQUE INDEX [IX_UQ_TransactionDetails_Guid]
  ON [SFin].[TransactionDetails] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_TransactionDetails_RecordHistory] on table [SFin].[TransactionDetails]')
GO
CREATE TRIGGER [SFin].[tg_TransactionDetails_RecordHistory]
   ON  [SFin].[TransactionDetails]	
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
			@TableName NVARCHAR(250) = N'TransactionDetails',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ActivityID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ActivityID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ActivityID] IS DISTINCT FROM i.[ActivityID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ActivityID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 490)
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
				VALUES(1, @SchemaName, @TableName, N'Description', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 491)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Gross]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Gross]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Gross] IS DISTINCT FROM i.[Gross])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Gross', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 492)
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
				VALUES(1, @SchemaName, @TableName, N'JobPaymentStageId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1620)
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
				VALUES(1, @SchemaName, @TableName, N'LegacyId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1181)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[MilestoneID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[MilestoneID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[MilestoneID] IS DISTINCT FROM i.[MilestoneID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'MilestoneID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 495)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Net]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Net]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Net] IS DISTINCT FROM i.[Net])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Net', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 496)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 497)
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
				VALUES(1, @SchemaName, @TableName, N'TransactionID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 499)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Vat]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Vat]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Vat] IS DISTINCT FROM i.[Vat])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Vat', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 500)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[VatRate]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[VatRate]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[VatRate] IS DISTINCT FROM i.[VatRate])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'VatRate', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 501)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_SFin_TransactionDetails_VatCodes] on table [SFin].[TransactionDetails]')
GO
ALTER TABLE [SFin].[TransactionDetails] WITH NOCHECK
  ADD CONSTRAINT [FK_SFin_TransactionDetails_VatCodes] FOREIGN KEY ([VatCodeID]) REFERENCES [SFin].[VatCodes] ([ID])
GO

PRINT (N'Create foreign key [FK_TransactionDetails_Activities] on table [SFin].[TransactionDetails]')
GO
ALTER TABLE [SFin].[TransactionDetails] WITH NOCHECK
  ADD CONSTRAINT [FK_TransactionDetails_Activities] FOREIGN KEY ([ActivityID]) REFERENCES [SJob].[Activities] ([ID])
GO

PRINT (N'Create foreign key [FK_TransactionDetails_DataObjects] on table [SFin].[TransactionDetails]')
GO
ALTER TABLE [SFin].[TransactionDetails] WITH NOCHECK
  ADD CONSTRAINT [FK_TransactionDetails_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_TransactionDetails_DataObjects] on table [SFin].[TransactionDetails]')
GO
ALTER TABLE [SFin].[TransactionDetails]
  NOCHECK CONSTRAINT [FK_TransactionDetails_DataObjects]
GO

PRINT (N'Create foreign key [FK_TransactionDetails_InvoiceRequestItems] on table [SFin].[TransactionDetails]')
GO
ALTER TABLE [SFin].[TransactionDetails] WITH NOCHECK
  ADD CONSTRAINT [FK_TransactionDetails_InvoiceRequestItems] FOREIGN KEY ([InvoiceRequestItemId]) REFERENCES [SFin].[InvoiceRequestItems] ([ID])
GO

PRINT (N'Create foreign key [FK_TransactionDetails_Milestones] on table [SFin].[TransactionDetails]')
GO
ALTER TABLE [SFin].[TransactionDetails] WITH NOCHECK
  ADD CONSTRAINT [FK_TransactionDetails_Milestones] FOREIGN KEY ([MilestoneID]) REFERENCES [SJob].[Milestones] ([ID])
GO

PRINT (N'Create foreign key [FK_TransactionDetails_RibaStages] on table [SFin].[TransactionDetails]')
GO
ALTER TABLE [SFin].[TransactionDetails] WITH NOCHECK
  ADD CONSTRAINT [FK_TransactionDetails_RibaStages] FOREIGN KEY ([RIBAStageId]) REFERENCES [SJob].[RibaStages] ([ID])
GO

PRINT (N'Create foreign key [FK_TransactionDetails_RowStatus] on table [SFin].[TransactionDetails]')
GO
ALTER TABLE [SFin].[TransactionDetails] WITH NOCHECK
  ADD CONSTRAINT [FK_TransactionDetails_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_TransactionDetails_TransactionDetails] on table [SFin].[TransactionDetails]')
GO
ALTER TABLE [SFin].[TransactionDetails] WITH NOCHECK
  ADD CONSTRAINT [FK_TransactionDetails_TransactionDetails] FOREIGN KEY ([ID]) REFERENCES [SFin].[TransactionDetails] ([ID])
GO

PRINT (N'Create foreign key [FK_TransactionDetails_Transactions] on table [SFin].[TransactionDetails]')
GO
ALTER TABLE [SFin].[TransactionDetails] WITH NOCHECK
  ADD CONSTRAINT [FK_TransactionDetails_Transactions] FOREIGN KEY ([TransactionID]) REFERENCES [SFin].[Transactions] ([ID]) ON DELETE CASCADE
GO
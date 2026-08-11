PRINT (N'Create table [SFin].[Transactions]')
GO
CREATE TABLE [SFin].[Transactions] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DEFAULT_Transactions_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_Transactions_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [TransactionTypeID] [smallint] NOT NULL CONSTRAINT [DF_Transactions_TransactionTypeID] DEFAULT (-1),
  [AccountID] [int] NOT NULL CONSTRAINT [DF_Transactions_AccountID] DEFAULT (-1),
  [JobID] [int] NOT NULL CONSTRAINT [DF_Transactions_JobID] DEFAULT (-1),
  [Number] [nvarchar](30) NOT NULL CONSTRAINT [DF_Transactions_Number] DEFAULT (''),
  [Date] [date] NOT NULL CONSTRAINT [DF_Transactions_Date] DEFAULT (getdate()),
  [LegacyId] [decimal](18, 2) NULL,
  [PurchaseOrderNumber] [nvarchar](28) NOT NULL CONSTRAINT [DF_Transactions_PurchaseOrderNumber] DEFAULT (''),
  [SageTransactionReference] [nvarchar](50) NOT NULL CONSTRAINT [DF_Transactions_SageTransactionNumber] DEFAULT (''),
  [OrganisationalUnitId] [int] NOT NULL CONSTRAINT [DF_Transactions_OrganisationalUnit] DEFAULT (-1),
  [CreatedByUserId] [int] NOT NULL CONSTRAINT [DF_Transactions_CreatedByUserId] DEFAULT (-1),
  [SurveyorUserId] [int] NOT NULL CONSTRAINT [DF_Transactions_SurveyorUserId] DEFAULT (-1),
  [CreatedDateTimeUTC] [datetime2] NOT NULL CONSTRAINT [DF_Transactions_CreatedDateTimeUTC] DEFAULT (getutcdate()),
  [CreditTermsId] [int] NOT NULL CONSTRAINT [DF_Transactions_CreditTermsId] DEFAULT (-1),
  [LegacySystemID] [int] NOT NULL DEFAULT (-1),
  [ExpectedDate] [date] NULL,
  [Batched] [bit] NOT NULL CONSTRAINT [DF_Transactions_Batched] DEFAULT (0),
  [ReservedInvoiceNumber] [nvarchar](30) NOT NULL CONSTRAINT [DF_Transactions_ReservedInvoiceNumber] DEFAULT (N''),
  [SageInvoiceNumber] [nvarchar](50) NULL,
  [SageSalesOrderNumber] [nvarchar](50) NULL,
  [SageInvoiceGeneratedDateTimeUtc] [datetime2] NULL
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_Transactions] on table [SFin].[Transactions]')
GO
ALTER TABLE [SFin].[Transactions] WITH NOCHECK
  ADD CONSTRAINT [PK_Transactions] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create index [IX_SFin_Transactions_1395927643] on table [SFin].[Transactions]')
GO
CREATE INDEX [IX_SFin_Transactions_1395927643]
  ON [SFin].[Transactions] ([RowStatus])
  INCLUDE ([AccountID], [JobID], [Number])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SFin_Transactions_1492766870] on table [SFin].[Transactions]')
GO
CREATE INDEX [IX_SFin_Transactions_1492766870]
  ON [SFin].[Transactions] ([RowStatus])
  INCLUDE ([Guid], [AccountID], [JobID], [Number], [Date], [SageTransactionReference], [ReservedInvoiceNumber])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SFin_Transactions_1751799825] on table [SFin].[Transactions]')
GO
CREATE INDEX [IX_SFin_Transactions_1751799825]
  ON [SFin].[Transactions] ([CreditTermsId])
  INCLUDE ([RowStatus], [TransactionTypeID], [Date])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SFin_Transactions_1772329717] on table [SFin].[Transactions]')
GO
CREATE INDEX [IX_SFin_Transactions_1772329717]
  ON [SFin].[Transactions] ([RowStatus])
  INCLUDE ([TransactionTypeID], [Date], [CreditTermsId])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SFin_Transactions_1948880065] on table [SFin].[Transactions]')
GO
CREATE INDEX [IX_SFin_Transactions_1948880065]
  ON [SFin].[Transactions] ([JobID])
  INCLUDE ([RowStatus], [RowVersion], [Guid], [TransactionTypeID], [AccountID], [Number], [Date], [LegacyId], [PurchaseOrderNumber], [SageTransactionReference], [OrganisationalUnitId], [CreatedByUserId], [SurveyorUserId], [CreatedDateTimeUTC], [CreditTermsId], [LegacySystemID], [ExpectedDate], [Batched], [ReservedInvoiceNumber], [SageInvoiceNumber], [SageSalesOrderNumber], [SageInvoiceGeneratedDateTimeUtc])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SFin_Transactions_19813955] on table [SFin].[Transactions]')
GO
CREATE INDEX [IX_SFin_Transactions_19813955]
  ON [SFin].[Transactions] ([Batched], [ID], [RowStatus])
  INCLUDE ([Guid], [AccountID])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SFin_Transactions_2071312223] on table [SFin].[Transactions]')
GO
CREATE INDEX [IX_SFin_Transactions_2071312223]
  ON [SFin].[Transactions] ([Number], [RowStatus])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SFin_Transactions_450070317] on table [SFin].[Transactions]')
GO
CREATE INDEX [IX_SFin_Transactions_450070317]
  ON [SFin].[Transactions] ([JobID])
  INCLUDE ([RowStatus], [TransactionTypeID], [Date], [CreditTermsId], [ExpectedDate])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SFin_Transactions_724871123] on table [SFin].[Transactions]')
GO
CREATE INDEX [IX_SFin_Transactions_724871123]
  ON [SFin].[Transactions] ([RowStatus])
  INCLUDE ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SFin_Transactions_794618427] on table [SFin].[Transactions]')
GO
CREATE INDEX [IX_SFin_Transactions_794618427]
  ON [SFin].[Transactions] ([SageTransactionReference], [RowStatus])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SFin_Transactions_80284921] on table [SFin].[Transactions]')
GO
CREATE INDEX [IX_SFin_Transactions_80284921]
  ON [SFin].[Transactions] ([JobID])
  INCLUDE ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Transactions_Account] on table [SFin].[Transactions]')
GO
CREATE INDEX [IX_Transactions_Account]
  ON [SFin].[Transactions] ([AccountID], [Date])
  INCLUDE ([RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Transactions_JobId] on table [SFin].[Transactions]')
GO
CREATE INDEX [IX_Transactions_JobId]
  ON [SFin].[Transactions] ([JobID], [RowStatus])
  INCLUDE ([Number])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Transactions_MyInvoicing] on table [SFin].[Transactions]')
GO
CREATE INDEX [IX_Transactions_MyInvoicing]
  ON [SFin].[Transactions] ([Date], [RowStatus], [ID])
  INCLUDE ([TransactionTypeID], [AccountID], [JobID], [Guid])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254) AND [ID]>(0))
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Transactions_TransactionType] on table [SFin].[Transactions]')
GO
CREATE INDEX [IX_Transactions_TransactionType]
  ON [SFin].[Transactions] ([TransactionTypeID], [RowStatus])
  INCLUDE ([CreditTermsId])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_Transactions_Guid] on table [SFin].[Transactions]')
GO
CREATE UNIQUE INDEX [IX_UQ_Transactions_Guid]
  ON [SFin].[Transactions] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_Transactions_RecordHistory] on table [SFin].[Transactions]')
GO
CREATE TRIGGER [SFin].[tg_Transactions_RecordHistory]
   ON  [SFin].[Transactions]	
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
			@TableName NVARCHAR(250) = N'Transactions',
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
				VALUES(1, @SchemaName, @TableName, N'AccountID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 481)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Batched]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Batched]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Batched] IS DISTINCT FROM i.[Batched])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Batched', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2588)
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
				VALUES(1, @SchemaName, @TableName, N'CreatedByUserId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1202)
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
				VALUES(1, @SchemaName, @TableName, N'CreatedDateTimeUTC', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1203)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[CreditTermsId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[CreditTermsId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[CreditTermsId] IS DISTINCT FROM i.[CreditTermsId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'CreditTermsId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1216)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Date]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Date]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Date] IS DISTINCT FROM i.[Date])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Date', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 482)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ExpectedDate]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ExpectedDate]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ExpectedDate] IS DISTINCT FROM i.[ExpectedDate])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ExpectedDate', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2776)
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
				VALUES(1, @SchemaName, @TableName, N'JobID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 485)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[LegacySystemID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[LegacySystemID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[LegacySystemID] IS DISTINCT FROM i.[LegacySystemID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'LegacySystemID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2777)
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
				VALUES(1, @SchemaName, @TableName, N'Number', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 486)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[OrganisationalUnitId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[OrganisationalUnitId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[OrganisationalUnitId] IS DISTINCT FROM i.[OrganisationalUnitId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'OrganisationalUnitId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1182)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[PurchaseOrderNumber]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[PurchaseOrderNumber]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[PurchaseOrderNumber] IS DISTINCT FROM i.[PurchaseOrderNumber])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'PurchaseOrderNumber', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1154)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ReservedInvoiceNumber]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ReservedInvoiceNumber]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ReservedInvoiceNumber] IS DISTINCT FROM i.[ReservedInvoiceNumber])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ReservedInvoiceNumber', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2775)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 487)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[SageTransactionReference]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[SageTransactionReference]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[SageTransactionReference] IS DISTINCT FROM i.[SageTransactionReference])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'SageTransactionReference', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1174)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[SurveyorUserId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[SurveyorUserId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[SurveyorUserId] IS DISTINCT FROM i.[SurveyorUserId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'SurveyorUserId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1204)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[TransactionTypeID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[TransactionTypeID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[TransactionTypeID] IS DISTINCT FROM i.[TransactionTypeID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'TransactionTypeID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 489)
			END 
			
			
			END
		END
		
		
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tr_Transactions_RecordBatchApprovalTransition] on table [SFin].[Transactions]')
GO
CREATE TRIGGER [SFin].[tr_Transactions_RecordBatchApprovalTransition]
ON [SFin].[Transactions]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF (ISNULL(CONVERT(INT, SESSION_CONTEXT(N'S_disable_triggers')), 0) = 1)
        RETURN;

    IF NOT UPDATE(Batched)
        RETURN;

    DECLARE
        @TransactionID BIGINT,
        @TransactionGuid UNIQUEIDENTIFIER,
        @SurveyorUserId INT,
        @CreatedByUserId INT;

    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            i.ID,
            i.Guid,
            i.SurveyorUserId,
            COALESCE(CONVERT(INT, SESSION_CONTEXT(N'user_id')), i.CreatedByUserId, -1) AS CreatedByUserId
        FROM inserted AS i
        INNER JOIN deleted AS d
            ON d.ID = i.ID
        WHERE i.RowStatus <> 0
          AND i.RowStatus <> 254
          AND d.RowStatus <> 0
          AND d.RowStatus <> 254
          AND ISNULL(d.Batched, 0) = 1
          AND ISNULL(i.Batched, 0) = 0;

    OPEN cur;

    FETCH NEXT FROM cur INTO
        @TransactionID,
        @TransactionGuid,
        @SurveyorUserId,
        @CreatedByUserId;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC SFin.TransactionSageSubmission_EnsureQueued
             @TransactionID = @TransactionID,
             @TransactionGuid = @TransactionGuid,
             @CreatedByUserId = @CreatedByUserId,
             @SurveyorUserId = @SurveyorUserId,
             @Comment = N'Finance approval detected from Batched 1 to 0.',
             @SuppressResult = 1;

        FETCH NEXT FROM cur INTO
            @TransactionID,
            @TransactionGuid,
            @SurveyorUserId,
            @CreatedByUserId;
    END

    CLOSE cur;
    DEALLOCATE cur;
END;
GO

PRINT (N'Create foreign key [FK_Transactions_Accounts] on table [SFin].[Transactions]')
GO
ALTER TABLE [SFin].[Transactions] WITH NOCHECK
  ADD CONSTRAINT [FK_Transactions_Accounts] FOREIGN KEY ([AccountID]) REFERENCES [SCrm].[Accounts] ([ID])
GO

PRINT (N'Create foreign key [FK_Transactions_CreditTerms] on table [SFin].[Transactions]')
GO
ALTER TABLE [SFin].[Transactions] WITH NOCHECK
  ADD CONSTRAINT [FK_Transactions_CreditTerms] FOREIGN KEY ([CreditTermsId]) REFERENCES [SFin].[CreditTerms] ([ID])
GO

PRINT (N'Create foreign key [FK_Transactions_DataObjects] on table [SFin].[Transactions]')
GO
ALTER TABLE [SFin].[Transactions] WITH NOCHECK
  ADD CONSTRAINT [FK_Transactions_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_Transactions_DataObjects] on table [SFin].[Transactions]')
GO
ALTER TABLE [SFin].[Transactions]
  NOCHECK CONSTRAINT [FK_Transactions_DataObjects]
GO

PRINT (N'Create foreign key [FK_Transactions_Identities] on table [SFin].[Transactions]')
GO
ALTER TABLE [SFin].[Transactions] WITH NOCHECK
  ADD CONSTRAINT [FK_Transactions_Identities] FOREIGN KEY ([CreatedByUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_Transactions_Identities1] on table [SFin].[Transactions]')
GO
ALTER TABLE [SFin].[Transactions] WITH NOCHECK
  ADD CONSTRAINT [FK_Transactions_Identities1] FOREIGN KEY ([SurveyorUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_Transactions_Jobs] on table [SFin].[Transactions]')
GO
ALTER TABLE [SFin].[Transactions] WITH NOCHECK
  ADD CONSTRAINT [FK_Transactions_Jobs] FOREIGN KEY ([JobID]) REFERENCES [SJob].[Jobs] ([ID])
GO

PRINT (N'Create foreign key [FK_Transactions_OrganisationalUnits] on table [SFin].[Transactions]')
GO
ALTER TABLE [SFin].[Transactions] WITH NOCHECK
  ADD CONSTRAINT [FK_Transactions_OrganisationalUnits] FOREIGN KEY ([OrganisationalUnitId]) REFERENCES [SCore].[OrganisationalUnits] ([ID])
GO

PRINT (N'Create foreign key [FK_Transactions_RowStatus] on table [SFin].[Transactions]')
GO
ALTER TABLE [SFin].[Transactions] WITH NOCHECK
  ADD CONSTRAINT [FK_Transactions_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_Transactions_TransactionTypes] on table [SFin].[Transactions]')
GO
ALTER TABLE [SFin].[Transactions] WITH NOCHECK
  ADD CONSTRAINT [FK_Transactions_TransactionTypes] FOREIGN KEY ([TransactionTypeID]) REFERENCES [SFin].[TransactionTypes] ([ID])
GO
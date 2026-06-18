PRINT (N'Create table [SFin].[InvoiceRequests]')
GO
CREATE TABLE [SFin].[InvoiceRequests] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DEFAULT_InvoiceRequests_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_InvoiceRequests_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Notes] [nvarchar](max) NOT NULL CONSTRAINT [DF_InvoiceRequests_Notes] DEFAULT (''),
  [RequesterUserId] [int] NOT NULL CONSTRAINT [DF_InvoiceRequests_RequesterUserId] DEFAULT (-1),
  [CreatedDateTimeUTC] [datetime2] NOT NULL CONSTRAINT [DF_InvoiceRequests_CreatedDateTimeUTC] DEFAULT (getutcdate()),
  [JobId] [int] NOT NULL CONSTRAINT [DF_InvoiceRequests_JobId] DEFAULT (-1),
  [LegacyId] [int] NULL,
  [LegacySystemID] [int] NOT NULL DEFAULT (-1),
  [InvoicingType] [nvarchar](10) NOT NULL DEFAULT (N''),
  [ExpectedDate] [date] NULL,
  [ManualStatus] [bit] NOT NULL DEFAULT (0),
  [InvoicePaymentStatusID] [bigint] NOT NULL CONSTRAINT [DF_InvoiceRequests_InvoicePaymentStatusID] DEFAULT (-1),
  [IsAutomated] [bit] NOT NULL CONSTRAINT [DF_InvoiceRequests_IsAutomated] DEFAULT (0),
  [IsZeroValuePlaceholder] [bit] NOT NULL CONSTRAINT [DF_InvoiceRequests_IsZeroValuePlaceholder] DEFAULT (0),
  [ReconciliationRequired] [bit] NOT NULL CONSTRAINT [DF_InvoiceRequests_ReconciliationRequired] DEFAULT (0),
  [ReconciliationReason] [nvarchar](200) NOT NULL CONSTRAINT [DF_InvoiceRequests_ReconciliationReason] DEFAULT (N''),
  [SourceType] [nvarchar](50) NOT NULL CONSTRAINT [DF_InvoiceRequests_SourceType] DEFAULT (N''),
  [SourceGuid] [uniqueidentifier] NULL,
  [SourceIntId] [int] NULL,
  [AutomationRunGuid] [uniqueidentifier] NULL,
  [InvoiceBatchGuid] [uniqueidentifier] NULL,
  [BlockedReason] [nvarchar](200) NOT NULL CONSTRAINT [DF_InvoiceRequests_BlockedReason] DEFAULT (N''),
  [FinanceAccountGuid] [uniqueidentifier] NULL,
  [IsMerged] [bit] NOT NULL CONSTRAINT [DF_InvoiceRequests_IsMerged] DEFAULT (0),
  [RIBAStageId] [int] NULL
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_InvoiceRequests] on table [SFin].[InvoiceRequests]')
GO
ALTER TABLE [SFin].[InvoiceRequests] WITH NOCHECK
  ADD CONSTRAINT [PK_InvoiceRequests] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_InvoiceRequests_AutomationRunGuid] on table [SFin].[InvoiceRequests]')
GO
CREATE INDEX [IX_InvoiceRequests_AutomationRunGuid]
  ON [SFin].[InvoiceRequests] ([AutomationRunGuid], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254) AND [AutomationRunGuid] IS NOT NULL)
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_InvoiceRequests_InvoiceBatchGuid] on table [SFin].[InvoiceRequests]')
GO
CREATE INDEX [IX_InvoiceRequests_InvoiceBatchGuid]
  ON [SFin].[InvoiceRequests] ([InvoiceBatchGuid], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254) AND [InvoiceBatchGuid] IS NOT NULL)
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SFin_InvoiceRequests_1301083792] on table [SFin].[InvoiceRequests]')
GO
CREATE INDEX [IX_SFin_InvoiceRequests_1301083792]
  ON [SFin].[InvoiceRequests] ([JobId], [SourceType], [SourceGuid])
  INCLUDE ([RowStatus], [IsMerged])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SFin_InvoiceRequests_1303242085] on table [SFin].[InvoiceRequests]')
GO
CREATE INDEX [IX_SFin_InvoiceRequests_1303242085]
  ON [SFin].[InvoiceRequests] ([IsAutomated], [SourceType], [RowStatus], [InvoicingType])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SFin_InvoiceRequests_1618878386] on table [SFin].[InvoiceRequests]')
GO
CREATE INDEX [IX_SFin_InvoiceRequests_1618878386]
  ON [SFin].[InvoiceRequests] ([IsAutomated], [SourceType], [RowStatus], [InvoicingType])
  INCLUDE ([SourceGuid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SFin_InvoiceRequests_1989789739] on table [SFin].[InvoiceRequests]')
GO
CREATE INDEX [IX_SFin_InvoiceRequests_1989789739]
  ON [SFin].[InvoiceRequests] ([IsAutomated], [SourceType], [RowStatus], [InvoicingType])
  INCLUDE ([Guid], [SourceGuid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SFin_InvoiceRequests_2097759900] on table [SFin].[InvoiceRequests]')
GO
CREATE INDEX [IX_SFin_InvoiceRequests_2097759900]
  ON [SFin].[InvoiceRequests] ([SourceType])
  INCLUDE ([RowStatus], [JobId], [SourceGuid], [IsMerged])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SFin_InvoiceRequests_2145932611] on table [SFin].[InvoiceRequests]')
GO
CREATE INDEX [IX_SFin_InvoiceRequests_2145932611]
  ON [SFin].[InvoiceRequests] ([JobId])
  INCLUDE ([RowStatus], [RowVersion], [Guid], [Notes], [RequesterUserId], [CreatedDateTimeUTC], [LegacyId], [LegacySystemID], [InvoicingType], [ExpectedDate], [ManualStatus], [InvoicePaymentStatusID], [IsAutomated], [IsZeroValuePlaceholder], [ReconciliationRequired], [ReconciliationReason], [SourceType], [SourceGuid], [SourceIntId], [AutomationRunGuid], [InvoiceBatchGuid], [BlockedReason], [FinanceAccountGuid], [IsMerged])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SFin_InvoiceRequests_287976985] on table [SFin].[InvoiceRequests]')
GO
CREATE INDEX [IX_SFin_InvoiceRequests_287976985]
  ON [SFin].[InvoiceRequests] ([JobId], [ReconciliationRequired], [SourceType], [SourceGuid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_SFin_InvoiceRequests_801677873] on table [SFin].[InvoiceRequests]')
GO
CREATE INDEX [IX_SFin_InvoiceRequests_801677873]
  ON [SFin].[InvoiceRequests] ([ReconciliationRequired], [SourceType])
  INCLUDE ([JobId], [SourceGuid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_InvoiceRequest_Guid] on table [SFin].[InvoiceRequests]')
GO
CREATE UNIQUE INDEX [IX_UQ_InvoiceRequest_Guid]
  ON [SFin].[InvoiceRequests] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [UX_InvoiceRequests_MonthConfig_Active] on table [SFin].[InvoiceRequests]')
GO
CREATE UNIQUE INDEX [UX_InvoiceRequests_MonthConfig_Active]
  ON [SFin].[InvoiceRequests] ([JobId], [SourceGuid])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254) AND [SourceType]=N'MonthConfig' AND [SourceGuid] IS NOT NULL)
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_InvoiceRequests_RecordHistory] on table [SFin].[InvoiceRequests]')
GO
CREATE TRIGGER [SFin].[tg_InvoiceRequests_RecordHistory]
   ON  [SFin].[InvoiceRequests]	
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
			@TableName NVARCHAR(250) = N'InvoiceRequests',
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
		
		
		
		IF (NOT EXISTS (SELECT 1 FROM deleted d WHERE d.[ID] = @CurrentInsertedID))
		BEGIN
			INSERT SCore.RecordHistory
			(
				RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID,
				PreviousValue, NewValue, SQLUser, EntityPropertyID
			)
			VALUES
			(
				1, @SchemaName, @TableName, N'', @CurrentInsertedID, @CurrentInsertedGuid,
				@UserID, N'', N'', SYSTEM_USER, -1
			);

			CONTINUE;
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
				VALUES(1, @SchemaName, @TableName, N'CreatedDateTimeUTC', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1663)
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
				VALUES(1, @SchemaName, @TableName, N'ExpectedDate', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2338)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[InvoicePaymentStatusID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[InvoicePaymentStatusID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[InvoicePaymentStatusID] IS DISTINCT FROM i.[InvoicePaymentStatusID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'InvoicePaymentStatusID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2350)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[InvoicingType]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[InvoicingType]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[InvoicingType] IS DISTINCT FROM i.[InvoicingType])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'InvoicingType', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2337)
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
				VALUES(1, @SchemaName, @TableName, N'JobId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1664)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ManualStatus]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ManualStatus]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ManualStatus] IS DISTINCT FROM i.[ManualStatus])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ManualStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2339)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Notes]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Notes]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Notes] IS DISTINCT FROM i.[Notes])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Notes', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1661)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RequesterUserId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RequesterUserId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RequesterUserId] IS DISTINCT FROM i.[RequesterUserId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RequesterUserId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1662)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1658)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_InvoiceRequests_DataObjects] on table [SFin].[InvoiceRequests]')
GO
ALTER TABLE [SFin].[InvoiceRequests] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceRequests_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_InvoiceRequests_DataObjects] on table [SFin].[InvoiceRequests]')
GO
ALTER TABLE [SFin].[InvoiceRequests]
  NOCHECK CONSTRAINT [FK_InvoiceRequests_DataObjects]
GO

PRINT (N'Create foreign key [FK_InvoiceRequests_Identities1] on table [SFin].[InvoiceRequests]')
GO
ALTER TABLE [SFin].[InvoiceRequests] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceRequests_Identities1] FOREIGN KEY ([RequesterUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_InvoiceRequests_InvoiceAutomationRuns] on table [SFin].[InvoiceRequests]')
GO
ALTER TABLE [SFin].[InvoiceRequests] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceRequests_InvoiceAutomationRuns] FOREIGN KEY ([AutomationRunGuid]) REFERENCES [SFin].[InvoiceAutomationRuns] ([Guid])
GO

PRINT (N'Create foreign key [FK_InvoiceRequests_InvoiceBatches] on table [SFin].[InvoiceRequests]')
GO
ALTER TABLE [SFin].[InvoiceRequests] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceRequests_InvoiceBatches] FOREIGN KEY ([InvoiceBatchGuid]) REFERENCES [SFin].[InvoiceBatches] ([Guid])
GO

PRINT (N'Create foreign key [FK_InvoiceRequests_InvoicePaymentStatus] on table [SFin].[InvoiceRequests]')
GO
ALTER TABLE [SFin].[InvoiceRequests] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceRequests_InvoicePaymentStatus] FOREIGN KEY ([InvoicePaymentStatusID]) REFERENCES [SFin].[InvoicePaymentStatus] ([ID])
GO

PRINT (N'Disable foreign key [FK_InvoiceRequests_InvoicePaymentStatus] on table [SFin].[InvoiceRequests]')
GO
ALTER TABLE [SFin].[InvoiceRequests]
  NOCHECK CONSTRAINT [FK_InvoiceRequests_InvoicePaymentStatus]
GO

PRINT (N'Create foreign key [FK_InvoiceRequests_Jobs] on table [SFin].[InvoiceRequests]')
GO
ALTER TABLE [SFin].[InvoiceRequests] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceRequests_Jobs] FOREIGN KEY ([JobId]) REFERENCES [SJob].[Jobs] ([ID])
GO

PRINT (N'Create foreign key [FK_InvoiceRequests_RibaStages] on table [SFin].[InvoiceRequests]')
GO
ALTER TABLE [SFin].[InvoiceRequests] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceRequests_RibaStages] FOREIGN KEY ([RIBAStageId]) REFERENCES [SJob].[RibaStages] ([ID])
GO

PRINT (N'Create foreign key [FK_InvoiceRequests_RowStatus] on table [SFin].[InvoiceRequests]')
GO
ALTER TABLE [SFin].[InvoiceRequests] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceRequests_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
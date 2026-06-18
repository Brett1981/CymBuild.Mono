PRINT (N'Create table [SSop].[QuoteItems]')
GO
CREATE TABLE [SSop].[QuoteItems] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_QuoteItems_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_QuoteItems_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [QuoteId] [int] NOT NULL CONSTRAINT [DF_QuoteItems_QuoteId] DEFAULT (-1),
  [QuoteSectionId] [int] NOT NULL CONSTRAINT [DF_QuoteItems_QuoteSectionId] DEFAULT (-1),
  [ProductId] [int] NOT NULL CONSTRAINT [DF_QuoteItems_ProductId] DEFAULT (-1),
  [Details] [nvarchar](2000) NOT NULL CONSTRAINT [DF_QuoteItems_Details] DEFAULT (''),
  [Net] [decimal](19, 2) NOT NULL CONSTRAINT [DF_QuoteItems_Net] DEFAULT (0),
  [VatRate] [decimal](9, 2) NOT NULL CONSTRAINT [DF_QuoteItems_Vat] DEFAULT (0),
  [DoNotConsolidateJob] [bit] NOT NULL CONSTRAINT [DF_QuoteItems_DoNotConsolidateJob] DEFAULT (0),
  [SortOrder] [int] NOT NULL CONSTRAINT [DF_QuoteItems_SortOrder] DEFAULT (0),
  [Quantity] [decimal](9, 2) NOT NULL CONSTRAINT [DF_QuoteItems_Quantity] DEFAULT (0),
  [CreatedJobId] [int] NOT NULL CONSTRAINT [DF_QuoteItems_CreatedJobId] DEFAULT (-1),
  [LegacyId] [int] NULL,
  [LegacySystemID] [int] NOT NULL CONSTRAINT [DF__QuoteItem__Legac__116CF100] DEFAULT (-1),
  [ProvideAtStageID] [int] NOT NULL CONSTRAINT [DF_QuoteItems_ProvideAtStageID] DEFAULT (-1),
  [NumberOfSiteVisits] [int] NOT NULL CONSTRAINT [DF__QuoteItem__Numbe__3AEEF4D7] DEFAULT (0),
  [NumberOfMeetings] [int] NOT NULL CONSTRAINT [DF__QuoteItem__Numbe__3BE31910] DEFAULT (0),
  [InvoicingSchedule] [int] NOT NULL CONSTRAINT [DF_QuoteItems_InvoicingSchedule] DEFAULT (-1)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_QuoteItems] on table [SSop].[QuoteItems]')
GO
ALTER TABLE [SSop].[QuoteItems] WITH NOCHECK
  ADD CONSTRAINT [PK_QuoteItems] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_QuoteItems_CurrentQuotes] on table [SSop].[QuoteItems]')
GO
CREATE INDEX [IX_QuoteItems_CurrentQuotes]
  ON [SSop].[QuoteItems] ([QuoteId], [CreatedJobId], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254) AND [CreatedJobId]<(0))
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_QuoteItems_Guid] on table [SSop].[QuoteItems]')
GO
CREATE INDEX [IX_QuoteItems_Guid]
  ON [SSop].[QuoteItems] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_QuoteItems_InvoicingSchedule] on table [SSop].[QuoteItems]')
GO
CREATE INDEX [IX_QuoteItems_InvoicingSchedule]
  ON [SSop].[QuoteItems] ([InvoicingSchedule])
  INCLUDE ([RowStatus], [CreatedJobId])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_QuoteItems_QuoteId] on table [SSop].[QuoteItems]')
GO
CREATE INDEX [IX_QuoteItems_QuoteId]
  ON [SSop].[QuoteItems] ([QuoteId], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_QuoteItems_QuoteId_CreatedJobId] on table [SSop].[QuoteItems]')
GO
CREATE INDEX [IX_QuoteItems_QuoteId_CreatedJobId]
  ON [SSop].[QuoteItems] ([QuoteId], [CreatedJobId])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_QuoteItems_RecordHistory] on table [SSop].[QuoteItems]')
GO
CREATE TRIGGER [SSop].[tg_QuoteItems_RecordHistory]
   ON  [SSop].[QuoteItems]	
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
			@SchemaName NVARCHAR(250) = N'SSop',
			@TableName NVARCHAR(250) = N'QuoteItems',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[CreatedJobId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[CreatedJobId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[CreatedJobId] IS DISTINCT FROM i.[CreatedJobId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'CreatedJobId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 716)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Details]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Details]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Details] IS DISTINCT FROM i.[Details])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Details', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 668)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[DoNotConsolidateJob]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[DoNotConsolidateJob]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[DoNotConsolidateJob] IS DISTINCT FROM i.[DoNotConsolidateJob])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'DoNotConsolidateJob', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 669)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[InvoicingSchedule]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[InvoicingSchedule]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[InvoicingSchedule] IS DISTINCT FROM i.[InvoicingSchedule])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'InvoicingSchedule', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2381)
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
				VALUES(1, @SchemaName, @TableName, N'LegacyId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1853)
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
				VALUES(1, @SchemaName, @TableName, N'LegacySystemID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1854)
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
				VALUES(1, @SchemaName, @TableName, N'Net', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 672)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[NumberOfMeetings]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[NumberOfMeetings]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[NumberOfMeetings] IS DISTINCT FROM i.[NumberOfMeetings])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'NumberOfMeetings', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2060)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[NumberOfSiteVisits]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[NumberOfSiteVisits]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[NumberOfSiteVisits] IS DISTINCT FROM i.[NumberOfSiteVisits])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'NumberOfSiteVisits', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2059)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ProductId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ProductId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ProductId] IS DISTINCT FROM i.[ProductId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ProductId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 673)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ProvideAtStageID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ProvideAtStageID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ProvideAtStageID] IS DISTINCT FROM i.[ProvideAtStageID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ProvideAtStageID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1855)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Quantity]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Quantity]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Quantity] IS DISTINCT FROM i.[Quantity])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Quantity', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 715)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[QuoteId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[QuoteId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[QuoteId] IS DISTINCT FROM i.[QuoteId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'QuoteId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1856)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[QuoteSectionId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[QuoteSectionId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[QuoteSectionId] IS DISTINCT FROM i.[QuoteSectionId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'QuoteSectionId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 674)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 675)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[SortOrder]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[SortOrder]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[SortOrder] IS DISTINCT FROM i.[SortOrder])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'SortOrder', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 677)
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
				VALUES(1, @SchemaName, @TableName, N'VatRate', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 678)
			END 
			
			
			END
		END
		
		
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tr_QuoteItems_EnqueueJobCreatedFromProposal] on table [SSop].[QuoteItems]')
GO
/* ---------------------------------------------------------------------------------------
   Trigger: SSop.QuoteItems AFTER UPDATE
   Fires when CreatedJobId changes from (<0 or NULL) to (>0)
   DEDUPES so you get 1 enqueue per JobId, even if multiple quoteitems consolidated.
--------------------------------------------------------------------------------------- */
CREATE TRIGGER [SSop].[tr_QuoteItems_EnqueueJobCreatedFromProposal]
ON [SSop].[QuoteItems]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT (UPDATE(CreatedJobId))
        RETURN;

    BEGIN TRY
        ;WITH Changed AS
        (
            SELECT
                  i.QuoteId
                , i.CreatedJobId
            FROM inserted i
            JOIN deleted d
              ON d.ID = i.ID
            WHERE ISNULL(d.CreatedJobId, -1) < 0
              AND ISNULL(i.CreatedJobId, -1) > 0
              AND i.RowStatus NOT IN (0,254)
        ),
        Dedup AS
        (
            SELECT DISTINCT
                  c.QuoteId
                , c.CreatedJobId
            FROM Changed c
            WHERE c.CreatedJobId > 0
              AND c.QuoteId > 0
        )
        SELECT *
        INTO #ToEnqueue
        FROM Dedup;

        DECLARE @JobId INT, @QuoteId INT;

        WHILE EXISTS (SELECT 1 FROM #ToEnqueue)
        BEGIN
            SELECT TOP (1)
                  @JobId = CreatedJobId
                , @QuoteId = QuoteId
            FROM #ToEnqueue
            ORDER BY CreatedJobId, QuoteId;

            EXEC SCore.IntegrationOutbox_EnqueueJobCreatedFromProposal
                 @JobId   = @JobId,
                 @QuoteId = @QuoteId;

            DELETE TOP (1)
            FROM #ToEnqueue;
        END
    END TRY
    BEGIN CATCH
        -- best-effort: never block quote/job pipeline
        RETURN;
    END CATCH
END;
GO

PRINT (N'Create foreign key [FK_QuoteItems_DataObjects] on table [SSop].[QuoteItems]')
GO
ALTER TABLE [SSop].[QuoteItems] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteItems_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_QuoteItems_DataObjects] on table [SSop].[QuoteItems]')
GO
ALTER TABLE [SSop].[QuoteItems]
  NOCHECK CONSTRAINT [FK_QuoteItems_DataObjects]
GO

PRINT (N'Create foreign key [FK_QuoteItems_InvoicingSchedule] on table [SSop].[QuoteItems]')
GO
ALTER TABLE [SSop].[QuoteItems] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteItems_InvoicingSchedule] FOREIGN KEY ([InvoicingSchedule]) REFERENCES [SFin].[InvoiceSchedules] ([ID])
GO

PRINT (N'Create foreign key [FK_QuoteItems_Jobs] on table [SSop].[QuoteItems]')
GO
ALTER TABLE [SSop].[QuoteItems] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteItems_Jobs] FOREIGN KEY ([CreatedJobId]) REFERENCES [SJob].[Jobs] ([ID])
GO

PRINT (N'Create foreign key [FK_QuoteItems_Products] on table [SSop].[QuoteItems]')
GO
ALTER TABLE [SSop].[QuoteItems] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteItems_Products] FOREIGN KEY ([ProductId]) REFERENCES [SProd].[Products] ([ID])
GO

PRINT (N'Create foreign key [FK_QuoteItems_QuoteSections] on table [SSop].[QuoteItems]')
GO
ALTER TABLE [SSop].[QuoteItems] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteItems_QuoteSections] FOREIGN KEY ([QuoteSectionId]) REFERENCES [SSop].[QuoteSections] ([ID]) ON DELETE CASCADE
GO

PRINT (N'Create foreign key [FK_QuoteItems_RibaStages] on table [SSop].[QuoteItems]')
GO
ALTER TABLE [SSop].[QuoteItems] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteItems_RibaStages] FOREIGN KEY ([ProvideAtStageID]) REFERENCES [SJob].[RibaStages] ([ID])
GO

PRINT (N'Create foreign key [FK_QuoteItems_RowStatus] on table [SSop].[QuoteItems]')
GO
ALTER TABLE [SSop].[QuoteItems] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteItems_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
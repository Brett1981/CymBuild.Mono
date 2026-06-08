PRINT (N'Create table [SSop].[QuotePaymentStages]')
GO
CREATE TABLE [SSop].[QuotePaymentStages] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_QuotePaymentStages_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_QuotePaymentStages_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [QuoteId] [int] NOT NULL CONSTRAINT [DF_QuotePaymentStages_QuoteId] DEFAULT (-1),
  [PaymentFrequencyTypeId] [int] NOT NULL CONSTRAINT [DF_QuotePaymentStages_PaymentFrequencyTypeId] DEFAULT (-1),
  [PaymentFrequency] [int] NOT NULL CONSTRAINT [DF_QuotePaymentStages_PaymentFrequency] DEFAULT (0),
  [Value] [decimal](18, 2) NOT NULL CONSTRAINT [DF_QuotePaymentStages_Value] DEFAULT (0),
  [PercentageOfTotal] [decimal](5, 2) NOT NULL CONSTRAINT [DF_QuotePaymentStages_PercentageOfTotal] DEFAULT (0),
  [PayAfterStageId] [int] NOT NULL CONSTRAINT [DF_QuotePaymentStages_PayAfterStageId] DEFAULT (-1)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_QuotePaymentStages] on table [SSop].[QuotePaymentStages]')
GO
ALTER TABLE [SSop].[QuotePaymentStages] WITH NOCHECK
  ADD CONSTRAINT [PK_QuotePaymentStages] PRIMARY KEY CLUSTERED ([ID])
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_QuotePaymentStages_Quote] on table [SSop].[QuotePaymentStages]')
GO
CREATE INDEX [IX_QuotePaymentStages_Quote]
  ON [SSop].[QuotePaymentStages] ([RowStatus], [QuoteId])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_QuotePaymentStages_Guid] on table [SSop].[QuotePaymentStages]')
GO
CREATE UNIQUE INDEX [IX_UQ_QuotePaymentStages_Guid]
  ON [SSop].[QuotePaymentStages] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_QuotePaymentStages_RecordHistory] on table [SSop].[QuotePaymentStages]')
GO
CREATE TRIGGER [SSop].[tg_QuotePaymentStages_RecordHistory]
   ON  [SSop].[QuotePaymentStages]	
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
			@TableName NVARCHAR(250) = N'QuotePaymentStages',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[PayAfterStageId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[PayAfterStageId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[PayAfterStageId] IS DISTINCT FROM i.[PayAfterStageId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'PayAfterStageId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1638)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[PaymentFrequency]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[PaymentFrequency]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[PaymentFrequency] IS DISTINCT FROM i.[PaymentFrequency])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'PaymentFrequency', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1635)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[PaymentFrequencyTypeId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[PaymentFrequencyTypeId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[PaymentFrequencyTypeId] IS DISTINCT FROM i.[PaymentFrequencyTypeId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'PaymentFrequencyTypeId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1634)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[PercentageOfTotal]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[PercentageOfTotal]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[PercentageOfTotal] IS DISTINCT FROM i.[PercentageOfTotal])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'PercentageOfTotal', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1637)
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
				VALUES(1, @SchemaName, @TableName, N'QuoteId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1633)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1630)
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
				VALUES(1, @SchemaName, @TableName, N'Value', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1636)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_QuotePaymentStages_DataObjects] on table [SSop].[QuotePaymentStages]')
GO
ALTER TABLE [SSop].[QuotePaymentStages] WITH NOCHECK
  ADD CONSTRAINT [FK_QuotePaymentStages_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_QuotePaymentStages_DataObjects] on table [SSop].[QuotePaymentStages]')
GO
ALTER TABLE [SSop].[QuotePaymentStages]
  NOCHECK CONSTRAINT [FK_QuotePaymentStages_DataObjects]
GO

PRINT (N'Create foreign key [FK_QuotePaymentStages_PaymentFrequencyTypes] on table [SSop].[QuotePaymentStages]')
GO
ALTER TABLE [SSop].[QuotePaymentStages] WITH NOCHECK
  ADD CONSTRAINT [FK_QuotePaymentStages_PaymentFrequencyTypes] FOREIGN KEY ([PaymentFrequencyTypeId]) REFERENCES [SFin].[PaymentFrequencyTypes] ([ID])
GO

PRINT (N'Create foreign key [FK_QuotePaymentStages_Quotes] on table [SSop].[QuotePaymentStages]')
GO
ALTER TABLE [SSop].[QuotePaymentStages] WITH NOCHECK
  ADD CONSTRAINT [FK_QuotePaymentStages_Quotes] FOREIGN KEY ([QuoteId]) REFERENCES [SSop].[Quotes] ([ID]) ON DELETE CASCADE
GO

PRINT (N'Create foreign key [FK_QuotePaymentStages_RibaStages] on table [SSop].[QuotePaymentStages]')
GO
ALTER TABLE [SSop].[QuotePaymentStages] WITH NOCHECK
  ADD CONSTRAINT [FK_QuotePaymentStages_RibaStages] FOREIGN KEY ([PayAfterStageId]) REFERENCES [SJob].[RibaStages] ([ID])
GO

PRINT (N'Create foreign key [FK_QuotePaymentStages_RowStatus] on table [SSop].[QuotePaymentStages]')
GO
ALTER TABLE [SSop].[QuotePaymentStages] WITH NOCHECK
  ADD CONSTRAINT [FK_QuotePaymentStages_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
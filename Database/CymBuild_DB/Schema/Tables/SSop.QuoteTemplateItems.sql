PRINT (N'Create table [SSop].[QuoteTemplateItems]')
GO
CREATE TABLE [SSop].[QuoteTemplateItems] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_QuoteTemplateItems_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_QuoteTemplateItems_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [QuoteTemplateSectionId] [int] NOT NULL CONSTRAINT [DF_QuoteTemplateItems_QuoteSectionId] DEFAULT (-1),
  [ProductId] [int] NOT NULL CONSTRAINT [DF_QuoteTemplateItems_ProductId] DEFAULT (-1),
  [Details] [nvarchar](2000) NOT NULL CONSTRAINT [DF_QuoteTemplateItems_Details] DEFAULT (''),
  [Net] [decimal](9, 2) NOT NULL CONSTRAINT [DF_QuoteTemplateItems_Net] DEFAULT (0),
  [VatRate] [decimal](9, 2) NOT NULL CONSTRAINT [DF_QuoteTemplateItems_Vat] DEFAULT (0),
  [DoNotConsolidateJob] [bit] NOT NULL CONSTRAINT [DF_QuoteTemplateItems_DoNotConsolidateJob] DEFAULT (0),
  [SortOrder] [int] NOT NULL CONSTRAINT [DF_QuoteTemplateItems_SortOrder] DEFAULT (0),
  [Quantity] [decimal](9, 2) NOT NULL CONSTRAINT [DF_QuoteTemplateItems_Quantity] DEFAULT (0)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_QuoteTemplateItems] on table [SSop].[QuoteTemplateItems]')
GO
ALTER TABLE [SSop].[QuoteTemplateItems] WITH NOCHECK
  ADD CONSTRAINT [PK_QuoteTemplateItems] PRIMARY KEY CLUSTERED ([ID])
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_QuoteTemplateItems_RecordHistory] on table [SSop].[QuoteTemplateItems]')
GO
CREATE TRIGGER [SSop].[tg_QuoteTemplateItems_RecordHistory]
   ON  [SSop].[QuoteTemplateItems]	
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
			@TableName NVARCHAR(250) = N'QuoteTemplateItems',
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
				VALUES(1, @SchemaName, @TableName, N'Details', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 909)
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
				VALUES(1, @SchemaName, @TableName, N'DoNotConsolidateJob', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 910)
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
				VALUES(1, @SchemaName, @TableName, N'Net', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 913)
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
				VALUES(1, @SchemaName, @TableName, N'ProductId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 914)
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
				VALUES(1, @SchemaName, @TableName, N'Quantity', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 915)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[QuoteTemplateSectionId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[QuoteTemplateSectionId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[QuoteTemplateSectionId] IS DISTINCT FROM i.[QuoteTemplateSectionId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'QuoteTemplateSectionId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 916)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 917)
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
				VALUES(1, @SchemaName, @TableName, N'SortOrder', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 919)
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
				VALUES(1, @SchemaName, @TableName, N'VatRate', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 920)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_QuoteTemplateItems_DataObjects] on table [SSop].[QuoteTemplateItems]')
GO
ALTER TABLE [SSop].[QuoteTemplateItems] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteTemplateItems_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_QuoteTemplateItems_DataObjects] on table [SSop].[QuoteTemplateItems]')
GO
ALTER TABLE [SSop].[QuoteTemplateItems]
  NOCHECK CONSTRAINT [FK_QuoteTemplateItems_DataObjects]
GO

PRINT (N'Create foreign key [FK_QuoteTemplateItems_Products] on table [SSop].[QuoteTemplateItems]')
GO
ALTER TABLE [SSop].[QuoteTemplateItems] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteTemplateItems_Products] FOREIGN KEY ([ProductId]) REFERENCES [SProd].[Products] ([ID])
GO

PRINT (N'Create foreign key [FK_QuoteTemplateItems_QuoteTemplateSections] on table [SSop].[QuoteTemplateItems]')
GO
ALTER TABLE [SSop].[QuoteTemplateItems] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteTemplateItems_QuoteTemplateSections] FOREIGN KEY ([QuoteTemplateSectionId]) REFERENCES [SSop].[QuoteTemplateSections] ([ID])
GO

PRINT (N'Create foreign key [FK_QuoteTemplateItems_RowStatus] on table [SSop].[QuoteTemplateItems]')
GO
ALTER TABLE [SSop].[QuoteTemplateItems] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteTemplateItems_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
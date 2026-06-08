PRINT (N'Create table [SSop].[PriceListProducts]')
GO
CREATE TABLE [SSop].[PriceListProducts] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_PriceListProducts_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_PriceListProducts_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [PriceListId] [int] NOT NULL CONSTRAINT [DF_PriceListProducts_PriceListId] DEFAULT (-1),
  [ProductId] [int] NOT NULL CONSTRAINT [DF_PriceListProducts_ProductId] DEFAULT (-1),
  [Price] [decimal](9, 2) NOT NULL CONSTRAINT [DF_PriceListProducts_Price] DEFAULT (0)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_PriceListProducts] on table [SSop].[PriceListProducts]')
GO
ALTER TABLE [SSop].[PriceListProducts] WITH NOCHECK
  ADD CONSTRAINT [PK_PriceListProducts] PRIMARY KEY CLUSTERED ([ID])
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_PriceListProducts_RecordHistory] on table [SSop].[PriceListProducts]')
GO
CREATE TRIGGER [SSop].[tg_PriceListProducts_RecordHistory]
   ON  [SSop].[PriceListProducts]	
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
			@TableName NVARCHAR(250) = N'PriceListProducts',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Price]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Price]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Price] IS DISTINCT FROM i.[Price])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Price', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 637)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[PriceListId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[PriceListId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[PriceListId] IS DISTINCT FROM i.[PriceListId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'PriceListId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 638)
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
				VALUES(1, @SchemaName, @TableName, N'ProductId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 639)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 640)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_PriceListProducts_DataObjects] on table [SSop].[PriceListProducts]')
GO
ALTER TABLE [SSop].[PriceListProducts] WITH NOCHECK
  ADD CONSTRAINT [FK_PriceListProducts_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_PriceListProducts_DataObjects] on table [SSop].[PriceListProducts]')
GO
ALTER TABLE [SSop].[PriceListProducts]
  NOCHECK CONSTRAINT [FK_PriceListProducts_DataObjects]
GO

PRINT (N'Create foreign key [FK_PriceListProducts_PriceLists] on table [SSop].[PriceListProducts]')
GO
ALTER TABLE [SSop].[PriceListProducts] WITH NOCHECK
  ADD CONSTRAINT [FK_PriceListProducts_PriceLists] FOREIGN KEY ([PriceListId]) REFERENCES [SSop].[PriceLists] ([ID])
GO

PRINT (N'Create foreign key [FK_PriceListProducts_Products] on table [SSop].[PriceListProducts]')
GO
ALTER TABLE [SSop].[PriceListProducts] WITH NOCHECK
  ADD CONSTRAINT [FK_PriceListProducts_Products] FOREIGN KEY ([ProductId]) REFERENCES [SProd].[Products] ([ID])
GO

PRINT (N'Create foreign key [FK_PriceListProducts_RowStatus] on table [SSop].[PriceListProducts]')
GO
ALTER TABLE [SSop].[PriceListProducts] WITH NOCHECK
  ADD CONSTRAINT [FK_PriceListProducts_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
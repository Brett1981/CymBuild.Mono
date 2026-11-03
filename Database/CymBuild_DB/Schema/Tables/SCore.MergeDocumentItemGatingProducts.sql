PRINT (N'Create table [SCore].[MergeDocumentItemGatingProducts]')
GO
CREATE TABLE [SCore].[MergeDocumentItemGatingProducts] (
  [ID] [int] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_MergeDocumentItemGatingProducts_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_MergeDocumentItemGatingProducts_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [MergeDocumentItemId] [int] NOT NULL CONSTRAINT [DF_MergeDocumentItemGatingProducts_MergeDocumentItemId] DEFAULT (-1),
  [ProductId] [int] NOT NULL CONSTRAINT [DF_MergeDocumentItemGatingProducts_ProductId] DEFAULT (-1)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_MergeDocumentItemGatingProducts] on table [SCore].[MergeDocumentItemGatingProducts]')
GO
ALTER TABLE [SCore].[MergeDocumentItemGatingProducts] WITH NOCHECK
  ADD CONSTRAINT [PK_MergeDocumentItemGatingProducts] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create index [IX_UQ_MergeDocumentItemGatingProducts_Guid] on table [SCore].[MergeDocumentItemGatingProducts]')
GO
CREATE UNIQUE INDEX [IX_UQ_MergeDocumentItemGatingProducts_Guid]
  ON [SCore].[MergeDocumentItemGatingProducts] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_MergeDocumentItemGatingProducts_Item_Product] on table [SCore].[MergeDocumentItemGatingProducts]')
GO
-- One gating row per (MergeDocumentItem, Product) pair. A row with no gating rows at all is
-- treated as unconditional (always included) by WordDocumentService - see
-- EF.Core.GetGatingProductIdsForMergeDocumentItem and
-- WordDocumentService.ShouldIncludeRowForQuote (CYB-323).
CREATE UNIQUE INDEX [IX_UQ_MergeDocumentItemGatingProducts_Item_Product]
  ON [SCore].[MergeDocumentItemGatingProducts] ([MergeDocumentItemId], [ProductId])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_MergeDocumentItemGatingProducts_RecordHistory] on table [SCore].[MergeDocumentItemGatingProducts]')
GO
CREATE TRIGGER [SCore].[tg_MergeDocumentItemGatingProducts_RecordHistory]
   ON  [SCore].[MergeDocumentItemGatingProducts]
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
			@SchemaName NVARCHAR(250) = N'SCore',
			@TableName NVARCHAR(250) = N'MergeDocumentItemGatingProducts',
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

			CONTINUE
		END

			SELECT
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[MergeDocumentItemId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[MergeDocumentItemId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[MergeDocumentItemId] IS DISTINCT FROM i.[MergeDocumentItemId])

			IF (@@RowCount > 0)
			BEGIN
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'MergeDocumentItemId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, -1)
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
				VALUES(1, @SchemaName, @TableName, N'ProductId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, -1)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, -1)
			END

	END
END
GO

PRINT (N'Create foreign key [FK_MergeDocumentItemGatingProducts_MergeDocumentItems] on table [SCore].[MergeDocumentItemGatingProducts]')
GO
ALTER TABLE [SCore].[MergeDocumentItemGatingProducts] WITH NOCHECK
  ADD CONSTRAINT [FK_MergeDocumentItemGatingProducts_MergeDocumentItems] FOREIGN KEY ([MergeDocumentItemId]) REFERENCES [SCore].[MergeDocumentItems] ([ID])
GO

PRINT (N'Create foreign key [FK_MergeDocumentItemGatingProducts_Products] on table [SCore].[MergeDocumentItemGatingProducts]')
GO
ALTER TABLE [SCore].[MergeDocumentItemGatingProducts] WITH NOCHECK
  ADD CONSTRAINT [FK_MergeDocumentItemGatingProducts_Products] FOREIGN KEY ([ProductId]) REFERENCES [SProd].[Products] ([ID])
GO

PRINT (N'Create foreign key [FK_MergeDocumentItemGatingProducts_RowStatus] on table [SCore].[MergeDocumentItemGatingProducts]')
GO
ALTER TABLE [SCore].[MergeDocumentItemGatingProducts] WITH NOCHECK
  ADD CONSTRAINT [FK_MergeDocumentItemGatingProducts_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

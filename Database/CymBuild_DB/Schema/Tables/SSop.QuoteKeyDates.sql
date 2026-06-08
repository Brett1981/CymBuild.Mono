PRINT (N'Create table [SSop].[QuoteKeyDates]')
GO
CREATE TABLE [SSop].[QuoteKeyDates] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DC_QuoteKeyDates_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DC_QuoteKeyDates_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [QuoteId] [int] NOT NULL CONSTRAINT [DC_QuoteKeyDates_QuoteId] DEFAULT (-1),
  [Detail] [varchar](500) NOT NULL DEFAULT (''),
  [DateTime] [datetime2] NULL
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_QuoteKeyDates_ID] on table [SSop].[QuoteKeyDates]')
GO
ALTER TABLE [SSop].[QuoteKeyDates] WITH NOCHECK
  ADD CONSTRAINT [PK_QuoteKeyDates_ID] PRIMARY KEY CLUSTERED ([ID])
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_QuoteKeyDates_QuoteId] on table [SSop].[QuoteKeyDates]')
GO
CREATE INDEX [IX_QuoteKeyDates_QuoteId]
  ON [SSop].[QuoteKeyDates] ([QuoteId], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_QuoteKeyDates_Guid] on table [SSop].[QuoteKeyDates]')
GO
CREATE UNIQUE INDEX [IX_UQ_QuoteKeyDates_Guid]
  ON [SSop].[QuoteKeyDates] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_QuoteKeyDates_RecordHistory] on table [SSop].[QuoteKeyDates]')
GO
CREATE TRIGGER [SSop].[tg_QuoteKeyDates_RecordHistory]
   ON  [SSop].[QuoteKeyDates]	
   AFTER UPDATE
AS 
BEGIN
	SET NOCOUNT ON;

    IF (ISNULL(CONVERT(int, SESSION_CONTEXT(N'S_disable_triggers')), 0) = 1)
    BEGIN 
        RETURN
    END

    DECLARE	@PreviousValue NVARCHAR(MAX),
			@NewValue NVARCHAR(MAX),
			@UserID INT = 0,
			@SchemaName NVARCHAR(250) = N'SSop',
			@TableName NVARCHAR(250) = N'QuoteKeyDates',
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1407)
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
				VALUES(1, @SchemaName, @TableName, N'QuoteId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1410)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Detail]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Detail]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Detail] IS DISTINCT FROM i.[Detail])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Detail', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1411)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[DateTime]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[DateTime]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[DateTime] IS DISTINCT FROM i.[DateTime])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'DateTime', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1412)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_QuoteKeyDates_Guid] on table [SSop].[QuoteKeyDates]')
GO
ALTER TABLE [SSop].[QuoteKeyDates] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteKeyDates_Guid] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_QuoteKeyDates_Guid] on table [SSop].[QuoteKeyDates]')
GO
ALTER TABLE [SSop].[QuoteKeyDates]
  NOCHECK CONSTRAINT [FK_QuoteKeyDates_Guid]
GO

PRINT (N'Create foreign key [FK_QuoteKeyDates_QuoteId] on table [SSop].[QuoteKeyDates]')
GO
ALTER TABLE [SSop].[QuoteKeyDates] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteKeyDates_QuoteId] FOREIGN KEY ([QuoteId]) REFERENCES [SSop].[Quotes] ([ID]) ON DELETE CASCADE
GO

PRINT (N'Create foreign key [FK_QuoteKeyDates_RowStatus] on table [SSop].[QuoteKeyDates]')
GO
ALTER TABLE [SSop].[QuoteKeyDates] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteKeyDates_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
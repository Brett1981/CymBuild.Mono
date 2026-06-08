PRINT (N'Create table [SFin].[TransactionTypes]')
GO
PRINT (N'Create table [SFin].[TransactionTypes]')
GO
CREATE TABLE [SFin].[TransactionTypes] (
  [ID] [smallint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_TransactionTypes_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_TransactionTypes_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](50) NOT NULL CONSTRAINT [DF_TransactionTypes_Name] DEFAULT (''),
  [IsActive] [bit] NOT NULL CONSTRAINT [DF_TransactionTypes_IsActive] DEFAULT (1),
  [SequenceID] [int] NOT NULL CONSTRAINT [DF_TransactionTypes_SequenceID] DEFAULT (-1),
  [IsNegated] [bit] NOT NULL CONSTRAINT [DF_TransactionTypes_IsNegated] DEFAULT (0),
  [IsBank] [bit] NOT NULL CONSTRAINT [DF_TransactionTypes_IsBank] DEFAULT (0)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_TransactionTypes] on table [SFin].[TransactionTypes]')
GO
ALTER TABLE [SFin].[TransactionTypes] WITH NOCHECK
  ADD CONSTRAINT [PK_TransactionTypes] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 90)
GO

PRINT (N'Create index [IX_TransactionTypes_IsBank] on table [SFin].[TransactionTypes]')
GO
CREATE INDEX [IX_TransactionTypes_IsBank]
  ON [SFin].[TransactionTypes] ([IsBank])
  INCLUDE ([IsNegated])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_TransactionTypes_Guid] on table [SFin].[TransactionTypes]')
GO
CREATE UNIQUE INDEX [IX_UQ_TransactionTypes_Guid]
  ON [SFin].[TransactionTypes] ([Guid])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_TransactionTypes_Name] on table [SFin].[TransactionTypes]')
GO
CREATE UNIQUE INDEX [IX_UQ_TransactionTypes_Name]
  ON [SFin].[TransactionTypes] ([Name])
  INCLUDE ([IsNegated])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_TransactionTypes_RecordHistory] on table [SFin].[TransactionTypes]')
GO
CREATE TRIGGER [SFin].[tg_TransactionTypes_RecordHistory]
   ON  [SFin].[TransactionTypes]	
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
			@TableName NVARCHAR(250) = N'TransactionTypes',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[IsActive]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[IsActive]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[IsActive] IS DISTINCT FROM i.[IsActive])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsActive', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 729)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Name]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Name]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Name] IS DISTINCT FROM i.[Name])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Name', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 730)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 731)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[SequenceID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[SequenceID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[SequenceID] IS DISTINCT FROM i.[SequenceID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'SequenceID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 733)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_TransactionTypes_DataObjects] on table [SFin].[TransactionTypes]')
GO
ALTER TABLE [SFin].[TransactionTypes] WITH NOCHECK
  ADD CONSTRAINT [FK_TransactionTypes_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_TransactionTypes_DataObjects] on table [SFin].[TransactionTypes]')
GO
ALTER TABLE [SFin].[TransactionTypes]
  NOCHECK CONSTRAINT [FK_TransactionTypes_DataObjects]
GO

PRINT (N'Create foreign key [FK_TransactionTypes_RowStatus] on table [SFin].[TransactionTypes]')
GO
ALTER TABLE [SFin].[TransactionTypes] WITH NOCHECK
  ADD CONSTRAINT [FK_TransactionTypes_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_TransactionTypes_SequenceTable] on table [SFin].[TransactionTypes]')
GO
ALTER TABLE [SFin].[TransactionTypes] WITH NOCHECK
  ADD CONSTRAINT [FK_TransactionTypes_SequenceTable] FOREIGN KEY ([SequenceID]) REFERENCES [SCore].[SequenceTable] ([ID])
GO
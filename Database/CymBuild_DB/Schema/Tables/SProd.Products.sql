PRINT (N'Create table [SProd].[Products]')
GO
PRINT (N'Create table [SProd].[Products]')
GO
CREATE TABLE [SProd].[Products] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Products_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_Products_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Code] [nvarchar](30) NOT NULL CONSTRAINT [DF_Products_Code] DEFAULT (''),
  [Description] [nvarchar](2000) NOT NULL CONSTRAINT [DF_Products_Description] DEFAULT (''),
  [CreatedJobType] [int] NOT NULL CONSTRAINT [DF_Products_CreatedJobType] DEFAULT (-1),
  [NeverConsolidate] [bit] NOT NULL CONSTRAINT [DF_Products_NeverConsolidate] DEFAULT (0),
  [RibaStageId] [int] NOT NULL CONSTRAINT [DF_Products_RibaStageId] DEFAULT (-1)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_Products] on table [SProd].[Products]')
GO
ALTER TABLE [SProd].[Products] WITH NOCHECK
  ADD CONSTRAINT [PK_Products] PRIMARY KEY CLUSTERED ([ID])
GO

PRINT (N'Create index [IX_UQ_Products_Code] on table [SProd].[Products]')
GO
CREATE UNIQUE INDEX [IX_UQ_Products_Code]
  ON [SProd].[Products] ([Code])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_Products_Guid] on table [SProd].[Products]')
GO
CREATE UNIQUE INDEX [IX_UQ_Products_Guid]
  ON [SProd].[Products] ([Guid])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_Products_RecordHistory] on table [SProd].[Products]')
GO
CREATE TRIGGER [SProd].[tg_Products_RecordHistory]
   ON  [SProd].[Products]	
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
			@SchemaName NVARCHAR(250) = N'SProd',
			@TableName NVARCHAR(250) = N'Products',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Code]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Code]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Code] IS DISTINCT FROM i.[Code])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Code', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 621)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[CreatedJobType]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[CreatedJobType]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[CreatedJobType] IS DISTINCT FROM i.[CreatedJobType])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'CreatedJobType', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 622)
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
				VALUES(1, @SchemaName, @TableName, N'Description', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 623)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[NeverConsolidate]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[NeverConsolidate]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[NeverConsolidate] IS DISTINCT FROM i.[NeverConsolidate])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'NeverConsolidate', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 626)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RibaStageId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RibaStageId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RibaStageId] IS DISTINCT FROM i.[RibaStageId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RibaStageId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 925)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 627)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_Products_DataObjects] on table [SProd].[Products]')
GO
ALTER TABLE [SProd].[Products] WITH NOCHECK
  ADD CONSTRAINT [FK_Products_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_Products_DataObjects] on table [SProd].[Products]')
GO
ALTER TABLE [SProd].[Products]
  NOCHECK CONSTRAINT [FK_Products_DataObjects]
GO

PRINT (N'Create foreign key [FK_Products_RibaStages] on table [SProd].[Products]')
GO
ALTER TABLE [SProd].[Products] WITH NOCHECK
  ADD CONSTRAINT [FK_Products_RibaStages] FOREIGN KEY ([RibaStageId]) REFERENCES [SJob].[RibaStages] ([ID])
GO

PRINT (N'Create foreign key [FK_Products_RowStatus] on table [SProd].[Products]')
GO
ALTER TABLE [SProd].[Products] WITH NOCHECK
  ADD CONSTRAINT [FK_Products_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
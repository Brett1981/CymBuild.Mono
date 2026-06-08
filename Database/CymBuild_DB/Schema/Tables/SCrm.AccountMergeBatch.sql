PRINT (N'Create table [SCrm].[AccountMergeBatch]')
GO
CREATE TABLE [SCrm].[AccountMergeBatch] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_AccountMergeBatch_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_AccountMergeBatch_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [SourceAccountId] [int] NOT NULL CONSTRAINT [DF_AccountMergeBatch_SourceAccountId] DEFAULT (-1),
  [TargetAccountId] [int] NOT NULL CONSTRAINT [DF_AccountMergeBatch_TargetAccountId] DEFAULT (-1),
  [CreatedByUserId] [int] NOT NULL CONSTRAINT [DF_AccountMergeBatch_CreatedByUserId] DEFAULT (-1),
  [CheckedByUserId] [int] NOT NULL CONSTRAINT [DF_AccountMergeBatch_CheckedByUserId] DEFAULT (-1),
  [IsComplete] [bit] NOT NULL CONSTRAINT [DF_AccountMergeBatch_IsComplete] DEFAULT (0)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_AccountMergeBatch] on table [SCrm].[AccountMergeBatch]')
GO
ALTER TABLE [SCrm].[AccountMergeBatch] WITH NOCHECK
  ADD CONSTRAINT [PK_AccountMergeBatch] PRIMARY KEY CLUSTERED ([ID])
GO

PRINT (N'Create index [IX_UQ_AccountMergeBatch_Guid] on table [SCrm].[AccountMergeBatch]')
GO
CREATE UNIQUE INDEX [IX_UQ_AccountMergeBatch_Guid]
  ON [SCrm].[AccountMergeBatch] ([Guid])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_AccountMergeBatch_RecordHistory] on table [SCrm].[AccountMergeBatch]')
GO
CREATE TRIGGER [SCrm].[tg_AccountMergeBatch_RecordHistory]
   ON  [SCrm].[AccountMergeBatch]	
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
			@SchemaName NVARCHAR(250) = N'SCrm',
			@TableName NVARCHAR(250) = N'AccountMergeBatch',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[CheckedByUserId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[CheckedByUserId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[CheckedByUserId] IS DISTINCT FROM i.[CheckedByUserId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'CheckedByUserId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1185)
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
				VALUES(1, @SchemaName, @TableName, N'CreatedByUserId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1186)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1190)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[SourceAccountId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[SourceAccountId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[SourceAccountId] IS DISTINCT FROM i.[SourceAccountId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'SourceAccountId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1192)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[TargetAccountId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[TargetAccountId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[TargetAccountId] IS DISTINCT FROM i.[TargetAccountId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'TargetAccountId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1193)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_AccountMergeBatch_Accounts] on table [SCrm].[AccountMergeBatch]')
GO
ALTER TABLE [SCrm].[AccountMergeBatch] WITH NOCHECK
  ADD CONSTRAINT [FK_AccountMergeBatch_Accounts] FOREIGN KEY ([SourceAccountId]) REFERENCES [SCrm].[Accounts] ([ID])
GO

PRINT (N'Create foreign key [FK_AccountMergeBatch_Accounts1] on table [SCrm].[AccountMergeBatch]')
GO
ALTER TABLE [SCrm].[AccountMergeBatch] WITH NOCHECK
  ADD CONSTRAINT [FK_AccountMergeBatch_Accounts1] FOREIGN KEY ([TargetAccountId]) REFERENCES [SCrm].[Accounts] ([ID])
GO

PRINT (N'Create foreign key [FK_AccountMergeBatch_DataObjects] on table [SCrm].[AccountMergeBatch]')
GO
ALTER TABLE [SCrm].[AccountMergeBatch] WITH NOCHECK
  ADD CONSTRAINT [FK_AccountMergeBatch_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_AccountMergeBatch_DataObjects] on table [SCrm].[AccountMergeBatch]')
GO
ALTER TABLE [SCrm].[AccountMergeBatch]
  NOCHECK CONSTRAINT [FK_AccountMergeBatch_DataObjects]
GO

PRINT (N'Create foreign key [FK_AccountMergeBatch_Identities] on table [SCrm].[AccountMergeBatch]')
GO
ALTER TABLE [SCrm].[AccountMergeBatch] WITH NOCHECK
  ADD CONSTRAINT [FK_AccountMergeBatch_Identities] FOREIGN KEY ([CreatedByUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_AccountMergeBatch_Identities1] on table [SCrm].[AccountMergeBatch]')
GO
ALTER TABLE [SCrm].[AccountMergeBatch] WITH NOCHECK
  ADD CONSTRAINT [FK_AccountMergeBatch_Identities1] FOREIGN KEY ([CheckedByUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_AccountMergeBatch_RowStatus] on table [SCrm].[AccountMergeBatch]')
GO
ALTER TABLE [SCrm].[AccountMergeBatch] WITH NOCHECK
  ADD CONSTRAINT [FK_AccountMergeBatch_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
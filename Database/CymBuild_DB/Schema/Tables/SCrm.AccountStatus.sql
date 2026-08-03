PRINT (N'Create table [SCrm].[AccountStatus]')
GO
PRINT (N'Create table [SCrm].[AccountStatus]')
GO
CREATE TABLE [SCrm].[AccountStatus] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_AccountStatus_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_AccountStatus_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](100) NOT NULL CONSTRAINT [DF_AccountStatus_Name] DEFAULT (N''),
  [IsHold] [bit] NOT NULL CONSTRAINT [DEFAULT_AccountStatus_IsHold] DEFAULT (0),
  [IsLive] [bit] NOT NULL CONSTRAINT [DF_AccountStatus_IsLive] DEFAULT (0)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_AccountStatus] on table [SCrm].[AccountStatus]')
GO
ALTER TABLE [SCrm].[AccountStatus] WITH NOCHECK
  ADD CONSTRAINT [PK_AccountStatus] PRIMARY KEY CLUSTERED ([ID])
GO

PRINT (N'Create index [IX_AccountStatus_IsLive] on table [SCrm].[AccountStatus]')
GO
CREATE INDEX [IX_AccountStatus_IsLive]
  ON [SCrm].[AccountStatus] ([IsLive])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_AccountStatus_Guid] on table [SCrm].[AccountStatus]')
GO
CREATE UNIQUE INDEX [IX_UQ_AccountStatus_Guid]
  ON [SCrm].[AccountStatus] ([Guid])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_UQ_AccountStatus_Name] on table [SCrm].[AccountStatus]')
GO
CREATE UNIQUE INDEX [IX_UQ_AccountStatus_Name]
  ON [SCrm].[AccountStatus] ([Name], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_AccountStatus_RecordHistory] on table [SCrm].[AccountStatus]')
GO
CREATE TRIGGER [SCrm].[tg_AccountStatus_RecordHistory]
   ON  [SCrm].[AccountStatus]	
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
			@TableName NVARCHAR(250) = N'AccountStatus',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[IsHold]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[IsHold]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[IsHold] IS DISTINCT FROM i.[IsHold])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsHold', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 526)
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
				VALUES(1, @SchemaName, @TableName, N'Name', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 527)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 528)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_AccountStatus_DataObjects] on table [SCrm].[AccountStatus]')
GO
ALTER TABLE [SCrm].[AccountStatus] WITH NOCHECK
  ADD CONSTRAINT [FK_AccountStatus_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_AccountStatus_DataObjects] on table [SCrm].[AccountStatus]')
GO
ALTER TABLE [SCrm].[AccountStatus]
  NOCHECK CONSTRAINT [FK_AccountStatus_DataObjects]
GO

PRINT (N'Create foreign key [FK_AccountStatus_RowStatus] on table [SCrm].[AccountStatus]')
GO
ALTER TABLE [SCrm].[AccountStatus] WITH NOCHECK
  ADD CONSTRAINT [FK_AccountStatus_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
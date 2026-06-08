PRINT (N'Create table [SJob].[JobPurposeGroups]')
GO
CREATE TABLE [SJob].[JobPurposeGroups] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_JobPurposeGroups_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_JobPurposeGroups_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [JobID] [int] NOT NULL CONSTRAINT [DF_JobPurposeGroups_JobID] DEFAULT (-1),
  [PurposeGroupID] [int] NOT NULL CONSTRAINT [DF_JobPurposeGroups_PurposeGroupID] DEFAULT (-1)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_JobPurposeGroups] on table [SJob].[JobPurposeGroups]')
GO
ALTER TABLE [SJob].[JobPurposeGroups] WITH NOCHECK
  ADD CONSTRAINT [PK_JobPurposeGroups] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_JobPurposeGroups_JobId] on table [SJob].[JobPurposeGroups]')
GO
CREATE INDEX [IX_JobPurposeGroups_JobId]
  ON [SJob].[JobPurposeGroups] ([JobID], [RowStatus])
  INCLUDE ([Guid])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_JobPurposeGroups_Guid] on table [SJob].[JobPurposeGroups]')
GO
CREATE UNIQUE INDEX [IX_UQ_JobPurposeGroups_Guid]
  ON [SJob].[JobPurposeGroups] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create statistics [stat_JobPurposeGroups_Job_Guid] on table [SJob].[JobPurposeGroups]')
GO
CREATE STATISTICS [stat_JobPurposeGroups_Job_Guid]
  ON [SJob].[JobPurposeGroups] ([JobID], [Guid])
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_JobPurposeGroups_RecordHistory] on table [SJob].[JobPurposeGroups]')
GO
CREATE TRIGGER [SJob].[tg_JobPurposeGroups_RecordHistory]
   ON  [SJob].[JobPurposeGroups]	
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
			@SchemaName NVARCHAR(250) = N'SJob',
			@TableName NVARCHAR(250) = N'JobPurposeGroups',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[JobID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[JobID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[JobID] IS DISTINCT FROM i.[JobID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'JobID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 577)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[PurposeGroupID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[PurposeGroupID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[PurposeGroupID] IS DISTINCT FROM i.[PurposeGroupID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'PurposeGroupID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 578)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 579)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_JobPurposeGroups_DataObjects] on table [SJob].[JobPurposeGroups]')
GO
ALTER TABLE [SJob].[JobPurposeGroups] WITH NOCHECK
  ADD CONSTRAINT [FK_JobPurposeGroups_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_JobPurposeGroups_DataObjects] on table [SJob].[JobPurposeGroups]')
GO
ALTER TABLE [SJob].[JobPurposeGroups]
  NOCHECK CONSTRAINT [FK_JobPurposeGroups_DataObjects]
GO

PRINT (N'Create foreign key [FK_JobPurposeGroups_Jobs] on table [SJob].[JobPurposeGroups]')
GO
ALTER TABLE [SJob].[JobPurposeGroups] WITH NOCHECK
  ADD CONSTRAINT [FK_JobPurposeGroups_Jobs] FOREIGN KEY ([JobID]) REFERENCES [SJob].[Jobs] ([ID]) ON DELETE CASCADE
GO

PRINT (N'Create foreign key [FK_JobPurposeGroups_PurposeGroups] on table [SJob].[JobPurposeGroups]')
GO
ALTER TABLE [SJob].[JobPurposeGroups] WITH NOCHECK
  ADD CONSTRAINT [FK_JobPurposeGroups_PurposeGroups] FOREIGN KEY ([PurposeGroupID]) REFERENCES [SJob].[PurposeGroups] ([ID])
GO

PRINT (N'Create foreign key [FK_JobPurposeGroups_RowStatus] on table [SJob].[JobPurposeGroups]')
GO
ALTER TABLE [SJob].[JobPurposeGroups] WITH NOCHECK
  ADD CONSTRAINT [FK_JobPurposeGroups_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
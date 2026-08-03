PRINT (N'Create table [SJob].[JobTypeProjectDirectoryRoles]')
GO
PRINT (N'Create table [SJob].[JobTypeProjectDirectoryRoles]')
GO
CREATE TABLE [SJob].[JobTypeProjectDirectoryRoles] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_JobTypeProjectDirectoryRoles_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_JobTypeProjectDirectoryRoles_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [JobTypeID] [int] NOT NULL CONSTRAINT [DF_JobTypeProjectDirectoryRoles_JobTypeID] DEFAULT (-1),
  [ProjectDirectoryRoleID] [int] NOT NULL CONSTRAINT [DF_JobTypeProjectDirectoryRoles_ProjectDirectoryRoleID] DEFAULT (-1),
  [SortOrder] [int] NOT NULL CONSTRAINT [DF_JobTypeProjectDirectoryRoles_SortOrder] DEFAULT (0)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_JobTypeProjectDirectoryRoles] on table [SJob].[JobTypeProjectDirectoryRoles]')
GO
ALTER TABLE [SJob].[JobTypeProjectDirectoryRoles] WITH NOCHECK
  ADD CONSTRAINT [PK_JobTypeProjectDirectoryRoles] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create index [IX_UQ_JobTypeProjectDirectoryRoles_Guid] on table [SJob].[JobTypeProjectDirectoryRoles]')
GO
CREATE UNIQUE INDEX [IX_UQ_JobTypeProjectDirectoryRoles_Guid]
  ON [SJob].[JobTypeProjectDirectoryRoles] ([Guid])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_UQ_JobTypeProjectDirectoryRoles_JobType_Role] on table [SJob].[JobTypeProjectDirectoryRoles]')
GO
CREATE UNIQUE INDEX [IX_UQ_JobTypeProjectDirectoryRoles_JobType_Role]
  ON [SJob].[JobTypeProjectDirectoryRoles] ([JobTypeID], [ProjectDirectoryRoleID], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_JobTypeProjectDirectoryRoles_RecordHistory] on table [SJob].[JobTypeProjectDirectoryRoles]')
GO
CREATE TRIGGER [SJob].[tg_JobTypeProjectDirectoryRoles_RecordHistory]
   ON  [SJob].[JobTypeProjectDirectoryRoles]	
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
			@TableName NVARCHAR(250) = N'JobTypeProjectDirectoryRoles',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[JobTypeID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[JobTypeID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[JobTypeID] IS DISTINCT FROM i.[JobTypeID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'JobTypeID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 936)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ProjectDirectoryRoleID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ProjectDirectoryRoleID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ProjectDirectoryRoleID] IS DISTINCT FROM i.[ProjectDirectoryRoleID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ProjectDirectoryRoleID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 937)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 938)
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
				VALUES(1, @SchemaName, @TableName, N'SortOrder', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 940)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_JobTypeProjectDirectoryRoles_DataObjects] on table [SJob].[JobTypeProjectDirectoryRoles]')
GO
ALTER TABLE [SJob].[JobTypeProjectDirectoryRoles] WITH NOCHECK
  ADD CONSTRAINT [FK_JobTypeProjectDirectoryRoles_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_JobTypeProjectDirectoryRoles_DataObjects] on table [SJob].[JobTypeProjectDirectoryRoles]')
GO
ALTER TABLE [SJob].[JobTypeProjectDirectoryRoles]
  NOCHECK CONSTRAINT [FK_JobTypeProjectDirectoryRoles_DataObjects]
GO

PRINT (N'Create foreign key [FK_JobTypeProjectDirectoryRoles_JobTypes] on table [SJob].[JobTypeProjectDirectoryRoles]')
GO
ALTER TABLE [SJob].[JobTypeProjectDirectoryRoles] WITH NOCHECK
  ADD CONSTRAINT [FK_JobTypeProjectDirectoryRoles_JobTypes] FOREIGN KEY ([JobTypeID]) REFERENCES [SJob].[JobTypes] ([ID])
GO

PRINT (N'Create foreign key [FK_JobTypeProjectDirectoryRoles_ProjectDirectoryRoles] on table [SJob].[JobTypeProjectDirectoryRoles]')
GO
ALTER TABLE [SJob].[JobTypeProjectDirectoryRoles] WITH NOCHECK
  ADD CONSTRAINT [FK_JobTypeProjectDirectoryRoles_ProjectDirectoryRoles] FOREIGN KEY ([ProjectDirectoryRoleID]) REFERENCES [SJob].[ProjectDirectoryRoles] ([ID])
GO

PRINT (N'Create foreign key [FK_JobTypeProjectDirectoryRoles_RowStatus] on table [SJob].[JobTypeProjectDirectoryRoles]')
GO
ALTER TABLE [SJob].[JobTypeProjectDirectoryRoles] WITH NOCHECK
  ADD CONSTRAINT [FK_JobTypeProjectDirectoryRoles_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
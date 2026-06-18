PRINT (N'Create table [SCore].[ObjectSecurity]')
GO
CREATE TABLE [SCore].[ObjectSecurity] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_ObjectSecurity_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_ObjectSecurity_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [ObjectGuid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_ObjectSecurity_RecordGuid] DEFAULT ('00000000-0000-0000-0000-000000000000'),
  [UserId] [int] NOT NULL CONSTRAINT [DF_ObjectSecurity_UserId] DEFAULT (-1),
  [GroupId] [int] NOT NULL CONSTRAINT [DF_ObjectSecurity_GroupId] DEFAULT (-1),
  [CanRead] [bit] NOT NULL CONSTRAINT [DF_ObjectSecurity_CanRead] DEFAULT (0),
  [DenyRead] [bit] NOT NULL CONSTRAINT [DF_ObjectSecurity_DenyRead] DEFAULT (0),
  [CanWrite] [bit] NOT NULL CONSTRAINT [DF_ObjectSecurity_CanWrite] DEFAULT (0),
  [DenyWrite] [bit] NOT NULL CONSTRAINT [DF_ObjectSecurity_DenyWrite] DEFAULT (0)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_ObjectSecurity] on table [SCore].[ObjectSecurity]')
GO
ALTER TABLE [SCore].[ObjectSecurity] WITH NOCHECK
  ADD CONSTRAINT [PK_ObjectSecurity] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 90)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_ObjectSecurity_CanRead] on table [SCore].[ObjectSecurity]')
GO
CREATE INDEX [IX_ObjectSecurity_CanRead]
  ON [SCore].[ObjectSecurity] ([ObjectGuid], [CanRead], [RowStatus])
  INCLUDE ([UserId], [GroupId])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_ObjectSecurity_DenyRead] on table [SCore].[ObjectSecurity]')
GO
CREATE INDEX [IX_ObjectSecurity_DenyRead]
  ON [SCore].[ObjectSecurity] ([ObjectGuid], [DenyRead], [RowStatus])
  INCLUDE ([UserId], [GroupId])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_UQ_ObjectSecurity_Setting] on table [SCore].[ObjectSecurity]')
GO
CREATE UNIQUE INDEX [IX_UQ_ObjectSecurity_Setting]
  ON [SCore].[ObjectSecurity] ([ObjectGuid], [UserId], [GroupId], [RowStatus])
  INCLUDE ([CanRead], [DenyRead], [CanWrite], [DenyWrite])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create statistics [stat_ObjectSecurity_CanRead] on table [SCore].[ObjectSecurity]')
GO
CREATE STATISTICS [stat_ObjectSecurity_CanRead]
  ON [SCore].[ObjectSecurity] ([UserId], [GroupId], [DenyRead], [ObjectGuid], [CanRead])
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_ObjectSecurity_RecordHistory] on table [SCore].[ObjectSecurity]')
GO
CREATE TRIGGER [SCore].[tg_ObjectSecurity_RecordHistory]
   ON  [SCore].[ObjectSecurity]	
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
			@TableName NVARCHAR(250) = N'ObjectSecurity',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[CanRead]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[CanRead]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[CanRead] IS DISTINCT FROM i.[CanRead])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'CanRead', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1053)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[CanWrite]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[CanWrite]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[CanWrite] IS DISTINCT FROM i.[CanWrite])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'CanWrite', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1054)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[DenyRead]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[DenyRead]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[DenyRead] IS DISTINCT FROM i.[DenyRead])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'DenyRead', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1055)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[DenyWrite]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[DenyWrite]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[DenyWrite] IS DISTINCT FROM i.[DenyWrite])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'DenyWrite', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1056)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[GroupId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[GroupId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[GroupId] IS DISTINCT FROM i.[GroupId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'GroupId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1057)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ObjectGuid]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ObjectGuid]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ObjectGuid] IS DISTINCT FROM i.[ObjectGuid])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ObjectGuid', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1060)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1061)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[UserId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[UserId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[UserId] IS DISTINCT FROM i.[UserId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'UserId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1063)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_ObjectSecurity_DataObjects] on table [SCore].[ObjectSecurity]')
GO
ALTER TABLE [SCore].[ObjectSecurity] WITH NOCHECK
  ADD CONSTRAINT [FK_ObjectSecurity_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_ObjectSecurity_DataObjects] on table [SCore].[ObjectSecurity]')
GO
ALTER TABLE [SCore].[ObjectSecurity]
  NOCHECK CONSTRAINT [FK_ObjectSecurity_DataObjects]
GO

PRINT (N'Create foreign key [FK_ObjectSecurity_Goups] on table [SCore].[ObjectSecurity]')
GO
ALTER TABLE [SCore].[ObjectSecurity] WITH NOCHECK
  ADD CONSTRAINT [FK_ObjectSecurity_Goups] FOREIGN KEY ([GroupId]) REFERENCES [SCore].[Groups] ([ID])
GO

PRINT (N'Create foreign key [FK_ObjectSecurity_RowStatus] on table [SCore].[ObjectSecurity]')
GO
ALTER TABLE [SCore].[ObjectSecurity] WITH NOCHECK
  ADD CONSTRAINT [FK_ObjectSecurity_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_ObjectSecurity_Users] on table [SCore].[ObjectSecurity]')
GO
ALTER TABLE [SCore].[ObjectSecurity] WITH NOCHECK
  ADD CONSTRAINT [FK_ObjectSecurity_Users] FOREIGN KEY ([UserId]) REFERENCES [SCore].[Identities] ([ID])
GO
PRINT (N'Create table [SCore].[UserGroups]')
GO
CREATE TABLE [SCore].[UserGroups] (
  [ID] [int] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_UserGroups_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_UserGroups_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [IdentityID] [int] NOT NULL CONSTRAINT [DF_UserGroups_UserID] DEFAULT (-1),
  [GroupID] [int] NOT NULL CONSTRAINT [DF_UserGroups_GroupID] DEFAULT (-1)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_UserGroups] on table [SCore].[UserGroups]')
GO
ALTER TABLE [SCore].[UserGroups] WITH NOCHECK
  ADD CONSTRAINT [PK_UserGroups] PRIMARY KEY CLUSTERED ([ID])
GO

PRINT (N'Create index [IX_UQ_UserGroups_Guid] on table [SCore].[UserGroups]')
GO
CREATE UNIQUE INDEX [IX_UQ_UserGroups_Guid]
  ON [SCore].[UserGroups] ([Guid])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_UQ_UserGroups_Identity_Group] on table [SCore].[UserGroups]')
GO
CREATE UNIQUE INDEX [IX_UQ_UserGroups_Identity_Group]
  ON [SCore].[UserGroups] ([IdentityID], [GroupID], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_UserGroups_RecordHistory] on table [SCore].[UserGroups]')
GO
CREATE TRIGGER [SCore].[tg_UserGroups_RecordHistory]
   ON  [SCore].[UserGroups]	
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
			@TableName NVARCHAR(250) = N'UserGroups',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[GroupID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[GroupID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[GroupID] IS DISTINCT FROM i.[GroupID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'GroupID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1278)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[IdentityID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[IdentityID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[IdentityID] IS DISTINCT FROM i.[IdentityID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IdentityID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1277)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1275)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_UserGroups_DataObjects] on table [SCore].[UserGroups]')
GO
ALTER TABLE [SCore].[UserGroups] WITH NOCHECK
  ADD CONSTRAINT [FK_UserGroups_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_UserGroups_DataObjects] on table [SCore].[UserGroups]')
GO
ALTER TABLE [SCore].[UserGroups]
  NOCHECK CONSTRAINT [FK_UserGroups_DataObjects]
GO

PRINT (N'Create foreign key [FK_UserGroups_Groups] on table [SCore].[UserGroups]')
GO
ALTER TABLE [SCore].[UserGroups] WITH NOCHECK
  ADD CONSTRAINT [FK_UserGroups_Groups] FOREIGN KEY ([GroupID]) REFERENCES [SCore].[Groups] ([ID]) ON DELETE CASCADE
GO

PRINT (N'Create foreign key [FK_UserGroups_Identities] on table [SCore].[UserGroups]')
GO
ALTER TABLE [SCore].[UserGroups] WITH NOCHECK
  ADD CONSTRAINT [FK_UserGroups_Identities] FOREIGN KEY ([IdentityID]) REFERENCES [SCore].[Identities] ([ID]) ON DELETE CASCADE
GO

PRINT (N'Create foreign key [FK_UserGroups_RowStatus] on table [SCore].[UserGroups]')
GO
ALTER TABLE [SCore].[UserGroups] WITH NOCHECK
  ADD CONSTRAINT [FK_UserGroups_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
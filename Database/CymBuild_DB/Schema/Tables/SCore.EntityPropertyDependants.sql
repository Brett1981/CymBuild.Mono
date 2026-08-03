PRINT (N'Create table [SCore].[EntityPropertyDependants]')
GO
PRINT (N'Create table [SCore].[EntityPropertyDependants]')
GO
CREATE TABLE [SCore].[EntityPropertyDependants] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_EEntityPropertyDependants_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_EEntityPropertyDependants_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [ParentEntityPropertyID] [int] NOT NULL CONSTRAINT [DF_EEntityPropertyDependants_ParentEntityPropertyID] DEFAULT (-1),
  [DependantPropertyID] [int] NOT NULL CONSTRAINT [DF_EEntityPropertyDependants_DependentEntityPropertyID] DEFAULT (-1)
)
ON [METADATA]
GO

PRINT (N'Create primary key [PK_EntityPropertyDependants] on table [SCore].[EntityPropertyDependants]')
GO
ALTER TABLE [SCore].[EntityPropertyDependants] WITH NOCHECK
  ADD CONSTRAINT [PK_EntityPropertyDependants] PRIMARY KEY CLUSTERED ([ID]) ON [METADATA]
GO

PRINT (N'Create index [IX_UQ_EntityPropertyDependants_Guid] on table [SCore].[EntityPropertyDependants]')
GO
CREATE UNIQUE INDEX [IX_UQ_EntityPropertyDependants_Guid]
  ON [SCore].[EntityPropertyDependants] ([Guid])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_EntityPropertyDependants_Parent_Dependant] on table [SCore].[EntityPropertyDependants]')
GO
CREATE UNIQUE INDEX [IX_UQ_EntityPropertyDependants_Parent_Dependant]
  ON [SCore].[EntityPropertyDependants] ([ParentEntityPropertyID], [DependantPropertyID])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_EntityPropertyDependants_RecordHistory] on table [SCore].[EntityPropertyDependants]')
GO
CREATE TRIGGER [SCore].[tg_EntityPropertyDependants_RecordHistory]
   ON  [SCore].[EntityPropertyDependants]	
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
			@TableName NVARCHAR(250) = N'EntityPropertyDependants',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[DependantPropertyID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[DependantPropertyID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[DependantPropertyID] IS DISTINCT FROM i.[DependantPropertyID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'DependantPropertyID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 745)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ParentEntityPropertyID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ParentEntityPropertyID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ParentEntityPropertyID] IS DISTINCT FROM i.[ParentEntityPropertyID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ParentEntityPropertyID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 748)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 749)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_EntityPropertyDependants_EntityProperties] on table [SCore].[EntityPropertyDependants]')
GO
ALTER TABLE [SCore].[EntityPropertyDependants] WITH NOCHECK
  ADD CONSTRAINT [FK_EntityPropertyDependants_EntityProperties] FOREIGN KEY ([ParentEntityPropertyID]) REFERENCES [SCore].[EntityProperties] ([ID])
GO

PRINT (N'Create foreign key [FK_EntityPropertyDependants_EntityProperties1] on table [SCore].[EntityPropertyDependants]')
GO
ALTER TABLE [SCore].[EntityPropertyDependants] WITH NOCHECK
  ADD CONSTRAINT [FK_EntityPropertyDependants_EntityProperties1] FOREIGN KEY ([DependantPropertyID]) REFERENCES [SCore].[EntityProperties] ([ID])
GO

PRINT (N'Create foreign key [FK_EntityPropertyDependants_RowStatus] on table [SCore].[EntityPropertyDependants]')
GO
ALTER TABLE [SCore].[EntityPropertyDependants] WITH NOCHECK
  ADD CONSTRAINT [FK_EntityPropertyDependants_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
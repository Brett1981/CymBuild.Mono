PRINT (N'Create table [SCore].[Groups]')
GO
PRINT (N'Create table [SCore].[Groups]')
GO
CREATE TABLE [SCore].[Groups] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Groups_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_Groups_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [DirectoryId] [nvarchar](100) NOT NULL CONSTRAINT [DF_Groups_DirectoryId] DEFAULT (''),
  [Code] [nvarchar](30) NOT NULL CONSTRAINT [DF_Groups_Code] DEFAULT (''),
  [Name] [nvarchar](250) NOT NULL CONSTRAINT [DF_Groups_Name] DEFAULT (''),
  [Source] [nvarchar](250) NOT NULL CONSTRAINT [DF_Groups_Source] DEFAULT ('')
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_Groups] on table [SCore].[Groups]')
GO
ALTER TABLE [SCore].[Groups] WITH NOCHECK
  ADD CONSTRAINT [PK_Groups] PRIMARY KEY CLUSTERED ([ID])
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_UQ_DirectoryID] on table [SCore].[Groups]')
GO
CREATE UNIQUE INDEX [IX_UQ_DirectoryID]
  ON [SCore].[Groups] ([DirectoryId])
  WHERE ([DirectoryId]<>N'')
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_Groups_Guid] on table [SCore].[Groups]')
GO
CREATE UNIQUE INDEX [IX_UQ_Groups_Guid]
  ON [SCore].[Groups] ([Guid])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_Uq_Groups_Name] on table [SCore].[Groups]')
GO
CREATE UNIQUE INDEX [IX_Uq_Groups_Name]
  ON [SCore].[Groups] ([Name])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_Groups_RecordHistory] on table [SCore].[Groups]')
GO
CREATE TRIGGER [SCore].[tg_Groups_RecordHistory]
   ON  [SCore].[Groups]	
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
			@TableName NVARCHAR(250) = N'Groups',
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
				VALUES(1, @SchemaName, @TableName, N'Code', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1066)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[DirectoryId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[DirectoryId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[DirectoryId] IS DISTINCT FROM i.[DirectoryId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'DirectoryId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1067)
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
				VALUES(1, @SchemaName, @TableName, N'Name', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1070)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1071)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Source]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Source]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Source] IS DISTINCT FROM i.[Source])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Source', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2556)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_Groups_DataObjects] on table [SCore].[Groups]')
GO
ALTER TABLE [SCore].[Groups] WITH NOCHECK
  ADD CONSTRAINT [FK_Groups_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_Groups_DataObjects] on table [SCore].[Groups]')
GO
ALTER TABLE [SCore].[Groups]
  NOCHECK CONSTRAINT [FK_Groups_DataObjects]
GO

PRINT (N'Create foreign key [FK_Groups_RowStatus] on table [SCore].[Groups]')
GO
ALTER TABLE [SCore].[Groups] WITH NOCHECK
  ADD CONSTRAINT [FK_Groups_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Add extended property [MS_Description] on table [SCore].[Groups]')
GO
EXEC sys.sp_addextendedproperty N'MS_Description', N'Groups of Users', 'SCHEMA', N'SCore', 'TABLE', N'Groups'
GO

PRINT (N'Add extended property [MS_Description] on column [SCore].[Groups].[Source]')
GO
EXEC sys.sp_addextendedproperty N'MS_Description', N'Kafka notification source identifier (e.g. cymbuild-fireengineering-authorisation)', 'SCHEMA', N'SCore', 'TABLE', N'Groups', 'COLUMN', N'Source'
GO

PRINT (N'Add extended property [MS_Description] on table [SCore].[Groups]')
GO


PRINT (N'Add extended property [MS_Description] on column [SCore].[Groups].[Source]')
GO
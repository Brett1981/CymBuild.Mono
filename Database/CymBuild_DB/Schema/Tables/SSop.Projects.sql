PRINT (N'Create table [SSop].[Projects]')
GO
PRINT (N'Create table [SSop].[Projects]')
GO
CREATE TABLE [SSop].[Projects] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Projects_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_Projects_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Number] [int] NOT NULL CONSTRAINT [DF_Projects_Number] DEFAULT (0),
  [ExternalReference] [nvarchar](50) NOT NULL CONSTRAINT [DF_Projects_ExternalReference] DEFAULT (''),
  [ProjectDescription] [nvarchar](max) NOT NULL CONSTRAINT [DF_Projects_ProjectDescription] DEFAULT (''),
  [ProjectProjectsStartDate] [date] NULL,
  [ProjectProjectedEndDate] [date] NULL,
  [ProjectCompleted] [date] NULL,
  [IsSubjectToNDA] [bit] NOT NULL CONSTRAINT [DF_Projects_IsSubjectToNDA] DEFAULT (0),
  [DataClassificationID] [int] NOT NULL CONSTRAINT [DF_Projects_DataClassificationID] DEFAULT (-1),
  [SecurityClassificationID] [int] NOT NULL CONSTRAINT [DF_Projects_SecurityClassificationID] DEFAULT (-1)
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_Projects] on table [SSop].[Projects]')
GO
ALTER TABLE [SSop].[Projects] WITH NOCHECK
  ADD CONSTRAINT [PK_Projects] PRIMARY KEY CLUSTERED ([ID])
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_UQ_Projects_Number] on table [SSop].[Projects]')
GO
CREATE UNIQUE INDEX [IX_UQ_Projects_Number]
  ON [SSop].[Projects] ([Number], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UX_Projects_Guid] on table [SSop].[Projects]')
GO
CREATE UNIQUE INDEX [IX_UX_Projects_Guid]
  ON [SSop].[Projects] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_Projects_RecordHistory] on table [SSop].[Projects]')
GO
CREATE TRIGGER [SSop].[tg_Projects_RecordHistory]
   ON  [SSop].[Projects]	
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
			@SchemaName NVARCHAR(250) = N'SSop',
			@TableName NVARCHAR(250) = N'Projects',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ExternalReference]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ExternalReference]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ExternalReference] IS DISTINCT FROM i.[ExternalReference])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ExternalReference', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1218)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[IsSubjectToNDA]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[IsSubjectToNDA]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[IsSubjectToNDA] IS DISTINCT FROM i.[IsSubjectToNDA])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsSubjectToNDA', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1814)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Number]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Number]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Number] IS DISTINCT FROM i.[Number])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Number', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1221)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ProjectCompleted]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ProjectCompleted]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ProjectCompleted] IS DISTINCT FROM i.[ProjectCompleted])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ProjectCompleted', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1222)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ProjectDescription]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ProjectDescription]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ProjectDescription] IS DISTINCT FROM i.[ProjectDescription])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ProjectDescription', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1223)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ProjectProjectedEndDate]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ProjectProjectedEndDate]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ProjectProjectedEndDate] IS DISTINCT FROM i.[ProjectProjectedEndDate])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ProjectProjectedEndDate', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1224)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ProjectProjectsStartDate]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ProjectProjectsStartDate]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ProjectProjectsStartDate] IS DISTINCT FROM i.[ProjectProjectsStartDate])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ProjectProjectsStartDate', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1225)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1226)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_Projects_DataClassifications] on table [SSop].[Projects]')
GO
ALTER TABLE [SSop].[Projects] WITH NOCHECK
  ADD CONSTRAINT [FK_Projects_DataClassifications] FOREIGN KEY ([DataClassificationID]) REFERENCES [SCore].[DataClassifications] ([ID])
GO

PRINT (N'Create foreign key [FK_Projects_DataObjects] on table [SSop].[Projects]')
GO
ALTER TABLE [SSop].[Projects] WITH NOCHECK
  ADD CONSTRAINT [FK_Projects_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid]) ON DELETE CASCADE
GO

PRINT (N'Disable foreign key [FK_Projects_DataObjects] on table [SSop].[Projects]')
GO
ALTER TABLE [SSop].[Projects]
  NOCHECK CONSTRAINT [FK_Projects_DataObjects]
GO

PRINT (N'Create foreign key [FK_Projects_RowStatus] on table [SSop].[Projects]')
GO
ALTER TABLE [SSop].[Projects] WITH NOCHECK
  ADD CONSTRAINT [FK_Projects_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_Projects_SecurityClassifications] on table [SSop].[Projects]')
GO
ALTER TABLE [SSop].[Projects] WITH NOCHECK
  ADD CONSTRAINT [FK_Projects_SecurityClassifications] FOREIGN KEY ([SecurityClassificationID]) REFERENCES [SCore].[SecurityClassifications] ([ID])
GO
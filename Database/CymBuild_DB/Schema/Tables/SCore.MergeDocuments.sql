PRINT (N'Create table [SCore].[MergeDocuments]')
GO
CREATE TABLE [SCore].[MergeDocuments] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_MergeDocuments_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_MergeDocuments_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](250) NOT NULL CONSTRAINT [DF_MergeDocuments_Name] DEFAULT (''),
  [FilenameTemplate] [nvarchar](250) NOT NULL CONSTRAINT [DF_MergeDocuments_FilenameTemplate] DEFAULT (''),
  [EntityTypeId] [int] NOT NULL CONSTRAINT [DF_MergeDocuments_EntityTypeId] DEFAULT (-1),
  [DocumentId] [nvarchar](500) NOT NULL CONSTRAINT [DF_MergeDocuments_DocumentId] DEFAULT (''),
  [LinkedEntityTypeId] [int] NOT NULL CONSTRAINT [DF_MergeDocuments_LinkedEntityTypeId] DEFAULT (-1),
  [SharepointSiteId] [int] NOT NULL CONSTRAINT [DF_MergeDocuments_SharepointSiteId] DEFAULT (-1),
  [AllowPDFOutputOnly] [bit] NOT NULL CONSTRAINT [DF_MergeDocuments_AllowPDFOutputOnly] DEFAULT (0),
  [ProduceOneOutputPerRow] [bit] NOT NULL CONSTRAINT [DF_MergeDocuments_ProduceOneOutputPerRow] DEFAULT (0),
  [AllowExcelOutputOnly] [bit] NOT NULL CONSTRAINT [DF_MergeDocuments_AllowExcelOutputOnly] DEFAULT (0)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_MergeDocuments] on table [SCore].[MergeDocuments]')
GO
ALTER TABLE [SCore].[MergeDocuments] WITH NOCHECK
  ADD CONSTRAINT [PK_MergeDocuments] PRIMARY KEY CLUSTERED ([ID])
GO

PRINT (N'Create unique key [UQ__MergeDocuments_Guid] on table [SCore].[MergeDocuments]')
GO
ALTER TABLE [SCore].[MergeDocuments] WITH NOCHECK
  ADD CONSTRAINT [UQ__MergeDocuments_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 90)
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_MergeDocuments_RecordHistory] on table [SCore].[MergeDocuments]')
GO
CREATE TRIGGER [SCore].[tg_MergeDocuments_RecordHistory]
   ON  [SCore].[MergeDocuments]	
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
			@TableName NVARCHAR(250) = N'MergeDocuments',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[AllowExcelOutputOnly]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[AllowExcelOutputOnly]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[AllowExcelOutputOnly] IS DISTINCT FROM i.[AllowExcelOutputOnly])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'AllowExcelOutputOnly', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2047)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[AllowPDFOutputOnly]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[AllowPDFOutputOnly]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[AllowPDFOutputOnly] IS DISTINCT FROM i.[AllowPDFOutputOnly])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'AllowPDFOutputOnly', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1977)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[DocumentId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[DocumentId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[DocumentId] IS DISTINCT FROM i.[DocumentId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'DocumentId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 689)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[EntityTypeId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[EntityTypeId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[EntityTypeId] IS DISTINCT FROM i.[EntityTypeId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'EntityTypeId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 691)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[FilenameTemplate]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[FilenameTemplate]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[FilenameTemplate] IS DISTINCT FROM i.[FilenameTemplate])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'FilenameTemplate', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 692)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[LinkedEntityTypeId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[LinkedEntityTypeId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[LinkedEntityTypeId] IS DISTINCT FROM i.[LinkedEntityTypeId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'LinkedEntityTypeId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 695)
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
				VALUES(1, @SchemaName, @TableName, N'Name', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 696)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ProduceOneOutputPerRow]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ProduceOneOutputPerRow]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ProduceOneOutputPerRow] IS DISTINCT FROM i.[ProduceOneOutputPerRow])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ProduceOneOutputPerRow', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1978)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 697)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[SharepointSiteId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[SharepointSiteId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[SharepointSiteId] IS DISTINCT FROM i.[SharepointSiteId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'SharepointSiteId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1023)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_MergeDocuments_DataObjects] on table [SCore].[MergeDocuments]')
GO
ALTER TABLE [SCore].[MergeDocuments] WITH NOCHECK
  ADD CONSTRAINT [FK_MergeDocuments_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_MergeDocuments_DataObjects] on table [SCore].[MergeDocuments]')
GO
ALTER TABLE [SCore].[MergeDocuments]
  NOCHECK CONSTRAINT [FK_MergeDocuments_DataObjects]
GO

PRINT (N'Create foreign key [FK_MergeDocuments_EntityTypes] on table [SCore].[MergeDocuments]')
GO
ALTER TABLE [SCore].[MergeDocuments] WITH NOCHECK
  ADD CONSTRAINT [FK_MergeDocuments_EntityTypes] FOREIGN KEY ([EntityTypeId]) REFERENCES [SCore].[EntityTypes] ([ID])
GO

PRINT (N'Create foreign key [FK_MergeDocuments_EntityTypes1] on table [SCore].[MergeDocuments]')
GO
ALTER TABLE [SCore].[MergeDocuments] WITH NOCHECK
  ADD CONSTRAINT [FK_MergeDocuments_EntityTypes1] FOREIGN KEY ([LinkedEntityTypeId]) REFERENCES [SCore].[EntityTypes] ([ID])
GO

PRINT (N'Create foreign key [FK_MergeDocuments_RowStatus] on table [SCore].[MergeDocuments]')
GO
ALTER TABLE [SCore].[MergeDocuments] WITH NOCHECK
  ADD CONSTRAINT [FK_MergeDocuments_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_MergeDocuments_SharepointSites] on table [SCore].[MergeDocuments]')
GO
ALTER TABLE [SCore].[MergeDocuments] WITH NOCHECK
  ADD CONSTRAINT [FK_MergeDocuments_SharepointSites] FOREIGN KEY ([SharepointSiteId]) REFERENCES [SCore].[SharepointSites] ([ID])
GO

PRINT (N'Add extended property [MS_Description] on table [SCore].[MergeDocuments]')
GO
EXEC sys.sp_addextendedproperty N'MS_Description', N'The definitions of Merge Documents ', 'SCHEMA', N'SCore', 'TABLE', N'MergeDocuments'
GO
PRINT (N'Create table [SUserInterface].[DropDownListDefinitions]')
GO
CREATE TABLE [SUserInterface].[DropDownListDefinitions] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_DropDownListDefinition_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_DropDownListDefinitions_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Code] [nvarchar](20) NOT NULL CONSTRAINT [DF_DropDownListDefinition_Code] DEFAULT (''),
  [NameColumn] [nvarchar](254) NOT NULL CONSTRAINT [DF_DropDownListDefinition_NameColumn] DEFAULT (''),
  [ValueColumn] [nvarchar](254) NOT NULL CONSTRAINT [DF_DropDownListDefinition_ValueColumn] DEFAULT (''),
  [SqlQuery] [nvarchar](max) NOT NULL CONSTRAINT [DF_DropDownListDefinition_SqlQuery] DEFAULT (''),
  [DefaultSortColumnName] [nvarchar](254) NOT NULL CONSTRAINT [DF_DropDownListDefinition_DefaultSortColumnName] DEFAULT (N'ID'),
  [IsDefaultColumn] [nvarchar](254) NOT NULL CONSTRAINT [DF_DropDownListDefinition_IdDefaultColumn] DEFAULT (''),
  [DetailPageUrl] [nvarchar](250) NOT NULL CONSTRAINT [DF_DropDownListDefinitions_DetailPageUrl] DEFAULT (''),
  [IsDetailWindowed] [bit] NOT NULL CONSTRAINT [DF_DropDownListDefinitions_IsDetailWindowed] DEFAULT (0),
  [EntityTypeId] [int] NOT NULL CONSTRAINT [DF_DropDownListDefinitions_EntityTypeId] DEFAULT (-1),
  [InformationPageUrl] [nvarchar](250) NOT NULL CONSTRAINT [DF_DropDownListDefinitions_InformationPageUrl] DEFAULT (''),
  [GroupColumn] [nvarchar](254) NOT NULL CONSTRAINT [DF_DropDownListDefinitions_GroupColumn] DEFAULT (''),
  [ColourHexColumn] [nvarchar](7) NOT NULL CONSTRAINT [DF_DropDownListDefinitions_ColourHexColumn] DEFAULT ('#000000'),
  [ExternalSearchPageUrl] [nvarchar](250) NOT NULL CONSTRAINT [DF_DropDownListDefinitions_ExternalSearchPageUrl] DEFAULT ('')
)
ON [METADATA]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_DropDownListDefinitions] on table [SUserInterface].[DropDownListDefinitions]')
GO
ALTER TABLE [SUserInterface].[DropDownListDefinitions] WITH NOCHECK
  ADD CONSTRAINT [PK_DropDownListDefinitions] PRIMARY KEY CLUSTERED ([ID]) ON [METADATA]
GO

PRINT (N'Create index [IX_DropDownListDefinition_Settings] on table [SUserInterface].[DropDownListDefinitions]')
GO
CREATE INDEX [IX_DropDownListDefinition_Settings]
  ON [SUserInterface].[DropDownListDefinitions] ([Guid], [RowStatus])
  INCLUDE ([NameColumn], [ValueColumn], [SqlQuery], [Code], [DefaultSortColumnName], [GroupColumn])
  WITH (FILLFACTOR = 100)
  ON [METADATA]
GO

PRINT (N'Create index [IX_UQ_DropDownListDefinition_Code] on table [SUserInterface].[DropDownListDefinitions]')
GO
CREATE UNIQUE INDEX [IX_UQ_DropDownListDefinition_Code]
  ON [SUserInterface].[DropDownListDefinitions] ([Code], [RowStatus])
  WITH (FILLFACTOR = 100)
  ON [METADATA]
GO

PRINT (N'Create index [IX_UQ_DropDownListDefinition_Guid] on table [SUserInterface].[DropDownListDefinitions]')
GO
CREATE UNIQUE INDEX [IX_UQ_DropDownListDefinition_Guid]
  ON [SUserInterface].[DropDownListDefinitions] ([Guid], [RowStatus])
  WITH (FILLFACTOR = 100)
  ON [METADATA]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_DropDownListDefinitions_RecordHistory] on table [SUserInterface].[DropDownListDefinitions]')
GO
CREATE TRIGGER [SUserInterface].[tg_DropDownListDefinitions_RecordHistory]
   ON  [SUserInterface].[DropDownListDefinitions]	
   AFTER UPDATE
AS 
BEGIN
	SET NOCOUNT ON;

    IF (ISNULL(CONVERT(int, SESSION_CONTEXT(N'S_disable_triggers')), 0) = 1)
    BEGIN 
        RETURN
    END

    DECLARE	@PreviousValue NVARCHAR(MAX),
			@NewValue NVARCHAR(MAX),
			@UserID INT = 0,
			@SchemaName NVARCHAR(250) = N'SUserInterface',
			@TableName NVARCHAR(250) = N'DropDownListDefinitions',
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
		
		SELECT	
					@PreviousValue = ISNULL(d.[RowStatus], N''),
					@NewValue = ISNULL(i.[RowStatus], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[RowStatus] <> i.[RowStatus])
                        OR  (ISNULL(d.[RowStatus], N'') <> ISNULL(i.[RowStatus], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 115)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[Code], N''),
					@NewValue = ISNULL(i.[Code], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[Code] <> i.[Code])
                        OR  (ISNULL(d.[Code], N'') <> ISNULL(i.[Code], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Code', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 118)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[NameColumn], N''),
					@NewValue = ISNULL(i.[NameColumn], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[NameColumn] <> i.[NameColumn])
                        OR  (ISNULL(d.[NameColumn], N'') <> ISNULL(i.[NameColumn], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'NameColumn', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 119)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[ValueColumn], N''),
					@NewValue = ISNULL(i.[ValueColumn], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[ValueColumn] <> i.[ValueColumn])
                        OR  (ISNULL(d.[ValueColumn], N'') <> ISNULL(i.[ValueColumn], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ValueColumn', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 120)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[SqlQuery], N''),
					@NewValue = ISNULL(i.[SqlQuery], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[SqlQuery] <> i.[SqlQuery])
                        OR  (ISNULL(d.[SqlQuery], N'') <> ISNULL(i.[SqlQuery], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'SqlQuery', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 121)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[DefaultSortColumnName], N''),
					@NewValue = ISNULL(i.[DefaultSortColumnName], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[DefaultSortColumnName] <> i.[DefaultSortColumnName])
                        OR  (ISNULL(d.[DefaultSortColumnName], N'') <> ISNULL(i.[DefaultSortColumnName], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'DefaultSortColumnName', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 122)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[IsDefaultColumn], N''),
					@NewValue = ISNULL(i.[IsDefaultColumn], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[IsDefaultColumn] <> i.[IsDefaultColumn])
                        OR  (ISNULL(d.[IsDefaultColumn], N'') <> ISNULL(i.[IsDefaultColumn], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsDefaultColumn', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 123)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[DetailPageUrl], N''),
					@NewValue = ISNULL(i.[DetailPageUrl], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[DetailPageUrl] <> i.[DetailPageUrl])
                        OR  (ISNULL(d.[DetailPageUrl], N'') <> ISNULL(i.[DetailPageUrl], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'DetailPageUrl', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 521)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[IsDetailWindowed], N''),
					@NewValue = ISNULL(i.[IsDetailWindowed], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[IsDetailWindowed] <> i.[IsDetailWindowed])
                        OR  (ISNULL(d.[IsDetailWindowed], N'') <> ISNULL(i.[IsDetailWindowed], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsDetailWindowed', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 522)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[EntityTypeId], N''),
					@NewValue = ISNULL(i.[EntityTypeId], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[EntityTypeId] <> i.[EntityTypeId])
                        OR  (ISNULL(d.[EntityTypeId], N'') <> ISNULL(i.[EntityTypeId], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'EntityTypeId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 523)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[InformationPageUrl], N''),
					@NewValue = ISNULL(i.[InformationPageUrl], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[InformationPageUrl] <> i.[InformationPageUrl])
                        OR  (ISNULL(d.[InformationPageUrl], N'') <> ISNULL(i.[InformationPageUrl], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'InformationPageUrl', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 726)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[GroupColumn], N''),
					@NewValue = ISNULL(i.[GroupColumn], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[GroupColumn] <> i.[GroupColumn])
                        OR  (ISNULL(d.[GroupColumn], N'') <> ISNULL(i.[GroupColumn], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'GroupColumn', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 751)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_DropDownListDefinitions_EntityTypes] on table [SUserInterface].[DropDownListDefinitions]')
GO
ALTER TABLE [SUserInterface].[DropDownListDefinitions] WITH NOCHECK
  ADD CONSTRAINT [FK_DropDownListDefinitions_EntityTypes] FOREIGN KEY ([EntityTypeId]) REFERENCES [SCore].[EntityTypes] ([ID])
GO

PRINT (N'Create foreign key [FK_DropDownListDefinitions_RowStatus] on table [SUserInterface].[DropDownListDefinitions]')
GO
ALTER TABLE [SUserInterface].[DropDownListDefinitions] WITH NOCHECK
  ADD CONSTRAINT [FK_DropDownListDefinitions_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
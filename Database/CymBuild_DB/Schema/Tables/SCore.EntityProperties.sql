PRINT (N'Create table [SCore].[EntityProperties]')
GO
CREATE TABLE [SCore].[EntityProperties] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_EntityProperties_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_EntityProperties_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](250) NOT NULL CONSTRAINT [DF_EntityProperties_Name] DEFAULT (''),
  [LanguageLabelID] [int] NOT NULL CONSTRAINT [DF_EntityProperties_LanguageLabelID] DEFAULT (-1),
  [EntityHoBTID] [int] NOT NULL CONSTRAINT [DF_EntityProperties_EntityHoBTID] DEFAULT (-1),
  [EntityDataTypeID] [int] NOT NULL CONSTRAINT [DF_EntityProperties_EntityDateTypeID] DEFAULT (-1),
  [IsReadOnly] [bit] NOT NULL CONSTRAINT [DF_EntityProperties_IsReadOnly] DEFAULT (0),
  [IsImmutable] [bit] NOT NULL CONSTRAINT [DF_EntityProperties_IsImmutable] DEFAULT (0),
  [IsUppercase] [bit] NOT NULL CONSTRAINT [DF_EntityProperties_IsUppercase] DEFAULT (0),
  [IsHidden] [bit] NOT NULL CONSTRAINT [DF_EntityProperties_IsHidden] DEFAULT (0),
  [IsCompulsory] [bit] NOT NULL CONSTRAINT [DF_EntityProperties_IsCompulsory] DEFAULT (0),
  [MaxLength] [int] NOT NULL CONSTRAINT [DF_EntityProperties_MaxLength] DEFAULT (0),
  [Precision] [int] NOT NULL CONSTRAINT [DF_EntityProperties_Precision] DEFAULT (0),
  [Scale] [int] NOT NULL CONSTRAINT [DF_EntityProperties_Scale] DEFAULT (0),
  [DoNotTrackChanges] [bit] NOT NULL CONSTRAINT [DF_EntityProperties_DoNotTrackChanges] DEFAULT (0),
  [EntityPropertyGroupID] [int] NOT NULL CONSTRAINT [DF_EntityProperties_EntityPropertyGroupID] DEFAULT (-1),
  [SortOrder] [smallint] NOT NULL CONSTRAINT [DF_EntityProperties_SortOrder] DEFAULT (0),
  [GroupSortOrder] [smallint] NOT NULL CONSTRAINT [DF_EntityProperties_GroupSortOrder] DEFAULT (0),
  [IsObjectLabel] [bit] NOT NULL CONSTRAINT [DEFAULT_EntityProperties_IsObjectLabel] DEFAULT (0),
  [DropDownListDefinitionID] [int] NOT NULL CONSTRAINT [DF_EntityProperties_DropDownListDefinitionID] DEFAULT (-1),
  [IsParentRelationship] [bit] NOT NULL CONSTRAINT [DEFAULT_EntityProperties_IsParentRelationship] DEFAULT (0),
  [IsLongitude] [bit] NOT NULL CONSTRAINT [DF_EntityProperties_IsLongitude] DEFAULT (0),
  [IsLatitude] [bit] NOT NULL CONSTRAINT [DF_EntityProperties_IsLatitude] DEFAULT (0),
  [IsIncludedInformation] [bit] NOT NULL CONSTRAINT [DF_EntityProperties_IsIncludedInformation] DEFAULT (0),
  [FixedDefaultValue] [nvarchar](50) NOT NULL CONSTRAINT [DF_EntityProperties_FixDefaultValue] DEFAULT (''),
  [SqlDefaultValueStatement] [nvarchar](4000) NOT NULL CONSTRAINT [DF_EntityProperties_SqlDefaultValueScript] DEFAULT (''),
  [AllowBulkChange] [bit] NOT NULL CONSTRAINT [DF_EntityProperties_AllowBulkChange] DEFAULT (0),
  [IsVirtual] [bit] NOT NULL CONSTRAINT [DF_EntityProperties_IsVirtual] DEFAULT (0),
  [ShowOnMobile] [bit] NOT NULL CONSTRAINT [DF_EntityProperties_ShowOnMobile] DEFAULT (0),
  [IsAlwaysVisibleInGroup] [bit] NOT NULL CONSTRAINT [DF_EntityProperties_IsAlwaysVisibleInGroup] DEFAULT (0),
  [IsAlwaysVisibleInGroup_Mobile] [bit] NOT NULL CONSTRAINT [DF_EntityProperties_IsAlwaysVisibleInGroup_Mobile] DEFAULT (0)
)
ON [METADATA]
GO

PRINT (N'Create primary key [PK_EntityProperties] on table [SCore].[EntityProperties]')
GO
ALTER TABLE [SCore].[EntityProperties] WITH NOCHECK
  ADD CONSTRAINT [PK_EntityProperties] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80) ON [METADATA]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_HobtProperties] on table [SCore].[EntityProperties]')
GO
CREATE INDEX [IX_HobtProperties]
  ON [SCore].[EntityProperties] ([EntityHoBTID], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 100)
  ON [METADATA]
GO

PRINT (N'Create index [IX_SCore_EntityProperties_107494679] on table [SCore].[EntityProperties]')
GO
CREATE INDEX [IX_SCore_EntityProperties_107494679]
  ON [SCore].[EntityProperties] ([Name], [EntityHoBTID])
  INCLUDE ([Guid], [LanguageLabelID])
  WITH (FILLFACTOR = 80)
  ON [METADATA]
GO

PRINT (N'Create index [IX_SCore_EntityProperties_1457811955] on table [SCore].[EntityProperties]')
GO
CREATE INDEX [IX_SCore_EntityProperties_1457811955]
  ON [SCore].[EntityProperties] ([DropDownListDefinitionID])
  INCLUDE ([Guid], [Name], [EntityHoBTID])
  WITH (FILLFACTOR = 80)
  ON [METADATA]
GO

PRINT (N'Create index [IX_SCore_EntityProperties_632192243] on table [SCore].[EntityProperties]')
GO
CREATE INDEX [IX_SCore_EntityProperties_632192243]
  ON [SCore].[EntityProperties] ([EntityHoBTID])
  INCLUDE ([RowStatus], [Guid], [Name], [EntityDataTypeID], [IsHidden], [EntityPropertyGroupID], [SortOrder], [GroupSortOrder])
  WITH (FILLFACTOR = 80)
  ON [METADATA]
GO

PRINT (N'Create index [IX_SCore_EntityProperties_938382760] on table [SCore].[EntityProperties]')
GO
CREATE INDEX [IX_SCore_EntityProperties_938382760]
  ON [SCore].[EntityProperties] ([EntityHoBTID], [DropDownListDefinitionID])
  INCLUDE ([Guid], [Name])
  WITH (FILLFACTOR = 80)
  ON [METADATA]
GO

PRINT (N'Create index [IX_UQ_EntityProperties_Guid] on table [SCore].[EntityProperties]')
GO
CREATE UNIQUE INDEX [IX_UQ_EntityProperties_Guid]
  ON [SCore].[EntityProperties] ([Guid])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_UQ_EntityProperties_Hobt_Name] on table [SCore].[EntityProperties]')
GO
CREATE UNIQUE INDEX [IX_UQ_EntityProperties_Hobt_Name]
  ON [SCore].[EntityProperties] ([EntityHoBTID], [Name], [RowStatus])
  INCLUDE ([Guid])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_EntityProperties_RecordHistory] on table [SCore].[EntityProperties]')
GO
CREATE TRIGGER [SCore].[tg_EntityProperties_RecordHistory]
   ON  [SCore].[EntityProperties]	
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
			@SchemaName NVARCHAR(250) = N'SCore',
			@TableName NVARCHAR(250) = N'EntityProperties',
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 40)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[Name], N''),
					@NewValue = ISNULL(i.[Name], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[Name] <> i.[Name])
                        OR  (ISNULL(d.[Name], N'') <> ISNULL(i.[Name], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Name', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 43)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[LanguageLabelID], N''),
					@NewValue = ISNULL(i.[LanguageLabelID], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[LanguageLabelID] <> i.[LanguageLabelID])
                        OR  (ISNULL(d.[LanguageLabelID], N'') <> ISNULL(i.[LanguageLabelID], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'LanguageLabelID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 44)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[EntityHoBTID], N''),
					@NewValue = ISNULL(i.[EntityHoBTID], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[EntityHoBTID] <> i.[EntityHoBTID])
                        OR  (ISNULL(d.[EntityHoBTID], N'') <> ISNULL(i.[EntityHoBTID], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'EntityHoBTID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 45)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[EntityDataTypeID], N''),
					@NewValue = ISNULL(i.[EntityDataTypeID], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[EntityDataTypeID] <> i.[EntityDataTypeID])
                        OR  (ISNULL(d.[EntityDataTypeID], N'') <> ISNULL(i.[EntityDataTypeID], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'EntityDataTypeID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 46)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[IsReadOnly], N''),
					@NewValue = ISNULL(i.[IsReadOnly], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[IsReadOnly] <> i.[IsReadOnly])
                        OR  (ISNULL(d.[IsReadOnly], N'') <> ISNULL(i.[IsReadOnly], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsReadOnly', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 47)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[IsImmutable], N''),
					@NewValue = ISNULL(i.[IsImmutable], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[IsImmutable] <> i.[IsImmutable])
                        OR  (ISNULL(d.[IsImmutable], N'') <> ISNULL(i.[IsImmutable], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsImmutable', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 48)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[IsUppercase], N''),
					@NewValue = ISNULL(i.[IsUppercase], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[IsUppercase] <> i.[IsUppercase])
                        OR  (ISNULL(d.[IsUppercase], N'') <> ISNULL(i.[IsUppercase], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsUppercase', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 49)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[IsHidden], N''),
					@NewValue = ISNULL(i.[IsHidden], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[IsHidden] <> i.[IsHidden])
                        OR  (ISNULL(d.[IsHidden], N'') <> ISNULL(i.[IsHidden], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsHidden', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 50)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[IsCompulsory], N''),
					@NewValue = ISNULL(i.[IsCompulsory], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[IsCompulsory] <> i.[IsCompulsory])
                        OR  (ISNULL(d.[IsCompulsory], N'') <> ISNULL(i.[IsCompulsory], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsCompulsory', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 51)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[MaxLength], N''),
					@NewValue = ISNULL(i.[MaxLength], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[MaxLength] <> i.[MaxLength])
                        OR  (ISNULL(d.[MaxLength], N'') <> ISNULL(i.[MaxLength], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'MaxLength', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 52)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[Precision], N''),
					@NewValue = ISNULL(i.[Precision], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[Precision] <> i.[Precision])
                        OR  (ISNULL(d.[Precision], N'') <> ISNULL(i.[Precision], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Precision', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 53)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[Scale], N''),
					@NewValue = ISNULL(i.[Scale], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[Scale] <> i.[Scale])
                        OR  (ISNULL(d.[Scale], N'') <> ISNULL(i.[Scale], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Scale', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 54)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[DoNotTrackChanges], N''),
					@NewValue = ISNULL(i.[DoNotTrackChanges], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[DoNotTrackChanges] <> i.[DoNotTrackChanges])
                        OR  (ISNULL(d.[DoNotTrackChanges], N'') <> ISNULL(i.[DoNotTrackChanges], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'DoNotTrackChanges', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 55)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[EntityPropertyGroupID], N''),
					@NewValue = ISNULL(i.[EntityPropertyGroupID], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[EntityPropertyGroupID] <> i.[EntityPropertyGroupID])
                        OR  (ISNULL(d.[EntityPropertyGroupID], N'') <> ISNULL(i.[EntityPropertyGroupID], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'EntityPropertyGroupID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 56)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[SortOrder], N''),
					@NewValue = ISNULL(i.[SortOrder], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[SortOrder] <> i.[SortOrder])
                        OR  (ISNULL(d.[SortOrder], N'') <> ISNULL(i.[SortOrder], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'SortOrder', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 57)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[GroupSortOrder], N''),
					@NewValue = ISNULL(i.[GroupSortOrder], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[GroupSortOrder] <> i.[GroupSortOrder])
                        OR  (ISNULL(d.[GroupSortOrder], N'') <> ISNULL(i.[GroupSortOrder], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'GroupSortOrder', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 58)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[IsObjectLabel], N''),
					@NewValue = ISNULL(i.[IsObjectLabel], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[IsObjectLabel] <> i.[IsObjectLabel])
                        OR  (ISNULL(d.[IsObjectLabel], N'') <> ISNULL(i.[IsObjectLabel], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsObjectLabel', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 159)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[DropDownListDefinitionID], N''),
					@NewValue = ISNULL(i.[DropDownListDefinitionID], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[DropDownListDefinitionID] <> i.[DropDownListDefinitionID])
                        OR  (ISNULL(d.[DropDownListDefinitionID], N'') <> ISNULL(i.[DropDownListDefinitionID], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'DropDownListDefinitionID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 269)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[IsParentRelationship], N''),
					@NewValue = ISNULL(i.[IsParentRelationship], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[IsParentRelationship] <> i.[IsParentRelationship])
                        OR  (ISNULL(d.[IsParentRelationship], N'') <> ISNULL(i.[IsParentRelationship], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsParentRelationship', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 270)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[IsIncludedInformation], N''),
					@NewValue = ISNULL(i.[IsIncludedInformation], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[IsIncludedInformation] <> i.[IsIncludedInformation])
                        OR  (ISNULL(d.[IsIncludedInformation], N'') <> ISNULL(i.[IsIncludedInformation], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsIncludedInformation', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 723)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[IsLatitude], N''),
					@NewValue = ISNULL(i.[IsLatitude], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[IsLatitude] <> i.[IsLatitude])
                        OR  (ISNULL(d.[IsLatitude], N'') <> ISNULL(i.[IsLatitude], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsLatitude', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 724)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[IsLongitude], N''),
					@NewValue = ISNULL(i.[IsLongitude], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[IsLongitude] <> i.[IsLongitude])
                        OR  (ISNULL(d.[IsLongitude], N'') <> ISNULL(i.[IsLongitude], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsLongitude', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 725)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[FixedDefaultValue], N''),
					@NewValue = ISNULL(i.[FixedDefaultValue], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[FixedDefaultValue] <> i.[FixedDefaultValue])
                        OR  (ISNULL(d.[FixedDefaultValue], N'') <> ISNULL(i.[FixedDefaultValue], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'FixedDefaultValue', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 947)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(d.[SqlDefaultValueStatement], N''),
					@NewValue = ISNULL(i.[SqlDefaultValueStatement], N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (
                        (d.[SqlDefaultValueStatement] <> i.[SqlDefaultValueStatement])
                        OR  (ISNULL(d.[SqlDefaultValueStatement], N'') <> ISNULL(i.[SqlDefaultValueStatement], N''))
                    )


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'SqlDefaultValueStatement', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 948)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_EntityProperties_DropDownListDefinitions] on table [SCore].[EntityProperties]')
GO
ALTER TABLE [SCore].[EntityProperties] WITH NOCHECK
  ADD CONSTRAINT [FK_EntityProperties_DropDownListDefinitions] FOREIGN KEY ([DropDownListDefinitionID]) REFERENCES [SUserInterface].[DropDownListDefinitions] ([ID])
GO

PRINT (N'Create foreign key [FK_EntityProperties_EntityDataTypes] on table [SCore].[EntityProperties]')
GO
ALTER TABLE [SCore].[EntityProperties] WITH NOCHECK
  ADD CONSTRAINT [FK_EntityProperties_EntityDataTypes] FOREIGN KEY ([EntityDataTypeID]) REFERENCES [SCore].[EntityDataTypes] ([ID])
GO

PRINT (N'Create foreign key [FK_EntityProperties_EntityHoBTs] on table [SCore].[EntityProperties]')
GO
ALTER TABLE [SCore].[EntityProperties] WITH NOCHECK
  ADD CONSTRAINT [FK_EntityProperties_EntityHoBTs] FOREIGN KEY ([EntityHoBTID]) REFERENCES [SCore].[EntityHobts] ([ID]) ON DELETE CASCADE
GO

PRINT (N'Create foreign key [FK_EntityProperties_EntityPropertyGroupID] on table [SCore].[EntityProperties]')
GO
ALTER TABLE [SCore].[EntityProperties] WITH NOCHECK
  ADD CONSTRAINT [FK_EntityProperties_EntityPropertyGroupID] FOREIGN KEY ([EntityPropertyGroupID]) REFERENCES [SCore].[EntityPropertyGroups] ([ID])
GO

PRINT (N'Create foreign key [FK_EntityProperties_LanguageLabels] on table [SCore].[EntityProperties]')
GO
ALTER TABLE [SCore].[EntityProperties] WITH NOCHECK
  ADD CONSTRAINT [FK_EntityProperties_LanguageLabels] FOREIGN KEY ([LanguageLabelID]) REFERENCES [SCore].[LanguageLabels] ([ID])
GO

PRINT (N'Create foreign key [FK_EntityProperties_RowStatus] on table [SCore].[EntityProperties]')
GO
ALTER TABLE [SCore].[EntityProperties] WITH NOCHECK
  ADD CONSTRAINT [FK_EntityProperties_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
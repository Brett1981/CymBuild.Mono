SET QUOTED_IDENTIFIER ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create table [SCore].[Identities]')
GO
CREATE TABLE [SCore].[Identities] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Identities_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_Identities_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [FullName] [nvarchar](250) NOT NULL CONSTRAINT [DF_Identities_FullName] DEFAULT (N''),
  [EmailAddress] [nvarchar](150) NOT NULL CONSTRAINT [DF_Tickets_EmailAddress] DEFAULT (N''),
  [UserGuid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_Identities_UserGuid] DEFAULT (newid()),
  [JobTitle] [nvarchar](50) NOT NULL CONSTRAINT [DF_Identities_JobTitle] DEFAULT (''),
  [OriganisationalUnitId] [int] NOT NULL CONSTRAINT [DF_Identities_OriganisationalUnitId] DEFAULT (-1),
  [IsActive] [bit] NOT NULL CONSTRAINT [DF_Identities_IsActive] DEFAULT (0),
  [ContactId] [int] NOT NULL CONSTRAINT [DF__Identitie__Conta__6EE2037B] DEFAULT (-1),
  [BillableRate] [decimal](19, 2) NOT NULL CONSTRAINT [DF_Identities_BillableRate] DEFAULT (0),
  [LoweredEmailAddress] AS (lower([EmailAddress])) PERSISTED,
  [Signature] [varbinary](max) NOT NULL CONSTRAINT [DF_Identities_Signature] DEFAULT (0x)
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_Identities] on table [SCore].[Identities]')
GO
ALTER TABLE [SCore].[Identities] WITH NOCHECK
  ADD CONSTRAINT [PK_Identities] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Identities_List] on table [SCore].[Identities]')
GO
CREATE INDEX [IX_Identities_List]
  ON [SCore].[Identities] ([IsActive], [RowStatus])
  INCLUDE ([FullName], [Guid], [OriganisationalUnitId])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254) AND [IsActive]=(1))
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Identities_LoweredEmailAddress] on table [SCore].[Identities]')
GO
CREATE INDEX [IX_Identities_LoweredEmailAddress]
  ON [SCore].[Identities] ([LoweredEmailAddress])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Identities_Name] on table [SCore].[Identities]')
GO
CREATE INDEX [IX_Identities_Name]
  ON [SCore].[Identities] ([FullName], [IsActive], [RowStatus])
  WHERE ([RowStatus]<>(254) AND [RowStatus]<>(0))
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_Identities_EmailAddress] on table [SCore].[Identities]')
GO
CREATE UNIQUE INDEX [IX_UQ_Identities_EmailAddress]
  ON [SCore].[Identities] ([EmailAddress])
  INCLUDE ([Guid])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_Identities_Guid] on table [SCore].[Identities]')
GO
CREATE UNIQUE INDEX [IX_UQ_Identities_Guid]
  ON [SCore].[Identities] ([Guid])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_Identities_RecordHistory] on table [SCore].[Identities]')
GO
CREATE TRIGGER [SCore].[tg_Identities_RecordHistory]
   ON  [SCore].[Identities]	
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
			@TableName NVARCHAR(250) = N'Identities',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[BillableRate]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[BillableRate]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[BillableRate] IS DISTINCT FROM i.[BillableRate])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'BillableRate', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1674)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ContactId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ContactId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ContactId] IS DISTINCT FROM i.[ContactId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ContactId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1383)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[EmailAddress]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[EmailAddress]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[EmailAddress] IS DISTINCT FROM i.[EmailAddress])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'EmailAddress', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 543)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[FullName]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[FullName]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[FullName] IS DISTINCT FROM i.[FullName])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'FullName', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 544)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[IsActive]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[IsActive]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[IsActive] IS DISTINCT FROM i.[IsActive])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsActive', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1382)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[JobTitle]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[JobTitle]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[JobTitle] IS DISTINCT FROM i.[JobTitle])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'JobTitle', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1051)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[OriganisationalUnitId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[OriganisationalUnitId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[OriganisationalUnitId] IS DISTINCT FROM i.[OriganisationalUnitId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'OriganisationalUnitId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1052)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 547)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Signature]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Signature]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Signature] IS DISTINCT FROM i.[Signature])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Signature', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1717)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[UserGuid]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[UserGuid]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[UserGuid] IS DISTINCT FROM i.[UserGuid])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'UserGuid', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 549)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_Identities_ContactId] on table [SCore].[Identities]')
GO
ALTER TABLE [SCore].[Identities] WITH NOCHECK
  ADD CONSTRAINT [FK_Identities_ContactId] FOREIGN KEY ([ContactId]) REFERENCES [SCrm].[Contacts] ([ID])
GO

PRINT (N'Create foreign key [FK_Identities_DataObjects] on table [SCore].[Identities]')
GO
ALTER TABLE [SCore].[Identities] WITH NOCHECK
  ADD CONSTRAINT [FK_Identities_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_Identities_DataObjects] on table [SCore].[Identities]')
GO
ALTER TABLE [SCore].[Identities]
  NOCHECK CONSTRAINT [FK_Identities_DataObjects]
GO

PRINT (N'Create foreign key [FK_Identities_OrganisationalUnits] on table [SCore].[Identities]')
GO
ALTER TABLE [SCore].[Identities] WITH NOCHECK
  ADD CONSTRAINT [FK_Identities_OrganisationalUnits] FOREIGN KEY ([OriganisationalUnitId]) REFERENCES [SCore].[OrganisationalUnits] ([ID])
GO

PRINT (N'Create foreign key [FK_Identities_RowStatus] on table [SCore].[Identities]')
GO
ALTER TABLE [SCore].[Identities] WITH NOCHECK
  ADD CONSTRAINT [FK_Identities_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Add extended property [MS_Description] on table [SCore].[Identities]')
GO
EXEC sys.sp_addextendedproperty N'MS_Description', N'Users mapped to their Entra ID''s', 'SCHEMA', N'SCore', 'TABLE', N'Identities'
GO
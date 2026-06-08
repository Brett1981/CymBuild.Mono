PRINT (N'Create table [SFin].[SageExports]')
GO
CREATE TABLE [SFin].[SageExports] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DEFAULT_TransactionExportsToSage_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_TransactionExportsToSage_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [ExportData] [nvarchar](max) NOT NULL CONSTRAINT [DF_TransactionExportsToSage_ExportData] DEFAULT (''),
  [InclusiveToDate] [date] NOT NULL CONSTRAINT [DF_TransactionExportsToSage_InclusiveToDate] DEFAULT (getdate()),
  [OrganisationalUnitId] [int] NOT NULL CONSTRAINT [DF_SageExports_OrganisationalUnitId] DEFAULT (-1)
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_TransactionExportsToSage] on table [SFin].[SageExports]')
GO
ALTER TABLE [SFin].[SageExports] WITH NOCHECK
  ADD CONSTRAINT [PK_TransactionExportsToSage] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create index [IX_UQ_SageExports_Guid] on table [SFin].[SageExports]')
GO
CREATE UNIQUE INDEX [IX_UQ_SageExports_Guid]
  ON [SFin].[SageExports] ([Guid])
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_SageExports_RecordHistory] on table [SFin].[SageExports]')
GO
CREATE TRIGGER [SFin].[tg_SageExports_RecordHistory]
   ON  [SFin].[SageExports]	
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
			@SchemaName NVARCHAR(250) = N'SFin',
			@TableName NVARCHAR(250) = N'SageExports',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ExportData]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ExportData]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ExportData] IS DISTINCT FROM i.[ExportData])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ExportData', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1146)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[InclusiveToDate]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[InclusiveToDate]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[InclusiveToDate] IS DISTINCT FROM i.[InclusiveToDate])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'InclusiveToDate', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1149)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[OrganisationalUnitId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[OrganisationalUnitId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[OrganisationalUnitId] IS DISTINCT FROM i.[OrganisationalUnitId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'OrganisationalUnitId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2001)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1150)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_SageExports_DataObjects] on table [SFin].[SageExports]')
GO
ALTER TABLE [SFin].[SageExports] WITH NOCHECK
  ADD CONSTRAINT [FK_SageExports_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_SageExports_DataObjects] on table [SFin].[SageExports]')
GO
ALTER TABLE [SFin].[SageExports]
  NOCHECK CONSTRAINT [FK_SageExports_DataObjects]
GO

PRINT (N'Create foreign key [FK_SageExports_OrganisationalUnits] on table [SFin].[SageExports]')
GO
ALTER TABLE [SFin].[SageExports] WITH NOCHECK
  ADD CONSTRAINT [FK_SageExports_OrganisationalUnits] FOREIGN KEY ([OrganisationalUnitId]) REFERENCES [SCore].[OrganisationalUnits] ([ID])
GO

PRINT (N'Create foreign key [FK_SageExports_RowStatus] on table [SFin].[SageExports]')
GO
ALTER TABLE [SFin].[SageExports] WITH NOCHECK
  ADD CONSTRAINT [FK_SageExports_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_TransactionExportsToSage_RowStatus] on table [SFin].[SageExports]')
GO
ALTER TABLE [SFin].[SageExports] WITH NOCHECK
  ADD CONSTRAINT [FK_TransactionExportsToSage_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
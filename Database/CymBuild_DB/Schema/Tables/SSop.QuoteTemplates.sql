PRINT (N'Create table [SSop].[QuoteTemplates]')
GO
CREATE TABLE [SSop].[QuoteTemplates] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_QuoteTemplates_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_QuoteTemplates_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [OrganisationalUnitID] [int] NOT NULL CONSTRAINT [DF_QuoteTemplates_OrganisationalUnitID] DEFAULT (-1),
  [Number] [int] NOT NULL CONSTRAINT [DF_QuoteTemplates_Number] DEFAULT (0),
  [Overview] [nvarchar](max) NOT NULL CONSTRAINT [DF_QuoteTemplates_Overview] DEFAULT (''),
  [FeeCap] [decimal](9, 2) NOT NULL CONSTRAINT [DF_QuoteTemplates_FeeCap] DEFAULT (0),
  [ContractId] [int] NOT NULL DEFAULT (-1),
  [ContractBandId] [int] NOT NULL DEFAULT (-1)
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_QuoteTemplates] on table [SSop].[QuoteTemplates]')
GO
ALTER TABLE [SSop].[QuoteTemplates] WITH NOCHECK
  ADD CONSTRAINT [PK_QuoteTemplates] PRIMARY KEY CLUSTERED ([ID])
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_QuoteTemplates_RecordHistory] on table [SSop].[QuoteTemplates]')
GO
CREATE TRIGGER [SSop].[tg_QuoteTemplates_RecordHistory]
   ON  [SSop].[QuoteTemplates]	
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
			@TableName NVARCHAR(250) = N'QuoteTemplates',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[FeeCap]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[FeeCap]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[FeeCap] IS DISTINCT FROM i.[FeeCap])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'FeeCap', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 885)
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
				VALUES(1, @SchemaName, @TableName, N'Number', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 888)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[OrganisationalUnitID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[OrganisationalUnitID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[OrganisationalUnitID] IS DISTINCT FROM i.[OrganisationalUnitID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'OrganisationalUnitID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 889)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Overview]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Overview]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Overview] IS DISTINCT FROM i.[Overview])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Overview', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 890)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 891)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_QuoteTemplates_ContractBandId] on table [SSop].[QuoteTemplates]')
GO
ALTER TABLE [SSop].[QuoteTemplates] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteTemplates_ContractBandId] FOREIGN KEY ([ContractBandId]) REFERENCES [SSop].[ContractBands] ([ID])
GO

PRINT (N'Create foreign key [FK_QuoteTemplates_ContractId] on table [SSop].[QuoteTemplates]')
GO
ALTER TABLE [SSop].[QuoteTemplates] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteTemplates_ContractId] FOREIGN KEY ([ContractId]) REFERENCES [SSop].[Contracts] ([ID])
GO

PRINT (N'Create foreign key [FK_QuoteTemplates_DataObjects] on table [SSop].[QuoteTemplates]')
GO
ALTER TABLE [SSop].[QuoteTemplates] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteTemplates_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_QuoteTemplates_DataObjects] on table [SSop].[QuoteTemplates]')
GO
ALTER TABLE [SSop].[QuoteTemplates]
  NOCHECK CONSTRAINT [FK_QuoteTemplates_DataObjects]
GO

PRINT (N'Create foreign key [FK_QuoteTemplates_OrganisationalUnits] on table [SSop].[QuoteTemplates]')
GO
ALTER TABLE [SSop].[QuoteTemplates] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteTemplates_OrganisationalUnits] FOREIGN KEY ([OrganisationalUnitID]) REFERENCES [SCore].[OrganisationalUnits] ([ID])
GO

PRINT (N'Create foreign key [FK_QuoteTemplates_RowStatus] on table [SSop].[QuoteTemplates]')
GO
ALTER TABLE [SSop].[QuoteTemplates] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteTemplates_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
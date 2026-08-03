PRINT (N'Create table [SFin].[PaymentFrequencyTypes]')
GO
PRINT (N'Create table [SFin].[PaymentFrequencyTypes]')
GO
CREATE TABLE [SFin].[PaymentFrequencyTypes] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_PaymentFrequencyTypes_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_PaymentFrequencyTypes_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](50) NOT NULL CONSTRAINT [DF_PaymentFrequencyTypes_Name] DEFAULT ('')
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_PaymentFrequencyTypes] on table [SFin].[PaymentFrequencyTypes]')
GO
ALTER TABLE [SFin].[PaymentFrequencyTypes] WITH NOCHECK
  ADD CONSTRAINT [PK_PaymentFrequencyTypes] PRIMARY KEY CLUSTERED ([ID])
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_UQ_PaymentFrequency_Name] on table [SFin].[PaymentFrequencyTypes]')
GO
CREATE UNIQUE INDEX [IX_UQ_PaymentFrequency_Name]
  ON [SFin].[PaymentFrequencyTypes] ([Guid], [Name], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_PaymentFrequencyTypes_Guid] on table [SFin].[PaymentFrequencyTypes]')
GO
CREATE UNIQUE INDEX [IX_UQ_PaymentFrequencyTypes_Guid]
  ON [SFin].[PaymentFrequencyTypes] ([Guid])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_PaymentFrequencyTypes_RecordHistory] on table [SFin].[PaymentFrequencyTypes]')
GO
CREATE TRIGGER [SFin].[tg_PaymentFrequencyTypes_RecordHistory]
   ON  [SFin].[PaymentFrequencyTypes]	
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
			@TableName NVARCHAR(250) = N'PaymentFrequencyTypes',
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
				VALUES(1, @SchemaName, @TableName, N'Name', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1619)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1616)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_PaymentFrequencyTypes_DataObjects] on table [SFin].[PaymentFrequencyTypes]')
GO
ALTER TABLE [SFin].[PaymentFrequencyTypes] WITH NOCHECK
  ADD CONSTRAINT [FK_PaymentFrequencyTypes_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_PaymentFrequencyTypes_DataObjects] on table [SFin].[PaymentFrequencyTypes]')
GO
ALTER TABLE [SFin].[PaymentFrequencyTypes]
  NOCHECK CONSTRAINT [FK_PaymentFrequencyTypes_DataObjects]
GO

PRINT (N'Create foreign key [FK_PaymentFrequencyTypes_RowStatus] on table [SFin].[PaymentFrequencyTypes]')
GO
ALTER TABLE [SFin].[PaymentFrequencyTypes] WITH NOCHECK
  ADD CONSTRAINT [FK_PaymentFrequencyTypes_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
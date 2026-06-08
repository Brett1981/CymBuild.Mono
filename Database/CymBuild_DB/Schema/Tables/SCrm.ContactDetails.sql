PRINT (N'Create table [SCrm].[ContactDetails]')
GO
PRINT (N'Create table [SCrm].[ContactDetails]')
GO
CREATE TABLE [SCrm].[ContactDetails] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_ContactDetails_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_ContactDetails_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [ContactID] [int] NOT NULL CONSTRAINT [DF_ContactDetails_ContactID] DEFAULT (-1),
  [ContactDetailTypeID] [smallint] NOT NULL CONSTRAINT [DF_ContactDetails_ContactDetailTypeID] DEFAULT (-1),
  [Name] [nvarchar](100) NOT NULL CONSTRAINT [DF_ContactDetails_Name] DEFAULT (N''),
  [Value] [nvarchar](250) NOT NULL CONSTRAINT [DF_ContactDetails_Value] DEFAULT (N''),
  [IsDefault] [bit] NOT NULL CONSTRAINT [DF_ContactDetails_IsDefault] DEFAULT (0)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_ContactDetails] on table [SCrm].[ContactDetails]')
GO
ALTER TABLE [SCrm].[ContactDetails] WITH NOCHECK
  ADD CONSTRAINT [PK_ContactDetails] PRIMARY KEY CLUSTERED ([ID])
GO

PRINT (N'Create index [IX_UQ_ContactDetails_ContactID_Name] on table [SCrm].[ContactDetails]')
GO
CREATE UNIQUE INDEX [IX_UQ_ContactDetails_ContactID_Name]
  ON [SCrm].[ContactDetails] ([ContactID], [Name])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_ContactDetails_Guid] on table [SCrm].[ContactDetails]')
GO
CREATE UNIQUE INDEX [IX_UQ_ContactDetails_Guid]
  ON [SCrm].[ContactDetails] ([Guid])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_ContactDetails_RecordHistory] on table [SCrm].[ContactDetails]')
GO
CREATE TRIGGER [SCrm].[tg_ContactDetails_RecordHistory]
   ON  [SCrm].[ContactDetails]	
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
			@SchemaName NVARCHAR(250) = N'SCrm',
			@TableName NVARCHAR(250) = N'ContactDetails',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ContactDetailTypeID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ContactDetailTypeID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ContactDetailTypeID] IS DISTINCT FROM i.[ContactDetailTypeID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ContactDetailTypeID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 199)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ContactID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ContactID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ContactID] IS DISTINCT FROM i.[ContactID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ContactID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 198)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[IsDefault]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[IsDefault]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[IsDefault] IS DISTINCT FROM i.[IsDefault])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsDefault', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1420)
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
				VALUES(1, @SchemaName, @TableName, N'Name', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 200)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 195)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Value]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Value]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Value] IS DISTINCT FROM i.[Value])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Value', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 201)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_ContactDetails_ContactDetailTypes] on table [SCrm].[ContactDetails]')
GO
ALTER TABLE [SCrm].[ContactDetails] WITH NOCHECK
  ADD CONSTRAINT [FK_ContactDetails_ContactDetailTypes] FOREIGN KEY ([ContactDetailTypeID]) REFERENCES [SCrm].[ContactDetailTypes] ([ID])
GO

PRINT (N'Create foreign key [FK_ContactDetails_Contacts] on table [SCrm].[ContactDetails]')
GO
ALTER TABLE [SCrm].[ContactDetails] WITH NOCHECK
  ADD CONSTRAINT [FK_ContactDetails_Contacts] FOREIGN KEY ([ContactID]) REFERENCES [SCrm].[Contacts] ([ID]) ON DELETE CASCADE
GO

PRINT (N'Create foreign key [FK_ContactDetails_DataObjects] on table [SCrm].[ContactDetails]')
GO
ALTER TABLE [SCrm].[ContactDetails] WITH NOCHECK
  ADD CONSTRAINT [FK_ContactDetails_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_ContactDetails_DataObjects] on table [SCrm].[ContactDetails]')
GO
ALTER TABLE [SCrm].[ContactDetails]
  NOCHECK CONSTRAINT [FK_ContactDetails_DataObjects]
GO

PRINT (N'Create foreign key [FK_ContactDetails_RowStatus] on table [SCrm].[ContactDetails]')
GO
ALTER TABLE [SCrm].[ContactDetails] WITH NOCHECK
  ADD CONSTRAINT [FK_ContactDetails_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
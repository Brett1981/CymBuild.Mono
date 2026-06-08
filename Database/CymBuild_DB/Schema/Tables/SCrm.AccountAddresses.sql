PRINT (N'Create table [SCrm].[AccountAddresses]')
GO
CREATE TABLE [SCrm].[AccountAddresses] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_AccountAddresses_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_AccountAddresses_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [AccountID] [int] NOT NULL CONSTRAINT [DF_AccountAddresses_AccountID] DEFAULT (-1),
  [AddressID] [int] NOT NULL CONSTRAINT [DF_AccountAddresses_AddressID] DEFAULT (-1),
  [IsMain] [bit] NOT NULL CONSTRAINT [DF_AccountAddresses_IsMain] DEFAULT (0)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_AccountAddresses] on table [SCrm].[AccountAddresses]')
GO
ALTER TABLE [SCrm].[AccountAddresses] WITH NOCHECK
  ADD CONSTRAINT [PK_AccountAddresses] PRIMARY KEY CLUSTERED ([ID])
GO

PRINT (N'Create index [IX_AccountAddresses_AccountID] on table [SCrm].[AccountAddresses]')
GO
CREATE INDEX [IX_AccountAddresses_AccountID]
  ON [SCrm].[AccountAddresses] ([AccountID])
  INCLUDE ([RowStatus], [Guid], [AddressID])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_UQ_AccountAddresses_AccountID_AddressID] on table [SCrm].[AccountAddresses]')
GO
CREATE UNIQUE INDEX [IX_UQ_AccountAddresses_AccountID_AddressID]
  ON [SCrm].[AccountAddresses] ([AccountID], [AddressID], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_AccountAddresses_Guid] on table [SCrm].[AccountAddresses]')
GO
CREATE UNIQUE INDEX [IX_UQ_AccountAddresses_Guid]
  ON [SCrm].[AccountAddresses] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_AccountAddresses_RecordHistory] on table [SCrm].[AccountAddresses]')
GO
CREATE TRIGGER [SCrm].[tg_AccountAddresses_RecordHistory]
   ON  [SCrm].[AccountAddresses]	
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
			@TableName NVARCHAR(250) = N'AccountAddresses',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[AccountID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[AccountID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[AccountID] IS DISTINCT FROM i.[AccountID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'AccountID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 508)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[AddressID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[AddressID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[AddressID] IS DISTINCT FROM i.[AddressID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'AddressID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 509)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 512)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_AccountAddresses_Accounts] on table [SCrm].[AccountAddresses]')
GO
ALTER TABLE [SCrm].[AccountAddresses] WITH NOCHECK
  ADD CONSTRAINT [FK_AccountAddresses_Accounts] FOREIGN KEY ([AccountID]) REFERENCES [SCrm].[Accounts] ([ID]) ON DELETE CASCADE
GO

PRINT (N'Create foreign key [FK_AccountAddresses_Addresses] on table [SCrm].[AccountAddresses]')
GO
ALTER TABLE [SCrm].[AccountAddresses] WITH NOCHECK
  ADD CONSTRAINT [FK_AccountAddresses_Addresses] FOREIGN KEY ([AddressID]) REFERENCES [SCrm].[Addresses] ([ID])
GO

PRINT (N'Create foreign key [FK_AccountAddresses_DataObjects] on table [SCrm].[AccountAddresses]')
GO
ALTER TABLE [SCrm].[AccountAddresses] WITH NOCHECK
  ADD CONSTRAINT [FK_AccountAddresses_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_AccountAddresses_DataObjects] on table [SCrm].[AccountAddresses]')
GO
ALTER TABLE [SCrm].[AccountAddresses]
  NOCHECK CONSTRAINT [FK_AccountAddresses_DataObjects]
GO

PRINT (N'Create foreign key [FK_AccountAddresses_RowStatus] on table [SCrm].[AccountAddresses]')
GO
ALTER TABLE [SCrm].[AccountAddresses] WITH NOCHECK
  ADD CONSTRAINT [FK_AccountAddresses_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
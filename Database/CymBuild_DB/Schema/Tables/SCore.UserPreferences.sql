PRINT (N'Create table [SCore].[UserPreferences]')
GO
CREATE TABLE [SCore].[UserPreferences] (
  [ID] [int] NOT NULL,
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_UserPreferences_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_MailerSettings_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [SystemLanguageID] [int] NOT NULL CONSTRAINT [DF_UserPreferences_SystemLanguageId] DEFAULT (-1),
  [WidgetLayout] [nvarchar](max) NOT NULL CONSTRAINT [DF_UserPreferences_WidgetLayout] DEFAULT ('{"ItemStates": []}'),
  [OutlookSettings] [nvarchar](max) NOT NULL CONSTRAINT [DF_UserPreferences_OutlookSettings] DEFAULT ('{}')
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_UserPreferences] on table [SCore].[UserPreferences]')
GO
ALTER TABLE [SCore].[UserPreferences] WITH NOCHECK
  ADD CONSTRAINT [PK_UserPreferences] PRIMARY KEY CLUSTERED ([ID])
GO

PRINT (N'Create unique key [UQ__UserPreferences_Guid] on table [SCore].[UserPreferences]')
GO
ALTER TABLE [SCore].[UserPreferences] WITH NOCHECK
  ADD CONSTRAINT [UQ__UserPreferences_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 90)
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_UserPreferences_RecordHistory] on table [SCore].[UserPreferences]')
GO
CREATE TRIGGER [SCore].[tg_UserPreferences_RecordHistory]
   ON  [SCore].[UserPreferences]	
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
			@TableName NVARCHAR(250) = N'UserPreferences',
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
		SELECT	TOP(1) @CurrentInsertedID = i.[ID]
		FROM	Inserted i
		WHERE	(i.[ID] > @CurrentInsertedID)
			ORDER BY i.[ID]

		SELECT	TOP(1) @CurrentInsertedGuid = i.Guid
		FROM	[SCore].[Identities] i
		WHERE	(ID =  @CurrentInsertedID)
		
		
		
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1386)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[SystemLanguageID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[SystemLanguageID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[SystemLanguageID] IS DISTINCT FROM i.[SystemLanguageID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'SystemLanguageID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1388)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_UserPreferences_Identities] on table [SCore].[UserPreferences]')
GO
ALTER TABLE [SCore].[UserPreferences] WITH NOCHECK
  ADD CONSTRAINT [FK_UserPreferences_Identities] FOREIGN KEY ([ID]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_UserPreferences_Languages] on table [SCore].[UserPreferences]')
GO
ALTER TABLE [SCore].[UserPreferences] WITH NOCHECK
  ADD CONSTRAINT [FK_UserPreferences_Languages] FOREIGN KEY ([SystemLanguageID]) REFERENCES [SCore].[Languages] ([ID])
GO

PRINT (N'Create foreign key [FK_UserPreferences_RowStatus] on table [SCore].[UserPreferences]')
GO
ALTER TABLE [SCore].[UserPreferences] WITH NOCHECK
  ADD CONSTRAINT [FK_UserPreferences_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
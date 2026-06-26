PRINT (N'Create table [SCore].[NonActivityEvents]')
GO
CREATE TABLE [SCore].[NonActivityEvents] (
  [ID] [int] IDENTITY,
  [StartTime] [datetime] NULL,
  [EndTime] [datetime] NULL,
  [MemberIdentityId] [int] NOT NULL CONSTRAINT [DF_NonActivityEvents_MemberId] DEFAULT (-1),
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF__NonActivit__Guid__75709C27] DEFAULT (newid()),
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF__NonActivi__RowSt__7664C060] DEFAULT (1),
  [RowVersion] [timestamp],
  [TeamGroupId] [int] NOT NULL CONSTRAINT [DF_NonActivityEvents_TeamId] DEFAULT (-1),
  [AbsenceTypeID] [int] NOT NULL CONSTRAINT [DF_NonActivityEvents_AbsenceTypeID] DEFAULT (-1)
)
ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_NonActivityEvents_RecordHistory] on table [SCore].[NonActivityEvents]')
GO
CREATE TRIGGER [SCore].[tg_NonActivityEvents_RecordHistory]
   ON  [SCore].[NonActivityEvents]	
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
			@TableName NVARCHAR(250) = N'NonActivityEvents',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[AbsenceTypeID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[AbsenceTypeID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[AbsenceTypeID] IS DISTINCT FROM i.[AbsenceTypeID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'AbsenceTypeID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2084)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[EndTime]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[EndTime]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[EndTime] IS DISTINCT FROM i.[EndTime])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'EndTime', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2086)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[MemberIdentityId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[MemberIdentityId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[MemberIdentityId] IS DISTINCT FROM i.[MemberIdentityId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'MemberIdentityId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2088)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2090)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[StartTime]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[StartTime]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[StartTime] IS DISTINCT FROM i.[StartTime])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'StartTime', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2085)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[TeamGroupId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[TeamGroupId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[TeamGroupId] IS DISTINCT FROM i.[TeamGroupId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'TeamGroupId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2087)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_NonActivityEvents_AbsenceTypes] on table [SCore].[NonActivityEvents]')
GO
ALTER TABLE [SCore].[NonActivityEvents] WITH NOCHECK
  ADD CONSTRAINT [FK_NonActivityEvents_AbsenceTypes] FOREIGN KEY ([AbsenceTypeID]) REFERENCES [SCore].[NonActivityTypes] ([ID])
GO

PRINT (N'Create foreign key [FK_NonActivityEvents_Groups] on table [SCore].[NonActivityEvents]')
GO
ALTER TABLE [SCore].[NonActivityEvents] WITH NOCHECK
  ADD CONSTRAINT [FK_NonActivityEvents_Groups] FOREIGN KEY ([TeamGroupId]) REFERENCES [SCore].[Groups] ([ID])
GO

PRINT (N'Create foreign key [FK_NonActivityEvents_Identities] on table [SCore].[NonActivityEvents]')
GO
ALTER TABLE [SCore].[NonActivityEvents] WITH NOCHECK
  ADD CONSTRAINT [FK_NonActivityEvents_Identities] FOREIGN KEY ([MemberIdentityId]) REFERENCES [SCore].[Identities] ([ID])
GO
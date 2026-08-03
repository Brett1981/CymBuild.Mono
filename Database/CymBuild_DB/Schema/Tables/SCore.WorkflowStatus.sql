PRINT (N'Create table [SCore].[WorkflowStatus]')
GO
PRINT (N'Create table [SCore].[WorkflowStatus]')
GO
PRINT (N'Create table [SCore].[WorkflowStatus]')
GO
CREATE TABLE [SCore].[WorkflowStatus] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF__WorkflowS__RowSt__36005452] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NULL CONSTRAINT [DF_WorkflowStatus_Guid] DEFAULT (newid()),
  [OrganisationalUnitId] [int] NOT NULL CONSTRAINT [DF_WorkflowStatus_OrganisationalUnitId] DEFAULT (-1),
  [Name] [nvarchar](100) NOT NULL CONSTRAINT [DF_WorkflowStatus_Name] DEFAULT (''),
  [Description] [nvarchar](400) NOT NULL CONSTRAINT [DF_WorkflowStatus_Description] DEFAULT (''),
  [ShowInEnquiries] [bit] NOT NULL CONSTRAINT [DF__WorkflowS__ShowI__3AC5096F] DEFAULT (0),
  [ShowInQuotes] [bit] NOT NULL CONSTRAINT [DF__WorkflowS__ShowI__3BB92DA8] DEFAULT (0),
  [ShowInJobs] [bit] NOT NULL CONSTRAINT [DF__WorkflowS__ShowI__3CAD51E1] DEFAULT (0),
  [Enabled] [bit] NOT NULL CONSTRAINT [DF__WorkflowS__Enabl__3DA1761A] DEFAULT (1),
  [IsPredefined] [bit] NOT NULL CONSTRAINT [DF__WorkflowS__IsPre__3E959A53] DEFAULT (0),
  [SortOrder] [int] NOT NULL CONSTRAINT [DF__WorkflowS__SortO__3F89BE8C] DEFAULT (0),
  [Colour] [nvarchar](7) NOT NULL CONSTRAINT [DF__WorkflowS__Colou__407DE2C5] DEFAULT ('#FFFFFF'),
  [Icon] [nvarchar](50) NULL,
  [SendNotification] [bit] NOT NULL CONSTRAINT [DF_WorkflowStatus_SendNotification] DEFAULT (0),
  [IsCompleteStatus] [bit] NOT NULL CONSTRAINT [DF_WorkflowStatus_IsCompleteStatus] DEFAULT (0),
  [IsCustomerWaitingStatus] [bit] NOT NULL CONSTRAINT [DF_WorkflowStatus_IsCustomerWaitingStatus] DEFAULT (0),
  [RequiresUsersAction] [bit] NOT NULL CONSTRAINT [DF_WorkflowStatus_RequiresUsersAction] DEFAULT (0),
  [IsActiveStatus] [bit] NOT NULL CONSTRAINT [DF_WorkflowStatus_IsActiveStatus] DEFAULT (0),
  [AuthorisationNeeded] [bit] NOT NULL CONSTRAINT [DF_WorkflowStatus_AuthorisationNeeded] DEFAULT (0),
  [IsAuthStatus] [bit] NOT NULL CONSTRAINT [DF_WorkflowStatus_IsAuthStatus] DEFAULT (0)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_SCore_WorkflowStatus] on table [SCore].[WorkflowStatus]')
GO
ALTER TABLE [SCore].[WorkflowStatus] WITH NOCHECK
  ADD CONSTRAINT [PK_SCore_WorkflowStatus] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key on table [SCore].[WorkflowStatus]')
GO
ALTER TABLE [SCore].[WorkflowStatus] WITH NOCHECK
  ADD UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_WorkflowStatus_Active_ID_Guid] on table [SCore].[WorkflowStatus]')
GO
CREATE INDEX [IX_WorkflowStatus_Active_ID_Guid]
  ON [SCore].[WorkflowStatus] ([ID])
  INCLUDE ([Guid])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_WorkflowStatus_Id_Guid] on table [SCore].[WorkflowStatus]')
GO
CREATE INDEX [IX_WorkflowStatus_Id_Guid]
  ON [SCore].[WorkflowStatus] ([ID])
  INCLUDE ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_WorkflowStatus_RecordHistory] on table [SCore].[WorkflowStatus]')
GO
CREATE TRIGGER [SCore].[tg_WorkflowStatus_RecordHistory]
   ON  [SCore].[WorkflowStatus]	
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
			@TableName NVARCHAR(250) = N'WorkflowStatus',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[AuthorisationNeeded]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[AuthorisationNeeded]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[AuthorisationNeeded] IS DISTINCT FROM i.[AuthorisationNeeded])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'AuthorisationNeeded', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2522)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Colour]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Colour]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Colour] IS DISTINCT FROM i.[Colour])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Colour', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2244)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Description]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Description]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Description] IS DISTINCT FROM i.[Description])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Description', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2249)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Enabled]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Enabled]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Enabled] IS DISTINCT FROM i.[Enabled])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Enabled', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2253)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Icon]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Icon]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Icon] IS DISTINCT FROM i.[Icon])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Icon', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2245)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[IsActiveStatus]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[IsActiveStatus]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[IsActiveStatus] IS DISTINCT FROM i.[IsActiveStatus])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsActiveStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2242)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[IsCompleteStatus]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[IsCompleteStatus]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[IsCompleteStatus] IS DISTINCT FROM i.[IsCompleteStatus])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsCompleteStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2247)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[IsCustomerWaitingStatus]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[IsCustomerWaitingStatus]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[IsCustomerWaitingStatus] IS DISTINCT FROM i.[IsCustomerWaitingStatus])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsCustomerWaitingStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2248)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[IsPredefined]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[IsPredefined]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[IsPredefined] IS DISTINCT FROM i.[IsPredefined])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsPredefined', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2254)
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
				VALUES(1, @SchemaName, @TableName, N'Name', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2240)
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
				VALUES(1, @SchemaName, @TableName, N'OrganisationalUnitId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2239)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RequiresUsersAction]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RequiresUsersAction]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RequiresUsersAction] IS DISTINCT FROM i.[RequiresUsersAction])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RequiresUsersAction', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2241)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2236)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[SendNotification]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[SendNotification]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[SendNotification] IS DISTINCT FROM i.[SendNotification])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'SendNotification', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2246)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ShowInEnquiries]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ShowInEnquiries]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ShowInEnquiries] IS DISTINCT FROM i.[ShowInEnquiries])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ShowInEnquiries', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2250)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ShowInJobs]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ShowInJobs]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ShowInJobs] IS DISTINCT FROM i.[ShowInJobs])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ShowInJobs', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2252)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ShowInQuotes]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ShowInQuotes]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ShowInQuotes] IS DISTINCT FROM i.[ShowInQuotes])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ShowInQuotes', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2251)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[SortOrder]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[SortOrder]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[SortOrder] IS DISTINCT FROM i.[SortOrder])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'SortOrder', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2243)
			END 
			
			
			END
		END
		
		
GO



SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO



SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_WorkflowStatus_Active_ID_Guid] on table [SCore].[WorkflowStatus]')
GO


PRINT (N'Create index [IX_WorkflowStatus_Id_Guid] on table [SCore].[WorkflowStatus]')
GO


SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_WorkflowStatus_RecordHistory] on table [SCore].[WorkflowStatus]')
GO



PRINT (N'Create index [IX_WorkflowStatus_Id_Guid] on table [SCore].[WorkflowStatus]')
GO


SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_WorkflowStatus_RecordHistory] on table [SCore].[WorkflowStatus]')
GO
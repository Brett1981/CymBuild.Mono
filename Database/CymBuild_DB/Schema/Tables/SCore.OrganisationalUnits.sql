SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create table [SCore].[OrganisationalUnits]')
GO
SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create table [SCore].[OrganisationalUnits]')
GO
CREATE TABLE [SCore].[OrganisationalUnits] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_OrganisationalUnits_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_OrganisationalUnits_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](250) NOT NULL CONSTRAINT [DF_OrganisationalUnits_Name] DEFAULT (''),
  [ParentID] [int] NOT NULL CONSTRAINT [DEFAULT_OrganisationalUnits_ParentID] DEFAULT (-1),
  [AddressId] [int] NOT NULL CONSTRAINT [DF_OrganisationalUnits_AddressId] DEFAULT (-1),
  [ContactId] [int] NOT NULL CONSTRAINT [DF_OrganisationalUnits_ContactId] DEFAULT (-1),
  [OfficialAddressId] [int] NOT NULL CONSTRAINT [DF_OrganisationalUnits_OfficialAddress] DEFAULT (-1),
  [OfficialContactId] [int] NOT NULL CONSTRAINT [DF_OrganisationalUnits_OfficialContactId] DEFAULT (-1),
  [OrgNode] [hierarchyid] NULL,
  [DepartmentPrefix] [nvarchar](10) NOT NULL CONSTRAINT [DF_OrganisationalUnits_DepartmentPrefix] DEFAULT (''),
  [CostCentreCode] [nvarchar](50) NOT NULL CONSTRAINT [DF_OrganisationalUnits_CostCentreCode] DEFAULT (''),
  [DefaultSecurityGroupId] [int] NOT NULL CONSTRAINT [DF_OrganisationalUnits_DefaultSecurityGroupId] DEFAULT (-1),
  [OrgLevel] AS ([OrgNode].[GetLevel]()),
  [IsCompany] AS (CONVERT([bit],case when [OrgNode].[GetLevel]()=(1) then (1) else (0) end)) PERSISTED,
  [IsDivision] AS (CONVERT([bit],case when [OrgNode].[GetLevel]()=(2) then (1) else (0) end)) PERSISTED,
  [IsBusinessUnit] AS (CONVERT([bit],case when [OrgNode].[GetLevel]()=(3) then (1) else (0) end)) PERSISTED,
  [IsDepartment] AS (CONVERT([bit],case when [OrgNode].[GetLevel]()=(4) then (1) else (0) end)) PERSISTED,
  [IsTeam] AS (CONVERT([bit],case when [OrgNode].[GetLevel]()=(5) then (1) else (0) end)) PERSISTED,
  [QuoteThreshold] [decimal](19, 2) NULL CONSTRAINT [DF_OrganisationalUnits_QuoteThreshold] DEFAULT (NULL)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_OrganisationalUnits] on table [SCore].[OrganisationalUnits]')
GO
ALTER TABLE [SCore].[OrganisationalUnits] WITH NOCHECK
  ADD CONSTRAINT [PK_OrganisationalUnits] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create index [IX_OrgUnits_OrgNode] on table [SCore].[OrganisationalUnits]')
GO
CREATE INDEX [IX_OrgUnits_OrgNode]
  ON [SCore].[OrganisationalUnits] ([OrgNode])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_OrganisationalUnits_Guid] on table [SCore].[OrganisationalUnits]')
GO
CREATE UNIQUE INDEX [IX_UQ_OrganisationalUnits_Guid]
  ON [SCore].[OrganisationalUnits] ([Guid])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_OrganisationalUnits_Name] on table [SCore].[OrganisationalUnits]')
GO
CREATE UNIQUE INDEX [IX_UQ_OrganisationalUnits_Name]
  ON [SCore].[OrganisationalUnits] ([Name])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [OrgUnitBFInd] on table [SCore].[OrganisationalUnits]')
GO
CREATE UNIQUE INDEX [OrgUnitBFInd]
  ON [SCore].[OrganisationalUnits] ([OrgLevel], [OrgNode])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_OrganisationalUnits_RecordHistory] on table [SCore].[OrganisationalUnits]')
GO
CREATE TRIGGER [SCore].[tg_OrganisationalUnits_RecordHistory]
   ON  [SCore].[OrganisationalUnits]	
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
			@TableName NVARCHAR(250) = N'OrganisationalUnits',
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
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[AddressId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[AddressId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[AddressId] IS DISTINCT FROM i.[AddressId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'AddressId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 859)
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
				VALUES(1, @SchemaName, @TableName, N'ContactId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 860)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[CostCentreCode]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[CostCentreCode]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[CostCentreCode] IS DISTINCT FROM i.[CostCentreCode])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'CostCentreCode', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1262)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[DefaultSecurityGroupId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[DefaultSecurityGroupId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[DefaultSecurityGroupId] IS DISTINCT FROM i.[DefaultSecurityGroupId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'DefaultSecurityGroupId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1562)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[DepartmentPrefix]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[DepartmentPrefix]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[DepartmentPrefix] IS DISTINCT FROM i.[DepartmentPrefix])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'DepartmentPrefix', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1177)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[IsBusinessUnit]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[IsBusinessUnit]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[IsBusinessUnit] IS DISTINCT FROM i.[IsBusinessUnit])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsBusinessUnit', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1263)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[IsDepartment]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[IsDepartment]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[IsDepartment] IS DISTINCT FROM i.[IsDepartment])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsDepartment', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1178)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[IsDivision]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[IsDivision]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[IsDivision] IS DISTINCT FROM i.[IsDivision])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsDivision', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1264)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[IsTeam]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[IsTeam]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[IsTeam] IS DISTINCT FROM i.[IsTeam])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsTeam', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1265)
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
				VALUES(1, @SchemaName, @TableName, N'Name', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 760)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[OfficialAddressId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[OfficialAddressId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[OfficialAddressId] IS DISTINCT FROM i.[OfficialAddressId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'OfficialAddressId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 861)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[OfficialContactId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[OfficialContactId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[OfficialContactId] IS DISTINCT FROM i.[OfficialContactId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'OfficialContactId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 862)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ParentID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ParentID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ParentID] IS DISTINCT FROM i.[ParentID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ParentID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 761)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[QuoteThreshold]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[QuoteThreshold]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[QuoteThreshold] IS DISTINCT FROM i.[QuoteThreshold])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'QuoteThreshold', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 2326)
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
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 762)
			END 
			
			
			END
		END
		
		
GO

PRINT (N'Create foreign key [FK_OrganisationalUnits_Groups] on table [SCore].[OrganisationalUnits]')
GO
ALTER TABLE [SCore].[OrganisationalUnits] WITH NOCHECK
  ADD CONSTRAINT [FK_OrganisationalUnits_Groups] FOREIGN KEY ([DefaultSecurityGroupId]) REFERENCES [SCore].[Groups] ([ID])
GO

PRINT (N'Create foreign key [FK_OrganisationalUnits_OrganisationalUnits] on table [SCore].[OrganisationalUnits]')
GO
ALTER TABLE [SCore].[OrganisationalUnits] WITH NOCHECK
  ADD CONSTRAINT [FK_OrganisationalUnits_OrganisationalUnits] FOREIGN KEY ([ParentID]) REFERENCES [SCore].[OrganisationalUnits] ([ID])
GO
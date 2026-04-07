SET QUOTED_IDENTIFIER ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET QUOTED_IDENTIFIER ON
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
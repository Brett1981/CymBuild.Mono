SET QUOTED_IDENTIFIER ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create table [SJob].[Assets]')
GO
CREATE TABLE [SJob].[Assets] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DEFAULT_Properties_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_Properties_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [AssetNumber] [int] NOT NULL CONSTRAINT [DEFAULT_Properties_UPRN] DEFAULT (0),
  [ParentAssetID] [int] NOT NULL CONSTRAINT [DEFAULT_Properties_ParentPropertyID] DEFAULT (-1),
  [CreatedDate] [datetime2] NOT NULL CONSTRAINT [DEFAULT_Properties_CreatedDate] DEFAULT (getutcdate()),
  [Name] [nvarchar](100) NOT NULL CONSTRAINT [DEFAULT_Properties_Name] DEFAULT (''),
  [Number] [nvarchar](50) NOT NULL CONSTRAINT [DEFAULT_Properties_Number] DEFAULT (''),
  [AddressLine1] [nvarchar](50) NOT NULL CONSTRAINT [DEFAULT_Properties_AddressLine1] DEFAULT (''),
  [AddressLine2] [nvarchar](50) NOT NULL CONSTRAINT [DEFAULT_Properties_AddressLine2] DEFAULT (''),
  [AddressLine3] [nvarchar](50) NOT NULL CONSTRAINT [DEFAULT_Properties_AddressLine3] DEFAULT (''),
  [Town] [nvarchar](50) NOT NULL CONSTRAINT [DEFAULT_Properties_Town] DEFAULT (''),
  [Postcode] [nvarchar](50) NOT NULL CONSTRAINT [DEFAULT_Properties_Postcode] DEFAULT (''),
  [LocalAuthorityAccountID] [int] NOT NULL CONSTRAINT [DEFAULT_Properties_LocalAuthorityAccountID] DEFAULT (-1),
  [FireAuthorityAccountID] [int] NOT NULL CONSTRAINT [DEFAULT_Properties_FireAuthorityAccountID] DEFAULT (-1),
  [WaterAuthorityAccountID] [int] NOT NULL CONSTRAINT [DEFAULT_Properties_WaterAuthorityAccountID] DEFAULT (-1),
  [FormattedAddressComma] [nvarchar](600) NOT NULL CONSTRAINT [DEFAULT_Properties_FormattedAddressComma] DEFAULT (''),
  [FormattedAddressCR] [nvarchar](600) NOT NULL CONSTRAINT [DEFAULT_Properties_FormattedAddressCR] DEFAULT (''),
  [Latitude] [decimal](9, 6) NOT NULL CONSTRAINT [DEFAULT_Properties_Latitude] DEFAULT (0),
  [Longitude] [decimal](9, 6) NOT NULL CONSTRAINT [DEFAULT_Properties_Longitude] DEFAULT (0),
  [IsHighRiskBuilding] [bit] NOT NULL CONSTRAINT [DF_Properties_IsHighRiskBuilding] DEFAULT (0),
  [IsComplexBuilding] [bit] NOT NULL CONSTRAINT [DF_Properties_IsComplexBuilding] DEFAULT (0),
  [BuildingHeightInMetres] [decimal](9, 2) NOT NULL CONSTRAINT [DF_Properties_BuildingHeightInMetres] DEFAULT (0),
  [CountyId] [int] NOT NULL CONSTRAINT [DF_Properties_CountyId] DEFAULT (-1),
  [CountryId] [int] NOT NULL CONSTRAINT [DF_Properties_CountryId] DEFAULT (-1),
  [ListLabel] AS ((CONVERT([nvarchar](100),[AssetNumber],(0))+N' - ')+[FormattedAddressComma]) PERSISTED,
  [OwnerAccountId] [int] NOT NULL CONSTRAINT [DF_Properties_OwnerAccountId] DEFAULT (-1),
  [LegacyID] [int] NULL,
  [LegacySystemID] [int] NOT NULL CONSTRAINT [DF__Propertie__Legac__1078CCC7] DEFAULT (-1),
  [GovernmentUPRN] [nvarchar](20) NOT NULL CONSTRAINT [DF_Assets_GovernmentUPRN] DEFAULT (N'')
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_Properties] on table [SJob].[Assets]')
GO
ALTER TABLE [SJob].[Assets] WITH NOCHECK
  ADD CONSTRAINT [PK_Properties] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Assets_List] on table [SJob].[Assets]')
GO
CREATE INDEX [IX_Assets_List]
  ON [SJob].[Assets] ([Guid], [AssetNumber], [RowStatus])
  INCLUDE ([ListLabel])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_UQ_Assets_AssetNumber] on table [SJob].[Assets]')
GO
CREATE UNIQUE INDEX [IX_UQ_Assets_AssetNumber]
  ON [SJob].[Assets] ([AssetNumber], [RowStatus])
  WHERE ([RowStatus]<>(0))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_Assets_Guid] on table [SJob].[Assets]')
GO
CREATE UNIQUE INDEX [IX_UQ_Assets_Guid]
  ON [SJob].[Assets] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_Properties_Accounts] on table [SJob].[Assets]')
GO
ALTER TABLE [SJob].[Assets] WITH NOCHECK
  ADD CONSTRAINT [FK_Properties_Accounts] FOREIGN KEY ([LocalAuthorityAccountID]) REFERENCES [SCrm].[Accounts] ([ID])
GO

PRINT (N'Create foreign key [FK_Properties_Accounts1] on table [SJob].[Assets]')
GO
ALTER TABLE [SJob].[Assets] WITH NOCHECK
  ADD CONSTRAINT [FK_Properties_Accounts1] FOREIGN KEY ([FireAuthorityAccountID]) REFERENCES [SCrm].[Accounts] ([ID])
GO

PRINT (N'Create foreign key [FK_Properties_Accounts2] on table [SJob].[Assets]')
GO
ALTER TABLE [SJob].[Assets] WITH NOCHECK
  ADD CONSTRAINT [FK_Properties_Accounts2] FOREIGN KEY ([WaterAuthorityAccountID]) REFERENCES [SCrm].[Accounts] ([ID])
GO

PRINT (N'Create foreign key [FK_Properties_Accounts3] on table [SJob].[Assets]')
GO
ALTER TABLE [SJob].[Assets] WITH NOCHECK
  ADD CONSTRAINT [FK_Properties_Accounts3] FOREIGN KEY ([OwnerAccountId]) REFERENCES [SCrm].[Accounts] ([ID])
GO

PRINT (N'Create foreign key [FK_Properties_Counties] on table [SJob].[Assets]')
GO
ALTER TABLE [SJob].[Assets] WITH NOCHECK
  ADD CONSTRAINT [FK_Properties_Counties] FOREIGN KEY ([CountyId]) REFERENCES [SCrm].[Counties] ([ID])
GO

PRINT (N'Create foreign key [FK_Properties_Countries] on table [SJob].[Assets]')
GO
ALTER TABLE [SJob].[Assets] WITH NOCHECK
  ADD CONSTRAINT [FK_Properties_Countries] FOREIGN KEY ([CountryId]) REFERENCES [SCrm].[Countries] ([ID])
GO

PRINT (N'Create foreign key [FK_Properties_DataObjects] on table [SJob].[Assets]')
GO
ALTER TABLE [SJob].[Assets] WITH NOCHECK
  ADD CONSTRAINT [FK_Properties_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_Properties_DataObjects] on table [SJob].[Assets]')
GO
ALTER TABLE [SJob].[Assets]
  NOCHECK CONSTRAINT [FK_Properties_DataObjects]
GO

PRINT (N'Create foreign key [FK_Properties_Properties] on table [SJob].[Assets]')
GO
ALTER TABLE [SJob].[Assets] WITH NOCHECK
  ADD CONSTRAINT [FK_Properties_Properties] FOREIGN KEY ([ParentAssetID]) REFERENCES [SJob].[Assets] ([ID])
GO

PRINT (N'Create foreign key [FK_Properties_RowStatus] on table [SJob].[Assets]')
GO
ALTER TABLE [SJob].[Assets] WITH NOCHECK
  ADD CONSTRAINT [FK_Properties_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
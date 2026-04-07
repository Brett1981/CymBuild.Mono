CREATE TABLE [SCrm].[Addresses] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Addresses_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_Addresses_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [AddressNumber] [int] NOT NULL CONSTRAINT [DF_Addresses_AddressNumber] DEFAULT (0),
  [Name] [nvarchar](100) NOT NULL CONSTRAINT [DF_Addresses_Name] DEFAULT (''),
  [Number] [nvarchar](50) NOT NULL CONSTRAINT [DF_Addresses_Number] DEFAULT (''),
  [AddressLine1] [nvarchar](255) NOT NULL CONSTRAINT [DF_Addresses_AddressLine1] DEFAULT (''),
  [AddressLine2] [nvarchar](255) NOT NULL CONSTRAINT [DF_Addresses_AddressLine2] DEFAULT (''),
  [AddressLine3] [nvarchar](255) NOT NULL CONSTRAINT [DF_Addresses_AddressLine3] DEFAULT (''),
  [Town] [nvarchar](255) NOT NULL CONSTRAINT [DF_Addresses_Town] DEFAULT (''),
  [CountyID] [int] NOT NULL CONSTRAINT [DF_Addresses_CountyID] DEFAULT (-1),
  [Postcode] [nvarchar](50) NOT NULL CONSTRAINT [DF_Addresses_Postcode] DEFAULT (''),
  [CountryID] [int] NOT NULL CONSTRAINT [DF_Addresses_CountryID] DEFAULT (-1),
  [LegacyID] [int] NULL,
  [FormattedAddressCR] [nvarchar](600) NOT NULL CONSTRAINT [DF_Addresses_FormattedAddressCR] DEFAULT (''),
  [FormattedAddressComma] [nvarchar](600) NOT NULL CONSTRAINT [DF_Addresses_FormattedAddressComma] DEFAULT (''),
  [LegacySystemID] [int] NOT NULL DEFAULT (-1),
  CONSTRAINT [PK__Addresse__3214EC2799120222] PRIMARY KEY CLUSTERED ([ID])
)
ON [PRIMARY]
GO

CREATE INDEX [IX_Addresses_DDL]
  ON [SCrm].[Addresses] ([FormattedAddressComma], [RowStatus])
  INCLUDE ([Guid])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_Addresses_Guid]
  ON [SCrm].[Addresses] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

ALTER TABLE [SCrm].[Addresses]
  ADD CONSTRAINT [FK_Addresses_Counties] FOREIGN KEY ([CountyID]) REFERENCES [SCrm].[Counties] ([ID])
GO

ALTER TABLE [SCrm].[Addresses]
  ADD CONSTRAINT [FK_Addresses_Countries] FOREIGN KEY ([CountryID]) REFERENCES [SCrm].[Countries] ([ID])
GO

ALTER TABLE [SCrm].[Addresses] WITH NOCHECK
  ADD CONSTRAINT [FK_Addresses_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid]) ON DELETE CASCADE
GO

ALTER TABLE [SCrm].[Addresses]
  NOCHECK CONSTRAINT [FK_Addresses_DataObjects]
GO

ALTER TABLE [SCrm].[Addresses]
  ADD CONSTRAINT [FK_Addresses_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
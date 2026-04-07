CREATE TABLE [SSop].[QuoteTemplates] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_QuoteTemplates_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_QuoteTemplates_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [OrganisationalUnitID] [int] NOT NULL CONSTRAINT [DF_QuoteTemplates_OrganisationalUnitID] DEFAULT (-1),
  [Number] [int] NOT NULL CONSTRAINT [DF_QuoteTemplates_Number] DEFAULT (0),
  [Overview] [nvarchar](max) NOT NULL CONSTRAINT [DF_QuoteTemplates_Overview] DEFAULT (''),
  [FeeCap] [decimal](9, 2) NOT NULL CONSTRAINT [DF_QuoteTemplates_FeeCap] DEFAULT (0),
  [ContractId] [int] NOT NULL DEFAULT (-1),
  [ContractBandId] [int] NOT NULL DEFAULT (-1),
  CONSTRAINT [PK_QuoteTemplates] PRIMARY KEY CLUSTERED ([ID])
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

ALTER TABLE [SSop].[QuoteTemplates] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteTemplates_ContractBandId] FOREIGN KEY ([ContractBandId]) REFERENCES [SSop].[ContractBands] ([ID])
GO

ALTER TABLE [SSop].[QuoteTemplates]
  ADD CONSTRAINT [FK_QuoteTemplates_ContractId] FOREIGN KEY ([ContractId]) REFERENCES [SSop].[Contracts] ([ID])
GO

ALTER TABLE [SSop].[QuoteTemplates] WITH NOCHECK
  ADD CONSTRAINT [FK_QuoteTemplates_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SSop].[QuoteTemplates]
  NOCHECK CONSTRAINT [FK_QuoteTemplates_DataObjects]
GO

ALTER TABLE [SSop].[QuoteTemplates]
  ADD CONSTRAINT [FK_QuoteTemplates_OrganisationalUnits] FOREIGN KEY ([OrganisationalUnitID]) REFERENCES [SCore].[OrganisationalUnits] ([ID])
GO

ALTER TABLE [SSop].[QuoteTemplates]
  ADD CONSTRAINT [FK_QuoteTemplates_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
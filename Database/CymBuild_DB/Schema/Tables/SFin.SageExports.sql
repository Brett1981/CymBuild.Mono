CREATE TABLE [SFin].[SageExports] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DEFAULT_TransactionExportsToSage_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_TransactionExportsToSage_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [ExportData] [nvarchar](max) NOT NULL CONSTRAINT [DF_TransactionExportsToSage_ExportData] DEFAULT (''),
  [InclusiveToDate] [date] NOT NULL CONSTRAINT [DF_TransactionExportsToSage_InclusiveToDate] DEFAULT (getdate()),
  [OrganisationalUnitId] [int] NOT NULL CONSTRAINT [DF_SageExports_OrganisationalUnitId] DEFAULT (-1),
  CONSTRAINT [PK_TransactionExportsToSage] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_SageExports_Guid]
  ON [SFin].[SageExports] ([Guid])
  ON [PRIMARY]
GO

ALTER TABLE [SFin].[SageExports] WITH NOCHECK
  ADD CONSTRAINT [FK_SageExports_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SFin].[SageExports]
  NOCHECK CONSTRAINT [FK_SageExports_DataObjects]
GO

ALTER TABLE [SFin].[SageExports]
  ADD CONSTRAINT [FK_SageExports_OrganisationalUnits] FOREIGN KEY ([OrganisationalUnitId]) REFERENCES [SCore].[OrganisationalUnits] ([ID])
GO

ALTER TABLE [SFin].[SageExports]
  ADD CONSTRAINT [FK_SageExports_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

ALTER TABLE [SFin].[SageExports]
  ADD CONSTRAINT [FK_TransactionExportsToSage_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
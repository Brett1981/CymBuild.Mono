PRINT (N'Create table [SFin].[VatCodes]')
GO
CREATE TABLE [SFin].[VatCodes] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_SFin_VatCodes_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_SFin_VatCodes_Guid] DEFAULT (newid()),
  [SageVatNo] [nvarchar](20) NOT NULL,
  [Description] [nvarchar](200) NOT NULL CONSTRAINT [DF_SFin_VatCodes_Description] DEFAULT (N''),
  [VatPercentage] [decimal](9, 4) NOT NULL CONSTRAINT [DF_SFin_VatCodes_VatPercentage] DEFAULT (0),
  [EffectiveFromDate] [date] NOT NULL CONSTRAINT [DF_SFin_VatCodes_EffectiveFromDate] DEFAULT (CONVERT([date],getdate())),
  [Active] [bit] NOT NULL CONSTRAINT [DF_SFin_VatCodes_Active] DEFAULT (1)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_SFin_VatCodes] on table [SFin].[VatCodes]')
GO
ALTER TABLE [SFin].[VatCodes] WITH NOCHECK
  ADD CONSTRAINT [PK_SFin_VatCodes] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_SFin_VatCodes_Guid] on table [SFin].[VatCodes]')
GO
ALTER TABLE [SFin].[VatCodes] WITH NOCHECK
  ADD CONSTRAINT [UQ_SFin_VatCodes_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create index [IX_SFin_VatCodes_VatPercentage_EffectiveFromDate] on table [SFin].[VatCodes]')
GO
CREATE INDEX [IX_SFin_VatCodes_VatPercentage_EffectiveFromDate]
  ON [SFin].[VatCodes] ([VatPercentage], [EffectiveFromDate] DESC)
  INCLUDE ([SageVatNo], [Description], [Active], [Guid], [RowStatus])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_SFin_VatCodes_DataObjects] on table [SFin].[VatCodes]')
GO
ALTER TABLE [SFin].[VatCodes] WITH NOCHECK
  ADD CONSTRAINT [FK_SFin_VatCodes_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid]) ON DELETE CASCADE
GO

PRINT (N'Disable foreign key [FK_SFin_VatCodes_DataObjects] on table [SFin].[VatCodes]')
GO
ALTER TABLE [SFin].[VatCodes]
  NOCHECK CONSTRAINT [FK_SFin_VatCodes_DataObjects]
GO

PRINT (N'Create foreign key [FK_SFin_VatCodes_RowStatus] on table [SFin].[VatCodes]')
GO
ALTER TABLE [SFin].[VatCodes] WITH NOCHECK
  ADD CONSTRAINT [FK_SFin_VatCodes_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
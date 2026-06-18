PRINT (N'Create table [SOffice].[OutlookEmailFromAddresses]')
GO
CREATE TABLE [SOffice].[OutlookEmailFromAddresses] (
  [ID] [int] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_OutlookEmailFromAddresses_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_OutlookEmailFromAddresses_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Address] [nvarchar](500) NOT NULL CONSTRAINT [DF_OutlookEmailFromAddresses_Address] DEFAULT ('')
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_OutlookEmailFromAddresses] on table [SOffice].[OutlookEmailFromAddresses]')
GO
ALTER TABLE [SOffice].[OutlookEmailFromAddresses] WITH NOCHECK
  ADD CONSTRAINT [PK_OutlookEmailFromAddresses] PRIMARY KEY CLUSTERED ([ID])
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_UQ_OutlookEmailFromAddresses_Address] on table [SOffice].[OutlookEmailFromAddresses]')
GO
CREATE UNIQUE INDEX [IX_UQ_OutlookEmailFromAddresses_Address]
  ON [SOffice].[OutlookEmailFromAddresses] ([Address], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_OutlookEmailFromAddresses_RowStatus] on table [SOffice].[OutlookEmailFromAddresses]')
GO
ALTER TABLE [SOffice].[OutlookEmailFromAddresses] WITH NOCHECK
  ADD CONSTRAINT [FK_OutlookEmailFromAddresses_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
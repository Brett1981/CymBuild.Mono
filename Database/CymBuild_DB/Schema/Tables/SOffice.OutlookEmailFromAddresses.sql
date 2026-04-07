CREATE TABLE [SOffice].[OutlookEmailFromAddresses] (
  [ID] [int] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_OutlookEmailFromAddresses_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_OutlookEmailFromAddresses_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Address] [nvarchar](500) NOT NULL CONSTRAINT [DF_OutlookEmailFromAddresses_Address] DEFAULT (''),
  CONSTRAINT [PK_OutlookEmailFromAddresses] PRIMARY KEY CLUSTERED ([ID])
)
ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_OutlookEmailFromAddresses_Address]
  ON [SOffice].[OutlookEmailFromAddresses] ([Address], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

ALTER TABLE [SOffice].[OutlookEmailFromAddresses]
  ADD CONSTRAINT [FK_OutlookEmailFromAddresses_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
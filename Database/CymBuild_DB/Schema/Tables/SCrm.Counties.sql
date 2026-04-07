CREATE TABLE [SCrm].[Counties] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Counties_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_Counties_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](100) NOT NULL CONSTRAINT [DF_Counties_Name] DEFAULT (''),
  [CountryID] [int] NOT NULL CONSTRAINT [DF_Counties_CountryID] DEFAULT (-1),
  PRIMARY KEY CLUSTERED ([ID])
)
ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_Counties]
  ON [SCrm].[Counties] ([Name], [CountryID])
  WHERE ([RowStatus]=(1))
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

CREATE INDEX [IX_UQ_Counties__Country_Name]
  ON [SCrm].[Counties] ([Name], [CountryID], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

ALTER TABLE [SCrm].[Counties]
  ADD CONSTRAINT [FK_Counties_Countries] FOREIGN KEY ([CountryID]) REFERENCES [SCrm].[Countries] ([ID])
GO

ALTER TABLE [SCrm].[Counties] WITH NOCHECK
  ADD CONSTRAINT [FK_Counties_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SCrm].[Counties]
  NOCHECK CONSTRAINT [FK_Counties_DataObjects]
GO

ALTER TABLE [SCrm].[Counties]
  ADD CONSTRAINT [FK_Counties_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
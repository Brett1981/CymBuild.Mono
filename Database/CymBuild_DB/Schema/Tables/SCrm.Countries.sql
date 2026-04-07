CREATE TABLE [SCrm].[Countries] (
  [ID] [int] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_Countries_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Countries_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Name] [nvarchar](100) NOT NULL CONSTRAINT [DF_Countries_Name] DEFAULT (''),
  PRIMARY KEY CLUSTERED ([ID])
)
ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_Countires_Guid]
  ON [SCrm].[Countries] ([Guid])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_Countries_Name]
  ON [SCrm].[Countries] ([Name], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

ALTER TABLE [SCrm].[Countries] WITH NOCHECK
  ADD CONSTRAINT [FK_Countries_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SCrm].[Countries]
  NOCHECK CONSTRAINT [FK_Countries_DataObjects]
GO

ALTER TABLE [SCrm].[Countries]
  ADD CONSTRAINT [FK_Countries_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
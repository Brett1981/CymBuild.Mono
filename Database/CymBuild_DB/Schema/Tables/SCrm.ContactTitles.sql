CREATE TABLE [SCrm].[ContactTitles] (
  [ID] [smallint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_ContactTitles_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_ContactTitles_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](100) NOT NULL CONSTRAINT [DF_ContactTitles_Name] DEFAULT (N''),
  CONSTRAINT [PK_ContactTitles] PRIMARY KEY CLUSTERED ([ID])
)
ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_ContactTitle_Guid]
  ON [SCrm].[ContactTitles] ([Guid])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

ALTER TABLE [SCrm].[ContactTitles] WITH NOCHECK
  ADD CONSTRAINT [FK_ContactTitles_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SCrm].[ContactTitles]
  NOCHECK CONSTRAINT [FK_ContactTitles_DataObjects]
GO

ALTER TABLE [SCrm].[ContactTitles]
  ADD CONSTRAINT [FK_ContactTitles_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
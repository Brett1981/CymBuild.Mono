CREATE TABLE [SCrm].[ContactPositions] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_ContactPositions_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_ContactPositions_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](100) NOT NULL CONSTRAINT [DF_ContactPositions_Name] DEFAULT (N''),
  CONSTRAINT [PK_ContactPositions] PRIMARY KEY CLUSTERED ([ID])
)
ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_ContactPositions]
  ON [SCrm].[ContactPositions] ([Guid])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

ALTER TABLE [SCrm].[ContactPositions] WITH NOCHECK
  ADD CONSTRAINT [FK_ContactPositions_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SCrm].[ContactPositions]
  NOCHECK CONSTRAINT [FK_ContactPositions_DataObjects]
GO

ALTER TABLE [SCrm].[ContactPositions]
  ADD CONSTRAINT [FK_ContactPositions_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
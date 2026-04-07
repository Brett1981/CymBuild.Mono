CREATE TABLE [SCrm].[ContactDetailTypes] (
  [ID] [smallint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_ContactDetailTypes_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_ContactDetailTypes_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](100) NOT NULL CONSTRAINT [DF_ContactDetailTypes_Name] DEFAULT (N''),
  CONSTRAINT [PK_ContactDetailTypes] PRIMARY KEY CLUSTERED ([ID])
)
ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_ContactDetailTypes_Guid]
  ON [SCrm].[ContactDetailTypes] ([Guid])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_ContactDetailTypes_Name]
  ON [SCrm].[ContactDetailTypes] ([Name])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

ALTER TABLE [SCrm].[ContactDetailTypes] WITH NOCHECK
  ADD CONSTRAINT [FK_ContactDetailTypes_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SCrm].[ContactDetailTypes]
  NOCHECK CONSTRAINT [FK_ContactDetailTypes_DataObjects]
GO

ALTER TABLE [SCrm].[ContactDetailTypes]
  ADD CONSTRAINT [FK_ContactDetailTypes_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
CREATE TABLE [SCore].[SharepointSites] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_SharepointSites_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_SharepointSites_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](50) NOT NULL CONSTRAINT [DF_SharepointSites_Name] DEFAULT (''),
  [SiteIdentifier] [nvarchar](250) NOT NULL CONSTRAINT [DF_SharepointSites_SiteIdentifier] DEFAULT (''),
  [SiteUrl] [nvarchar](250) NOT NULL CONSTRAINT [DF_SharepointSites_SiteUrl] DEFAULT (''),
  CONSTRAINT [PK_SharepointSites] PRIMARY KEY CLUSTERED ([ID])
)
ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_SharePointSites_Guid]
  ON [SCore].[SharepointSites] ([Guid])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_SharePointSites_SiteIdentifier]
  ON [SCore].[SharepointSites] ([SiteIdentifier])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

ALTER TABLE [SCore].[SharepointSites]
  ADD CONSTRAINT [FK_SharepointSites_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
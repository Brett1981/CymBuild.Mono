CREATE TABLE [SCore].[Versioning] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Versioning_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_Versioning_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Version] [nvarchar](10) NOT NULL CONSTRAINT [DF_Versioning_Version] DEFAULT (''),
  [Description] [nvarchar](100) NOT NULL CONSTRAINT [DF_Versioning_Name] DEFAULT (''),
  [IsCurrent] [bit] NOT NULL CONSTRAINT [DF_Versioning_Current] DEFAULT (0),
  CONSTRAINT [PK_Versioning] PRIMARY KEY CLUSTERED ([ID]) ON [METADATA]
)
ON [METADATA]
GO

CREATE UNIQUE INDEX [IX_Versioning_IsCurrent]
  ON [SCore].[Versioning] ([IsCurrent])
  WHERE ([IsCurrent]=(1))
  ON [PRIMARY]
GO

ALTER TABLE [SCore].[Versioning]
  ADD CONSTRAINT [FK_Versioning_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
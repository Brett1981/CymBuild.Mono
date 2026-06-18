PRINT (N'Create table [SCore].[Versioning]')
GO
CREATE TABLE [SCore].[Versioning] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Versioning_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_Versioning_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Version] [nvarchar](10) NOT NULL CONSTRAINT [DF_Versioning_Version] DEFAULT (''),
  [Description] [nvarchar](100) NOT NULL CONSTRAINT [DF_Versioning_Name] DEFAULT (''),
  [IsCurrent] [bit] NOT NULL CONSTRAINT [DF_Versioning_Current] DEFAULT (0)
)
ON [METADATA]
GO

PRINT (N'Create primary key [PK_Versioning] on table [SCore].[Versioning]')
GO
ALTER TABLE [SCore].[Versioning] WITH NOCHECK
  ADD CONSTRAINT [PK_Versioning] PRIMARY KEY CLUSTERED ([ID]) ON [METADATA]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Versioning_IsCurrent] on table [SCore].[Versioning]')
GO
CREATE UNIQUE INDEX [IX_Versioning_IsCurrent]
  ON [SCore].[Versioning] ([IsCurrent])
  WHERE ([IsCurrent]=(1))
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_Versioning_RowStatus] on table [SCore].[Versioning]')
GO
ALTER TABLE [SCore].[Versioning] WITH NOCHECK
  ADD CONSTRAINT [FK_Versioning_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
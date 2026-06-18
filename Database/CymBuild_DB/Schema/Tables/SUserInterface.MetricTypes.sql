PRINT (N'Create table [SUserInterface].[MetricTypes]')
GO
CREATE TABLE [SUserInterface].[MetricTypes] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_MetricTypes_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_MetricTypes_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](50) NOT NULL CONSTRAINT [DF_MetricTypes_Name] DEFAULT ('')
)
ON [METADATA]
GO

PRINT (N'Create primary key [PK_MetricTypes] on table [SUserInterface].[MetricTypes]')
GO
ALTER TABLE [SUserInterface].[MetricTypes] WITH NOCHECK
  ADD CONSTRAINT [PK_MetricTypes] PRIMARY KEY CLUSTERED ([ID]) ON [METADATA]
GO

PRINT (N'Create index [IX_UQ_MetricTypes_Guid] on table [SUserInterface].[MetricTypes]')
GO
CREATE UNIQUE INDEX [IX_UQ_MetricTypes_Guid]
  ON [SUserInterface].[MetricTypes] ([Guid])
  WITH (FILLFACTOR = 100)
  ON [METADATA]
GO

PRINT (N'Create index [IX_UQ_MetricTypes_Name] on table [SUserInterface].[MetricTypes]')
GO
CREATE UNIQUE INDEX [IX_UQ_MetricTypes_Name]
  ON [SUserInterface].[MetricTypes] ([Name])
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_MetricTypes_RowStatus] on table [SUserInterface].[MetricTypes]')
GO
ALTER TABLE [SUserInterface].[MetricTypes] WITH NOCHECK
  ADD CONSTRAINT [FK_MetricTypes_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
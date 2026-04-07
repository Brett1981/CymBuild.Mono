CREATE TABLE [SUserInterface].[MetricTypes] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_MetricTypes_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_MetricTypes_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](50) NOT NULL CONSTRAINT [DF_MetricTypes_Name] DEFAULT (''),
  CONSTRAINT [PK_MetricTypes] PRIMARY KEY CLUSTERED ([ID]) ON [METADATA]
)
ON [METADATA]
GO

CREATE UNIQUE INDEX [IX_UQ_MetricTypes_Guid]
  ON [SUserInterface].[MetricTypes] ([Guid])
  WITH (FILLFACTOR = 100)
  ON [METADATA]
GO

CREATE UNIQUE INDEX [IX_UQ_MetricTypes_Name]
  ON [SUserInterface].[MetricTypes] ([Name])
  ON [PRIMARY]
GO

ALTER TABLE [SUserInterface].[MetricTypes]
  ADD CONSTRAINT [FK_MetricTypes_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

EXEC sys.sp_addextendedproperty N'MS_Description', N'The types of gauges that can be shown on the dashboard.', 'SCHEMA', N'SUserInterface', 'TABLE', N'MetricTypes'
GO
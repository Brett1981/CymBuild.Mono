CREATE TABLE [SUserInterface].[Icons] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DC_Icons_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DC_Icons_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](50) NOT NULL CONSTRAINT [DC_Icons_Name] DEFAULT (''),
  CONSTRAINT [PK_Icons_ID] PRIMARY KEY CLUSTERED ([ID]) ON [METADATA],
  CONSTRAINT [UK_Icons_Guid] UNIQUE ([Guid]) ON [METADATA]
)
ON [METADATA]
GO

CREATE UNIQUE INDEX [IX_UQ_MetricTypes_Name]
  ON [SUserInterface].[Icons] ([Name])
  ON [PRIMARY]
GO

ALTER TABLE [SUserInterface].[Icons]
  ADD CONSTRAINT [FK_Icons_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

EXEC sys.sp_addextendedproperty N'MS_Description', N'The types of gauges that can be shown on the dashboard.', 'SCHEMA', N'SUserInterface', 'TABLE', N'Icons'
GO
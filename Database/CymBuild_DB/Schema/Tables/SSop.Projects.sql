CREATE TABLE [SSop].[Projects] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Projects_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_Projects_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Number] [int] NOT NULL CONSTRAINT [DF_Projects_Number] DEFAULT (0),
  [ExternalReference] [nvarchar](50) NOT NULL CONSTRAINT [DF_Projects_ExternalReference] DEFAULT (''),
  [ProjectDescription] [nvarchar](max) NOT NULL CONSTRAINT [DF_Projects_ProjectDescription] DEFAULT (''),
  [ProjectProjectsStartDate] [date] NULL,
  [ProjectProjectedEndDate] [date] NULL,
  [ProjectCompleted] [date] NULL,
  [IsSubjectToNDA] [bit] NOT NULL CONSTRAINT [DF_Projects_IsSubjectToNDA] DEFAULT (0),
  CONSTRAINT [PK_Projects] PRIMARY KEY CLUSTERED ([ID])
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_Projects_Number]
  ON [SSop].[Projects] ([Number], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UX_Projects_Guid]
  ON [SSop].[Projects] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

ALTER TABLE [SSop].[Projects] WITH NOCHECK
  ADD CONSTRAINT [FK_Projects_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid]) ON DELETE CASCADE
GO

ALTER TABLE [SSop].[Projects]
  NOCHECK CONSTRAINT [FK_Projects_DataObjects]
GO

ALTER TABLE [SSop].[Projects]
  ADD CONSTRAINT [FK_Projects_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
CREATE TABLE [SCrm].[AccountStatus] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_AccountStatus_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_AccountStatus_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](100) NOT NULL CONSTRAINT [DF_AccountStatus_Name] DEFAULT (N''),
  [IsHold] [bit] NOT NULL CONSTRAINT [DEFAULT_AccountStatus_IsHold] DEFAULT (0),
  [IsLive] [bit] NOT NULL CONSTRAINT [DF_AccountStatus_IsLive] DEFAULT (0),
  CONSTRAINT [PK_AccountStatus] PRIMARY KEY CLUSTERED ([ID])
)
ON [PRIMARY]
GO

CREATE INDEX [IX_AccountStatus_IsLive]
  ON [SCrm].[AccountStatus] ([IsLive])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_AccountStatus_Guid]
  ON [SCrm].[AccountStatus] ([Guid])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_AccountStatus_Name]
  ON [SCrm].[AccountStatus] ([Name], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

ALTER TABLE [SCrm].[AccountStatus] WITH NOCHECK
  ADD CONSTRAINT [FK_AccountStatus_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SCrm].[AccountStatus]
  NOCHECK CONSTRAINT [FK_AccountStatus_DataObjects]
GO

ALTER TABLE [SCrm].[AccountStatus]
  ADD CONSTRAINT [FK_AccountStatus_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
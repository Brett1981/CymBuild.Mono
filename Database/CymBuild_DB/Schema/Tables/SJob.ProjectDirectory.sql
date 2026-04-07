CREATE TABLE [SJob].[ProjectDirectory] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_ProjectDirectory_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_ProjectDirectory_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [JobID] [int] NOT NULL CONSTRAINT [DF_ProjectDirectory_JobId] DEFAULT (-1),
  [ProjectID] [int] NOT NULL CONSTRAINT [DF_ProjectDirectory_ProjectID] DEFAULT (-1),
  [ProjectDirectoryRoleID] [int] NOT NULL CONSTRAINT [DF_ProjectDirectory_ProjectDirectoryRoleID] DEFAULT (-1),
  [AccountID] [int] NOT NULL CONSTRAINT [DF_ProjectDirectory_AccountId] DEFAULT (-1),
  [ContactID] [int] NOT NULL CONSTRAINT [DF_ProjectDirectory_ContactId] DEFAULT (-1),
  CONSTRAINT [PK_ProjectDirectory] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
)
ON [PRIMARY]
GO

CREATE INDEX [IX_ProjectDirectory_Job]
  ON [SJob].[ProjectDirectory] ([JobID])
  INCLUDE ([ProjectDirectoryRoleID])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_ProjectDirectory_Guid]
  ON [SJob].[ProjectDirectory] ([Guid])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

ALTER TABLE [SJob].[ProjectDirectory]
  ADD CONSTRAINT [FK_ProjectDirectory_Accounts] FOREIGN KEY ([AccountID]) REFERENCES [SCrm].[Accounts] ([ID])
GO

ALTER TABLE [SJob].[ProjectDirectory]
  ADD CONSTRAINT [FK_ProjectDirectory_Contacts] FOREIGN KEY ([ContactID]) REFERENCES [SCrm].[Contacts] ([ID])
GO

ALTER TABLE [SJob].[ProjectDirectory] WITH NOCHECK
  ADD CONSTRAINT [FK_ProjectDirectory_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SJob].[ProjectDirectory]
  NOCHECK CONSTRAINT [FK_ProjectDirectory_DataObjects]
GO

ALTER TABLE [SJob].[ProjectDirectory]
  ADD CONSTRAINT [FK_ProjectDirectory_Jobs] FOREIGN KEY ([JobID]) REFERENCES [SJob].[Jobs] ([ID]) ON DELETE CASCADE
GO

ALTER TABLE [SJob].[ProjectDirectory]
  ADD CONSTRAINT [FK_ProjectDirectory_ProjectDirectoryRoles] FOREIGN KEY ([ProjectDirectoryRoleID]) REFERENCES [SJob].[ProjectDirectoryRoles] ([ID])
GO

ALTER TABLE [SJob].[ProjectDirectory]
  ADD CONSTRAINT [FK_ProjectDirectory_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
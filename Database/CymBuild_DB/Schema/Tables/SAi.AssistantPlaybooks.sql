PRINT (N'Create table [SAi].[AssistantPlaybooks]')
GO
CREATE TABLE [SAi].[AssistantPlaybooks] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL,
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL ROWGUIDCOL,
  [UserId] [int] NULL,
  [Title] [nvarchar](250) NOT NULL,
  [Summary] [nvarchar](1000) NULL,
  [PlaybookTypeCode] [nvarchar](30) NOT NULL,
  [VisibilityCode] [nvarchar](20) NOT NULL,
  [SourceConversationId] [int] NULL,
  [SourceWorkflowRunId] [int] NULL,
  [CreatedByUserId] [int] NOT NULL,
  [CreatedUtc] [datetime2] NOT NULL,
  [UpdatedUtc] [datetime2] NULL,
  [IsFeatured] [bit] NOT NULL CONSTRAINT [DF_AssistantPlaybooks_IsFeatured] DEFAULT (0)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_AssistantPlaybooks] on table [SAi].[AssistantPlaybooks]')
GO
ALTER TABLE [SAi].[AssistantPlaybooks] WITH NOCHECK
  ADD CONSTRAINT [PK_AssistantPlaybooks] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_AssistantPlaybooks_Guid] on table [SAi].[AssistantPlaybooks]')
GO
ALTER TABLE [SAi].[AssistantPlaybooks] WITH NOCHECK
  ADD CONSTRAINT [UQ_AssistantPlaybooks_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create index [IX_AssistantPlaybooks_User_UpdatedUtc] on table [SAi].[AssistantPlaybooks]')
GO
CREATE INDEX [IX_AssistantPlaybooks_User_UpdatedUtc]
  ON [SAi].[AssistantPlaybooks] ([UserId], [UpdatedUtc] DESC)
  INCLUDE ([Title], [VisibilityCode], [IsFeatured], [PlaybookTypeCode])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_AssistantPlaybooks_DataObjects] on table [SAi].[AssistantPlaybooks]')
GO
ALTER TABLE [SAi].[AssistantPlaybooks] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantPlaybooks_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_AssistantPlaybooks_DataObjects] on table [SAi].[AssistantPlaybooks]')
GO
ALTER TABLE [SAi].[AssistantPlaybooks]
  NOCHECK CONSTRAINT [FK_AssistantPlaybooks_DataObjects]
GO

PRINT (N'Create foreign key [FK_AssistantPlaybooks_Identities_CreatedBy] on table [SAi].[AssistantPlaybooks]')
GO
ALTER TABLE [SAi].[AssistantPlaybooks] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantPlaybooks_Identities_CreatedBy] FOREIGN KEY ([CreatedByUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_AssistantPlaybooks_Identities_User] on table [SAi].[AssistantPlaybooks]')
GO
ALTER TABLE [SAi].[AssistantPlaybooks] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantPlaybooks_Identities_User] FOREIGN KEY ([UserId]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_AssistantPlaybooks_RowStatus] on table [SAi].[AssistantPlaybooks]')
GO
ALTER TABLE [SAi].[AssistantPlaybooks] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantPlaybooks_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_AssistantPlaybooks_SourceConversation] on table [SAi].[AssistantPlaybooks]')
GO
ALTER TABLE [SAi].[AssistantPlaybooks] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantPlaybooks_SourceConversation] FOREIGN KEY ([SourceConversationId]) REFERENCES [SAi].[AssistantConversations] ([ID])
GO

PRINT (N'Create foreign key [FK_AssistantPlaybooks_SourceWorkflowRun] on table [SAi].[AssistantPlaybooks]')
GO
ALTER TABLE [SAi].[AssistantPlaybooks] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantPlaybooks_SourceWorkflowRun] FOREIGN KEY ([SourceWorkflowRunId]) REFERENCES [SAi].[AssistantWorkflowRuns] ([ID])
GO
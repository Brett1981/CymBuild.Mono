PRINT (N'Create table [SAi].[AssistantPlaybookSteps]')
GO
CREATE TABLE [SAi].[AssistantPlaybookSteps] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL,
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL ROWGUIDCOL,
  [PlaybookId] [int] NOT NULL,
  [StepOrder] [int] NOT NULL,
  [Title] [nvarchar](250) NOT NULL,
  [InstructionMarkdown] [nvarchar](max) NOT NULL,
  [IsOptional] [bit] NOT NULL CONSTRAINT [DF_AssistantPlaybookSteps_IsOptional] DEFAULT (0),
  [ExpectedOutcome] [nvarchar](1000) NULL
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_AssistantPlaybookSteps] on table [SAi].[AssistantPlaybookSteps]')
GO
ALTER TABLE [SAi].[AssistantPlaybookSteps] WITH NOCHECK
  ADD CONSTRAINT [PK_AssistantPlaybookSteps] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_AssistantPlaybookSteps_Guid] on table [SAi].[AssistantPlaybookSteps]')
GO
ALTER TABLE [SAi].[AssistantPlaybookSteps] WITH NOCHECK
  ADD CONSTRAINT [UQ_AssistantPlaybookSteps_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create foreign key [FK_AssistantPlaybookSteps_DataObjects] on table [SAi].[AssistantPlaybookSteps]')
GO
ALTER TABLE [SAi].[AssistantPlaybookSteps] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantPlaybookSteps_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_AssistantPlaybookSteps_DataObjects] on table [SAi].[AssistantPlaybookSteps]')
GO
ALTER TABLE [SAi].[AssistantPlaybookSteps]
  NOCHECK CONSTRAINT [FK_AssistantPlaybookSteps_DataObjects]
GO

PRINT (N'Create foreign key [FK_AssistantPlaybookSteps_Playbooks] on table [SAi].[AssistantPlaybookSteps]')
GO
ALTER TABLE [SAi].[AssistantPlaybookSteps] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantPlaybookSteps_Playbooks] FOREIGN KEY ([PlaybookId]) REFERENCES [SAi].[AssistantPlaybooks] ([ID])
GO

PRINT (N'Create foreign key [FK_AssistantPlaybookSteps_RowStatus] on table [SAi].[AssistantPlaybookSteps]')
GO
ALTER TABLE [SAi].[AssistantPlaybookSteps] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantPlaybookSteps_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
PRINT (N'Create table [SAi].[AssistantWorkflowTemplates]')
GO
CREATE TABLE [SAi].[AssistantWorkflowTemplates] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL,
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL ROWGUIDCOL,
  [Code] [nvarchar](50) NOT NULL,
  [Title] [nvarchar](250) NOT NULL,
  [Summary] [nvarchar](1000) NULL,
  [AudienceCode] [nvarchar](30) NULL,
  [TemplatePrompt] [nvarchar](max) NOT NULL,
  [ClarificationSchemaJson] [nvarchar](max) NULL,
  [OutputFormatCode] [nvarchar](30) NOT NULL,
  [IsPublished] [bit] NOT NULL CONSTRAINT [DF_AssistantWorkflowTemplates_IsPublished] DEFAULT (0),
  [IsFeatured] [bit] NOT NULL CONSTRAINT [DF_AssistantWorkflowTemplates_IsFeatured] DEFAULT (0),
  [CreatedByUserId] [int] NOT NULL,
  [CreatedUtc] [datetime2] NOT NULL,
  [UpdatedUtc] [datetime2] NULL
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_AssistantWorkflowTemplates] on table [SAi].[AssistantWorkflowTemplates]')
GO
ALTER TABLE [SAi].[AssistantWorkflowTemplates] WITH NOCHECK
  ADD CONSTRAINT [PK_AssistantWorkflowTemplates] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_AssistantWorkflowTemplates_Code] on table [SAi].[AssistantWorkflowTemplates]')
GO
ALTER TABLE [SAi].[AssistantWorkflowTemplates] WITH NOCHECK
  ADD CONSTRAINT [UQ_AssistantWorkflowTemplates_Code] UNIQUE ([Code]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_AssistantWorkflowTemplates_Guid] on table [SAi].[AssistantWorkflowTemplates]')
GO
ALTER TABLE [SAi].[AssistantWorkflowTemplates] WITH NOCHECK
  ADD CONSTRAINT [UQ_AssistantWorkflowTemplates_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create index [IX_AssistantWorkflowTemplates_Published_Featured] on table [SAi].[AssistantWorkflowTemplates]')
GO
CREATE INDEX [IX_AssistantWorkflowTemplates_Published_Featured]
  ON [SAi].[AssistantWorkflowTemplates] ([IsPublished], [IsFeatured] DESC, [AudienceCode])
  INCLUDE ([Code], [Title], [OutputFormatCode])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_AssistantWorkflowTemplates_DataObjects] on table [SAi].[AssistantWorkflowTemplates]')
GO
ALTER TABLE [SAi].[AssistantWorkflowTemplates] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantWorkflowTemplates_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_AssistantWorkflowTemplates_DataObjects] on table [SAi].[AssistantWorkflowTemplates]')
GO
ALTER TABLE [SAi].[AssistantWorkflowTemplates]
  NOCHECK CONSTRAINT [FK_AssistantWorkflowTemplates_DataObjects]
GO

PRINT (N'Create foreign key [FK_AssistantWorkflowTemplates_Identities_CreatedBy] on table [SAi].[AssistantWorkflowTemplates]')
GO
ALTER TABLE [SAi].[AssistantWorkflowTemplates] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantWorkflowTemplates_Identities_CreatedBy] FOREIGN KEY ([CreatedByUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_AssistantWorkflowTemplates_RowStatus] on table [SAi].[AssistantWorkflowTemplates]')
GO
ALTER TABLE [SAi].[AssistantWorkflowTemplates] WITH NOCHECK
  ADD CONSTRAINT [FK_AssistantWorkflowTemplates_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
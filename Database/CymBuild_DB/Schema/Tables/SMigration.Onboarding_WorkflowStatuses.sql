PRINT (N'Create table [SMigration].[Onboarding_WorkflowStatuses]')
GO
PRINT (N'Create table [SMigration].[Onboarding_WorkflowStatuses]')
GO
CREATE TABLE [SMigration].[Onboarding_WorkflowStatuses] (
  [RunGuid] [uniqueidentifier] NOT NULL,
  [WorkflowStatusGuid] [uniqueidentifier] NOT NULL,
  [RowStatus] [tinyint] NOT NULL,
  [OrganisationalUnitGuid] [uniqueidentifier] NULL,
  [Name] [nvarchar](100) NOT NULL,
  [Description] [nvarchar](400) NOT NULL,
  [ShowInEnquiries] [bit] NOT NULL,
  [ShowInQuotes] [bit] NOT NULL,
  [ShowInJobs] [bit] NOT NULL,
  [Enabled] [bit] NOT NULL,
  [IsPredefined] [bit] NOT NULL,
  [SortOrder] [int] NOT NULL,
  [Colour] [nvarchar](7) NOT NULL,
  [Icon] [nvarchar](50) NULL,
  [SendNotification] [bit] NOT NULL,
  [IsCompleteStatus] [bit] NOT NULL,
  [IsCustomerWaitingStatus] [bit] NOT NULL,
  [RequiresUsersAction] [bit] NOT NULL,
  [IsActiveStatus] [bit] NOT NULL,
  [AuthorisationNeeded] [bit] NOT NULL,
  [IsAuthStatus] [bit] NOT NULL
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_SMigration_Onboarding_WorkflowStatuses] on table [SMigration].[Onboarding_WorkflowStatuses]')
GO
ALTER TABLE [SMigration].[Onboarding_WorkflowStatuses] WITH NOCHECK
  ADD CONSTRAINT [PK_SMigration_Onboarding_WorkflowStatuses] PRIMARY KEY CLUSTERED ([RunGuid], [WorkflowStatusGuid]) WITH (FILLFACTOR = 80)
GO
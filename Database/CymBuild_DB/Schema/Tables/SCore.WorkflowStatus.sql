PRINT (N'Create table [SCore].[WorkflowStatus]')
GO
CREATE TABLE [SCore].[WorkflowStatus] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF__WorkflowS__RowSt__36005452] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NULL CONSTRAINT [DF_WorkflowStatus_Guid] DEFAULT (newid()),
  [OrganisationalUnitId] [int] NOT NULL CONSTRAINT [DF_WorkflowStatus_OrganisationalUnitId] DEFAULT (-1),
  [Name] [nvarchar](100) NOT NULL CONSTRAINT [DF_WorkflowStatus_Name] DEFAULT (''),
  [Description] [nvarchar](400) NOT NULL CONSTRAINT [DF_WorkflowStatus_Description] DEFAULT (''),
  [ShowInEnquiries] [bit] NOT NULL CONSTRAINT [DF__WorkflowS__ShowI__3AC5096F] DEFAULT (0),
  [ShowInQuotes] [bit] NOT NULL CONSTRAINT [DF__WorkflowS__ShowI__3BB92DA8] DEFAULT (0),
  [ShowInJobs] [bit] NOT NULL CONSTRAINT [DF__WorkflowS__ShowI__3CAD51E1] DEFAULT (0),
  [Enabled] [bit] NOT NULL CONSTRAINT [DF__WorkflowS__Enabl__3DA1761A] DEFAULT (1),
  [IsPredefined] [bit] NOT NULL CONSTRAINT [DF__WorkflowS__IsPre__3E959A53] DEFAULT (0),
  [SortOrder] [int] NOT NULL CONSTRAINT [DF__WorkflowS__SortO__3F89BE8C] DEFAULT (0),
  [Colour] [nvarchar](7) NOT NULL CONSTRAINT [DF__WorkflowS__Colou__407DE2C5] DEFAULT ('#FFFFFF'),
  [Icon] [nvarchar](50) NULL,
  [SendNotification] [bit] NOT NULL CONSTRAINT [DF_WorkflowStatus_SendNotification] DEFAULT (0),
  [IsCompleteStatus] [bit] NOT NULL CONSTRAINT [DF_WorkflowStatus_IsCompleteStatus] DEFAULT (0),
  [IsCustomerWaitingStatus] [bit] NOT NULL CONSTRAINT [DF_WorkflowStatus_IsCustomerWaitingStatus] DEFAULT (0),
  [RequiresUsersAction] [bit] NOT NULL CONSTRAINT [DF_WorkflowStatus_RequiresUsersAction] DEFAULT (0),
  [IsActiveStatus] [bit] NOT NULL CONSTRAINT [DF_WorkflowStatus_IsActiveStatus] DEFAULT (0),
  [AuthorisationNeeded] [bit] NOT NULL CONSTRAINT [DF_WorkflowStatus_AuthorisationNeeded] DEFAULT (0),
  [IsAuthStatus] [bit] NOT NULL CONSTRAINT [DF_WorkflowStatus_IsAuthStatus] DEFAULT (0),
  CONSTRAINT [PK_SCore_WorkflowStatus] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80),
  UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
)
ON [PRIMARY]
GO

CREATE INDEX [IX_WorkflowStatus_Id_Guid]
  ON [SCore].[WorkflowStatus] ([ID])
  INCLUDE ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_WorkflowStatus_Id_Guid] on table [SCore].[WorkflowStatus]')
GO
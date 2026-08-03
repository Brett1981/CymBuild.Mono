SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

/* ================================================================================================
   CymBuild OnBoarding R4 F9
   Adds staged workflow status support for SCore.WorkflowStatus.
   Deployment-safe: creates the stage table only when missing.
   ================================================================================================ */
IF OBJECT_ID(N'SMigration.Onboarding_WorkflowStatuses', N'U') IS NULL
BEGIN
    CREATE TABLE [SMigration].[Onboarding_WorkflowStatuses]
    (
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
        [IsAuthStatus] [bit] NOT NULL,
        CONSTRAINT [PK_SMigration_Onboarding_WorkflowStatuses]
            PRIMARY KEY CLUSTERED ([RunGuid], [WorkflowStatusGuid]) WITH (FILLFACTOR = 80)
    );
END;
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

/* ================================================================================================
   CymBuild OnBoarding R4 F9
   Re-seed OnBoarding scope so Workflows, WorkflowStatuses, WorkflowTransitions and
   WorkflowStatusNotificationGroups are all visible/selectable review buckets.
   ================================================================================================ */
EXEC [SMigration].[OnboardingEntityScope_Seed];
GO

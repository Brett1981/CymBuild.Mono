/*
    CYB-361 generated manual preview deployment script
    Target server   : SOC-SQLDEVBRE01\GENERAL
    Target database : CymBuild_QA
    Run Guid        : fa5875dd-af78-41c1-94b7-03dca5ce8be1
    Generated UTC   : 2026-09-04T13:24:32.0070408Z

    INSPECTION ONLY. Do not execute this generated file as the approved deployment path.
    Run Invoke-CymBuildSchemaDeployment.ps1 so existence checks, LIVE guardrails and SMigration audit are enforced.
*/
USE [CymBuild_QA];
GO
EXEC sys.sp_set_session_context @key = N'CymBuild_schema_predeployment_will_run', @value = 1, @read_only = 0;
GO
EXEC [SCore].[PreDeploymentScript];
GO
EXEC sys.sp_set_session_context @key = N'CymBuild_schema_predeployment_will_run', @value = 0, @read_only = 0;
GO
DECLARE @CymBuildPostDeploymentRunGuid UNIQUEIDENTIFIER = NEWID();
EXEC [SCore].[PostDeploymentScript] @ThrowOnIssues = 1, @RunGuid = @CymBuildPostDeploymentRunGuid;
GO

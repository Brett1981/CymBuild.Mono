/*
    CymBuild schema deployment shared helper.

    Creates a connection-local temporary procedure used by dedicated, source-controlled table
    migrations. The helper changes only column nullability and dynamically preserves supported
    target indexes and standalone user-created statistics that depend on the altered columns.
    Read-only preflight may recognise schema-bound functions/views that the controlled
    SCore.PreDeploymentScript can remove through SCore.SCHEMABINDING. Apply mode remains strict:
    those dependencies must be absent before any column is altered. Unsupported table, column,
    index, statistics, full-text, computed-column, and unmanaged schema-bound dependency shapes
    are rejected before target maintenance begins.

    The calling migration must own an active transaction. Unsupported dependency shapes are
    rejected before any dependency is dropped.
*/
SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;
SET NOCOUNT ON;
GO

IF OBJECT_ID(N'tempdb..#CymBuild_AlterColumnNullabilityWithDependencies', N'P') IS NOT NULL
BEGIN
    DROP PROCEDURE #CymBuild_AlterColumnNullabilityWithDependencies;
END;
GO
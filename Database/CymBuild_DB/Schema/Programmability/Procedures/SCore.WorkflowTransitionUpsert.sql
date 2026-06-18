SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SCore].[WorkflowTransitionUpsert]')
GO

CREATE PROCEDURE [SCore].[WorkflowTransitionUpsert]
(
    @Guid           UNIQUEIDENTIFIER,
    @WorkflowGuid   UNIQUEIDENTIFIER,
    @FromStatusGuid UNIQUEIDENTIFIER,
    @ToStatusGuid   UNIQUEIDENTIFIER,
    @IsFinal        BIT,
    @Enabled        BIT,
    @SortOrder      INT,
    @Description    NVARCHAR(400)
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @FromStatusID INT,
        @ToStatusID INT,
        @WorkflowID INT,
        @ExistingGuid UNIQUEIDENTIFIER,
        @EffectiveGuid UNIQUEIDENTIFIER,
        @IsInsert BIT = 0;

    SELECT @FromStatusID = ws.ID
    FROM SCore.WorkflowStatus AS ws
    WHERE ws.Guid = @FromStatusGuid
      AND ws.RowStatus NOT IN (0,254);

    SELECT @ToStatusID = ws.ID
    FROM SCore.WorkflowStatus AS ws
    WHERE ws.Guid = @ToStatusGuid
      AND ws.RowStatus NOT IN (0,254);

    SELECT @WorkflowID = wf.ID
    FROM SCore.Workflow AS wf
    WHERE wf.Guid = @WorkflowGuid
      AND wf.RowStatus NOT IN (0,254);

    IF (@WorkflowID IS NULL)
        THROW 60000, N'Could not resolve Workflow.', 1;

    IF (@FromStatusID IS NULL)
        THROW 60000, N'Could not resolve From Status.', 1;

    IF (@ToStatusID IS NULL)
        THROW 60000, N'Could not resolve To Status.', 1;

    IF (@FromStatusID = @ToStatusID)
        THROW 60000, N'From Status and To Status cannot be the same.', 1;

    -------------------------------------------------------------------------
    -- Prefer exact Guid match first.
    -------------------------------------------------------------------------
    SELECT TOP (1)
        @ExistingGuid = wt.Guid
    FROM SCore.WorkflowTransition AS wt
    WHERE wt.Guid = @Guid;

    -------------------------------------------------------------------------
    -- If the UI supplied a new Guid but the same transition already exists,
    -- update the existing transition instead of inserting a duplicate.
    -------------------------------------------------------------------------
    IF (@ExistingGuid IS NULL)
    BEGIN
        SELECT TOP (1)
            @ExistingGuid = wt.Guid
        FROM SCore.WorkflowTransition AS wt
        WHERE wt.WorkflowID = @WorkflowID
          AND wt.FromStatusID = @FromStatusID
          AND wt.ToStatusID = @ToStatusID
          AND wt.RowStatus NOT IN (0,254)
        ORDER BY wt.ID;
    END;

    SET @EffectiveGuid = ISNULL(@ExistingGuid, @Guid);

    EXEC SCore.UpsertDataObject
        @Guid = @EffectiveGuid,
        @SchemeName = N'SCore',
        @ObjectName = N'WorkflowTransition',
        @IsInsert = @IsInsert OUTPUT,
        @IncludeDefaultSecurity = 1;

    IF EXISTS
    (
        SELECT 1
        FROM SCore.WorkflowTransition AS wt
        WHERE wt.Guid = @EffectiveGuid
    )
    BEGIN
        UPDATE wt
        SET wt.RowStatus = 1,
            wt.WorkflowID = @WorkflowID,
            wt.FromStatusID = @FromStatusID,
            wt.ToStatusID = @ToStatusID,
            wt.IsFinal = @IsFinal,
            wt.Enabled = @Enabled,
            wt.SortOrder = @SortOrder,
            wt.Description = ISNULL(@Description, N'')
        FROM SCore.WorkflowTransition AS wt
        WHERE wt.Guid = @EffectiveGuid;
    END;
    ELSE
    BEGIN
        INSERT SCore.WorkflowTransition
        (
            RowStatus,
            Guid,
            WorkflowID,
            FromStatusID,
            ToStatusID,
            IsFinal,
            Enabled,
            SortOrder,
            Description
        )
        VALUES
        (
            1,
            @EffectiveGuid,
            @WorkflowID,
            @FromStatusID,
            @ToStatusID,
            @IsFinal,
            @Enabled,
            @SortOrder,
            ISNULL(@Description, N'')
        );
    END;
END;
GO
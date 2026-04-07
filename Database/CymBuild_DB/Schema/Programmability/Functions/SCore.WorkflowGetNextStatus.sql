SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
/* =============================================================================
   CYB-101 – WorkflowGetNextStatus (UI next-status dropdown)

   Fixes:
   - Latest-status-only enforcement (use single latest StatusID for @ParentGuid)
   - Quote guardrail: hide Sent/Accepted when 0 active QuoteItems exist
   - Respect IsFinal (no further next statuses)
   - DEDUPE: remove duplicate options caused by duplicate WorkflowStatus rows
            (dedupe by Name, prefer IsPredefined/Enabled/SortOrder/lowest ID)

============================================================================= */
CREATE FUNCTION [SCore].[WorkflowGetNextStatus]
(
    @ParentGuid UNIQUEIDENTIFIER,
    @RecordGuid UNIQUEIDENTIFIER
)
RETURNS @WorkflowStatus TABLE
(
    Name     NVARCHAR(50),
    Guid     UNIQUEIDENTIFIER,
    RowStatus TINYINT
)
       --WITH SCHEMABINDING
AS
BEGIN
    DECLARE @EntityTypeGuid UNIQUEIDENTIFIER;
    DECLARE @EntityTypeID   INT;

    -- Filters
    DECLARE @ShowInEnquiry BIT = 0;
    DECLARE @ShowInQuotes  BIT = 0;
    DECLARE @ShowInJobs    BIT = 0;

    DECLARE @OrgUnitID INT;

    -------------------------------------------------------------------------
    -- Entity type + workflow scope lookup (via DataObjects -> EntityTypes)
    -------------------------------------------------------------------------
    SELECT
        @EntityTypeGuid = et.Guid,
        @EntityTypeID   = et.ID
    FROM SCore.DataObjects AS root_hobt
    JOIN SCore.EntityTypes AS et ON et.ID = root_hobt.EntityTypeId
    WHERE root_hobt.Guid = @ParentGuid;

    -- Enquiry
    IF (@EntityTypeGuid = CONVERT(uniqueidentifier, '3B4F2DF9-B6CF-4A49-9EED-2206473867A1'))
    BEGIN
        SET @ShowInEnquiry = 1;

        SELECT @OrgUnitID = e.OrganisationalUnitID
        FROM SSop.Enquiries AS e
        WHERE e.Guid = @ParentGuid;
    END
    -- Quotes
    ELSE IF (@EntityTypeGuid = CONVERT(uniqueidentifier, '1C4794C1-F956-4C32-B886-5500AC778A56'))
    BEGIN
        SET @ShowInQuotes = 1;

        SELECT @OrgUnitID = q.OrganisationalUnitID
        FROM SSop.Quotes AS q
        WHERE q.Guid = @ParentGuid;
    END
    -- Jobs
    ELSE IF (@EntityTypeGuid = CONVERT(uniqueidentifier, '63542427-46AB-4078-ABD1-1D583C24315C'))
    BEGIN
        SET @ShowInJobs = 1;

        SELECT @OrgUnitID = j.OrganisationalUnitID
        FROM SJob.Jobs AS j
        WHERE j.Guid = @ParentGuid;
    END;

    DECLARE @CurrentStatusID INT = NULL;
    DECLARE @IsFinal BIT = 0;

    -------------------------------------------------------------------------
    -- Resolve SINGLE latest workflow status for this record (latest-only)
    -------------------------------------------------------------------------
    SELECT TOP (1)
        @CurrentStatusID = dot.StatusID
    FROM SCore.DataObjectTransition AS dot
    WHERE dot.DataObjectGuid = @ParentGuid
      AND dot.RowStatus NOT IN (0,254)
    ORDER BY dot.DateTimeUTC DESC, dot.ID DESC;

    -------------------------------------------------------------------------
    -- Determine if the latest transition is final (keep existing behaviour)
    -------------------------------------------------------------------------
    SELECT @IsFinal = wft.IsFinal
    FROM SCore.DataObjectTransition AS dot1
    JOIN SCore.WorkflowTransition  AS wft ON wft.ToStatusID = dot1.StatusID
    WHERE dot1.DataObjectGuid = @ParentGuid
      AND dot1.RowStatus NOT IN (0,254)
      AND NOT EXISTS
      (
          SELECT 1
          FROM SCore.DataObjectTransition AS dot2
          WHERE dot2.DataObjectGuid = @ParentGuid
            AND dot2.RowStatus NOT IN (0,254)
            AND
            (
                dot2.DateTimeUTC > dot1.DateTimeUTC
                OR (dot2.DateTimeUTC = dot1.DateTimeUTC AND dot2.ID > dot1.ID)
            )
      );

    -------------------------------------------------------------------------
    -- If viewing an existing transition record, return all statuses (deduped)
    -------------------------------------------------------------------------
    IF (EXISTS (SELECT 1 FROM SCore.DataObjectTransition AS d WHERE d.Guid = @RecordGuid AND d.StatusID <> 1))
    BEGIN
        INSERT INTO @WorkflowStatus (Name, Guid, RowStatus)
        SELECT x.Name, x.Guid, x.RowStatus
        FROM
        (
            SELECT
                toStatus.Name      AS Name,
                toStatus.Guid      AS Guid,
                toStatus.RowStatus AS RowStatus,
                ROW_NUMBER() OVER
                (
                    PARTITION BY toStatus.Name
                    ORDER BY
                        ISNULL(toStatus.IsPredefined, 0) DESC,
                        ISNULL(toStatus.Enabled, 1) DESC,
                        ISNULL(toStatus.SortOrder, 999999) ASC,
                        toStatus.ID ASC
                ) AS rn
            FROM SCore.WorkflowTransition AS wft
            JOIN SCore.WorkflowStatus    AS fromStatus ON fromStatus.ID = wft.FromStatusID
            JOIN SCore.WorkflowStatus    AS toStatus   ON toStatus.ID   = wft.ToStatusID
            JOIN SCore.Workflow          AS wf         ON wf.ID         = wft.WorkflowID
            WHERE wft.RowStatus NOT IN (0,254)
              AND wf.Enabled = 1
              AND wf.EntityTypeID = @EntityTypeID
              AND wf.OrganisationalUnitId =
                    CASE
                        WHEN EXISTS
                        (
                            SELECT 1
                            FROM SCore.Workflow AS wf2
                            WHERE wf2.OrganisationalUnitId = @OrgUnitID
                              AND wf2.EntityTypeID = @EntityTypeID
                              AND wf2.Enabled = 1
                        )
                        THEN @OrgUnitID
                        ELSE -1
                    END
              AND fromStatus.RowStatus NOT IN (0,254)
              AND toStatus.RowStatus   NOT IN (0,254)
			  AND toStatus.IsAuthStatus = 0
              AND
              (
                  (@ShowInEnquiry = 0 OR ISNULL(toStatus.ShowInEnquiries,0) = 1) AND
                  (@ShowInQuotes  = 0 OR ISNULL(toStatus.ShowInQuotes,0)    = 1) AND
                  (@ShowInJobs    = 0 OR ISNULL(toStatus.ShowInJobs,0)      = 1)
              )
              AND toStatus.ID <> 1 -- Exclude "N/A"
        ) AS x
        WHERE x.rn = 1;

        RETURN;
    END;

    -------------------------------------------------------------------------
    -- Respect IsFinal
    -------------------------------------------------------------------------
    IF (ISNULL(@IsFinal, 0) = 1)
    BEGIN
        RETURN;
    END;

    -------------------------------------------------------------------------
    -- Quote-specific enforcement: hide Sent/Accepted when 0 QuoteItems exist
    -------------------------------------------------------------------------
    DECLARE @QuoteHasItems BIT = 1;

    IF (@ShowInQuotes = 1)
    BEGIN
        IF NOT EXISTS
        (
            SELECT 1
            FROM SSop.QuoteItems AS qi
            JOIN SSop.Quotes     AS q  ON q.ID = qi.QuoteId
            WHERE q.Guid = @ParentGuid
              AND q.RowStatus  NOT IN (0,254)
              AND qi.RowStatus NOT IN (0,254)
        )
        BEGIN
            SET @QuoteHasItems = 0;
        END;
    END;

    -------------------------------------------------------------------------
    -- Return next statuses from CURRENT status only (latest-only) + DEDUPE BY NAME
    -------------------------------------------------------------------------
    INSERT INTO @WorkflowStatus (Name, Guid, RowStatus)
    SELECT x.Name, x.Guid, x.RowStatus
    FROM
    (
        SELECT
            toStatus.Name      AS Name,
            toStatus.Guid      AS Guid,
            toStatus.RowStatus AS RowStatus,
            ROW_NUMBER() OVER
            (
                PARTITION BY toStatus.Name
                ORDER BY
                    ISNULL(toStatus.IsPredefined, 0) DESC,
                    ISNULL(toStatus.Enabled, 1) DESC,
                    ISNULL(toStatus.SortOrder, 999999) ASC,
                    toStatus.ID ASC
            ) AS rn
        FROM SCore.WorkflowTransition AS wft
        JOIN SCore.WorkflowStatus    AS fromStatus ON fromStatus.ID = wft.FromStatusID
        JOIN SCore.WorkflowStatus    AS toStatus   ON toStatus.ID   = wft.ToStatusID
        JOIN SCore.Workflow          AS wf         ON wf.ID         = wft.WorkflowID
        WHERE wft.RowStatus NOT IN (0,254)
          AND wf.Enabled = 1
          AND wf.EntityTypeID = @EntityTypeID
          AND wf.OrganisationalUnitId =
                CASE
                    WHEN EXISTS
                    (
                        SELECT 1
                        FROM SCore.Workflow AS wf2
                        WHERE wf2.OrganisationalUnitId = @OrgUnitID
                          AND wf2.EntityTypeID = @EntityTypeID
                          AND wf2.Enabled = 1
                    )
                    THEN @OrgUnitID
                    ELSE -1
                END
          AND fromStatus.RowStatus NOT IN (0,254)
          AND toStatus.RowStatus   NOT IN (0,254)
          AND
          (
              (@ShowInEnquiry = 0 OR ISNULL(toStatus.ShowInEnquiries,0) = 1) AND
              (@ShowInQuotes  = 0 OR ISNULL(toStatus.ShowInQuotes,0)    = 1) AND
              (@ShowInJobs    = 0 OR ISNULL(toStatus.ShowInJobs,0)      = 1)
          )
          AND toStatus.ID <> 1
          AND @CurrentStatusID IS NOT NULL
          AND wft.FromStatusID = @CurrentStatusID  -- LATEST-STATUS-ONLY enforcement
          AND toStatus.ID NOT IN
          (
              SELECT dot.StatusID
              FROM SCore.DataObjectTransition AS dot
              WHERE dot.DataObjectGuid = @ParentGuid
                AND dot.RowStatus NOT IN (0,254)
          )
          AND
          (
              -- CYB-101: Hide Sent/Accepted when quote has 0 items
              @ShowInQuotes = 0
              OR @QuoteHasItems = 1
              OR toStatus.Name NOT IN (N'Sent', N'Accepted')
          )
		  AND toStatus.IsAuthStatus <> 1
		 
    ) AS x
    WHERE x.rn = 1;

    RETURN;
END;
GO
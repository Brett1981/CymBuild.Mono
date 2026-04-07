SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_Jobs_Dormant]
(
    @UserId INT
)
RETURNS TABLE
      --WITH SCHEMABINDING
AS
RETURN
WITH StatusDefs AS
(
    SELECT
        DormantGuid   = CONVERT(uniqueidentifier, '6708FDB6-29A7-4505-A209-F1E785386122'),
        CancelledGuid = CONVERT(uniqueidentifier, '20D22623-283B-4088-9CEB-D944AC3E6516')
),
DefExists AS
(
    SELECT
        DormantStatusExists =
            CASE WHEN EXISTS
            (
                SELECT 1
                FROM SCore.WorkflowStatus w
                CROSS JOIN StatusDefs d
                WHERE w.RowStatus NOT IN (0,254)
                  AND w.Guid = d.DormantGuid
            )
            THEN 1 ELSE 0 END,

        CancelledStatusExists =
            CASE WHEN EXISTS
            (
                SELECT 1
                FROM SCore.WorkflowStatus w
                CROSS JOIN StatusDefs d
                WHERE w.RowStatus NOT IN (0,254)
                  AND w.Guid = d.CancelledGuid
            )
            THEN 1 ELSE 0 END
),
LastStatus AS
(
    SELECT
        dot.DataObjectGuid,
        wfs.Guid  AS LastStatusGuid,
        wfs.Name  AS LastStatusName,
        ROW_NUMBER() OVER
        (
            PARTITION BY dot.DataObjectGuid
            ORDER BY dot.DateTimeUTC DESC, dot.ID DESC
        ) AS rn
    FROM SCore.DataObjectTransition dot
    JOIN SCore.WorkflowStatus wfs ON wfs.ID = dot.StatusID
    WHERE dot.RowStatus NOT IN (0,254)
      AND wfs.RowStatus NOT IN (0,254)
)
SELECT
    j.ID,
    j.RowStatus,
    j.RowVersion,
    j.Guid,
    j.Number,
    j.JobDescription,
    j.JobTypeID,
    jt.Name AS JobTypeName,
    i.Guid AS SurveyorGuid,
    client.Name + N' / ' + agent.Name AS ClientAgent,
    i.FullName AS SurveyorName,
    prop.FormattedAddressComma AS Asset,
    ISNULL(p.IsSubjectToNDA, 0) AS IsSubjectToNDA,
    j.IsComplete,
    -- keep the existing JobStatus view if present, otherwise fall back to legacy-ish default
    js.JobStatus,
    j.JobDormant,
    org.Name AS OrgUnit,
    j.ExternalReference,
    j.JobDormant AS DormantDate
FROM SJob.Jobs j
LEFT JOIN SJob.JobStatus js             ON js.ID = j.ID
LEFT JOIN SSop.Projects p               ON p.ID = j.ProjectId
JOIN SJob.JobTypes jt                   ON jt.ID = j.JobTypeID
JOIN SCore.Identities i                 ON i.ID = j.SurveyorID
JOIN SJob.Assets prop                   ON prop.ID = j.UprnID
JOIN SCrm.Accounts client               ON client.ID = j.ClientAccountID
JOIN SCrm.Accounts agent                ON agent.ID = j.AgentAccountID
JOIN SCore.OrganisationalUnits org      ON org.ID = j.OrganisationalUnitID

-- legacy jobs may not have these rows, so keep them optional
LEFT JOIN SJob.Job_ExtendedInfo jExt    ON jExt.Id = j.ID
LEFT JOIN SSop.Quotes q                 ON q.Guid = jExt.QuoteGuid

CROSS JOIN DefExists dx
CROSS JOIN StatusDefs sd
LEFT JOIN LastStatus ls
    ON ls.DataObjectGuid = j.Guid
   AND ls.rn = 1

WHERE
    j.RowStatus NOT IN (0,254)
    AND j.ID > 0
    AND j.IsComplete = 0
    AND j.SurveyorID = @UserId

    AND EXISTS
    (
        SELECT 1
        FROM SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) oscr
    )

    ------------------------------------------------------------------------
    -- Cancelled exclusion:
    -- - If Cancelled workflow status exists: ignore legacy and use LATEST wf only
    -- - Else: use legacy JobCancelled fallback
    ------------------------------------------------------------------------
    AND
    (
        (dx.CancelledStatusExists = 1 AND ISNULL(ls.LastStatusGuid, '00000000-0000-0000-0000-000000000000') <> sd.CancelledGuid)
        OR
        (dx.CancelledStatusExists = 0 AND j.JobCancelled IS NULL)
    )

    ------------------------------------------------------------------------
    -- Dormant inclusion rule (YOUR clarified requirement):
    --
    -- If Dormant wf status definition DOES NOT exist:
    --   => purely legacy (j.JobDormant)
    --
    -- If Dormant wf status definition DOES exist:
    --   => use latest wf status (Dormant) when transitions exist,
    --      but still allow legacy dormant when there are no transitions yet.
    ------------------------------------------------------------------------
    AND
    (
        (dx.DormantStatusExists = 0 AND j.JobDormant IS NOT NULL)
        OR
        (dx.DormantStatusExists = 1 AND
            (
                ls.LastStatusGuid = sd.DormantGuid
                OR (ls.LastStatusGuid IS NULL AND j.JobDormant IS NOT NULL)
            )
        )
    );
GO
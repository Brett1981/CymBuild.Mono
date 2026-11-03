/*
    [CYB-237] Backfill Original / New Total Agreed Fee on legacy fee amendments.

    Fee amendments created before CYB-237 carry the legacy status (SJob.FeeAmendmentStatus with the
    zero Guid, ID -1) and were given the column defaults OriginalAgreedFee = 0 / NewTotalAgreedFee = 0.

    Sourcing (as per CYB-237): the Original Agreed Fee is looked up from the Agreed column of the
    job's Fees grid (SJob.Job_FeeDrawdown) for the specific stage being amended. If the amendment
    applies to Fee Cap, the Fee Cap row is used.

    Because the grid's Agreed value today already includes this amendment and any later ones, the
    value is taken as it stood immediately before this amendment:

        OriginalAgreedFee = grid Agreed for the amended stage
                          - changes to that stage from this and later (ID >=) counted amendments
        NewTotalAgreedFee = OriginalAgreedFee + this amendment's change to that stage

    so each amendment's New Total equals the next amendment's Original on the same stage.
    A stage's change mirrors the grid: the fixed column for the stage number (FeeCapChange for
    Fee Cap), plus SJob.FeeAmendmentRibaStages / SJob.CustomFeeAmendment rows for that stage.
    "Counted" amendments are those the grid includes: legacy and Agreed.

    If one amendment changes more than one stage, the amended stages are summed (listed in the
    preview as StagesAmended). Amendments with no fee change on a grid stage (e.g. meeting/visit
    only) cannot be sourced and are listed separately, not updated.

    Run once per environment as a release step (QA -> UAT -> LIVE). Run with @WhatIf = 1 first to
    review the preview, then with @WhatIf = 0. Idempotent: only rows whose stored values differ from
    the calculation are updated, so a re-run changes nothing.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @WhatIf BIT = 0;    -- 1 = preview only, 0 = apply

DECLARE @LegacyFeeAmendmentStatusGuid UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000000',
        @AgreedFeeAmendmentStatusGuid UNIQUEIDENTIFIER = '215F258A-CF79-468F-9EB8-A84481F7F8AF';

DROP TABLE IF EXISTS #CountedStatus;
DROP TABLE IF EXISTS #Legacy;
DROP TABLE IF EXISTS #Grid;
DROP TABLE IF EXISTS #StageChange;
DROP TABLE IF EXISTS #Calculated;

-- Statuses the Fees grid counts towards Agreed (matches SJob.Job_FeeDrawdown).
SELECT  fas.ID
INTO    #CountedStatus
FROM    SJob.FeeAmendmentStatus AS fas
WHERE   (fas.[Guid] IN (@LegacyFeeAmendmentStatusGuid, @AgreedFeeAmendmentStatusGuid));

-- Active legacy amendments to backfill.
SELECT  fa.ID,
        fa.[Guid],
        fa.JobID,
        fa.OriginalAgreedFee,
        fa.NewTotalAgreedFee
INTO    #Legacy
FROM    SJob.FeeAmendment AS fa
JOIN    SJob.FeeAmendmentStatus AS fas ON (fas.ID = fa.FeeAmendmentStatusID)
WHERE   (fas.[Guid] = @LegacyFeeAmendmentStatusGuid)
    AND (fa.ID > 0)
    AND (fa.RowStatus NOT IN (0,254));

-- Fees grid stage rows (Agreed column) for those jobs; the two Total rows (StageId -2/-3) are excluded.
SELECT  fd.JobId,
        fd.StageId,
        fd.StageLabel,
        fd.Agreed
INTO    #Grid
FROM    SJob.Job_FeeDrawdown AS fd
WHERE   (fd.StageId > 0)
    AND (fd.JobId IN (SELECT l.JobID FROM #Legacy AS l));

-- Each counted amendment's fee change per grid stage, attributed the same way the grid does.
SELECT  fa.ID       AS FeeAmendmentID,
        g.JobId,
        g.StageId,
        g.StageLabel,
        chg.FeeChange
INTO    #StageChange
FROM    #Grid AS g
JOIN    SJob.RibaStages AS rs ON (rs.ID = g.StageId)
JOIN    SJob.FeeAmendment AS fa ON (fa.JobID = g.JobId)
CROSS APPLY
(
    SELECT  CASE rs.Number
                WHEN 0   THEN fa.RibaStage0Change
                WHEN 1   THEN fa.RibaStage1Change
                WHEN 2   THEN fa.RibaStage2Change
                WHEN 3   THEN fa.RibaStage3Change
                WHEN 4   THEN fa.RibaStage4Change
                WHEN 5   THEN fa.RibaStage5Change
                WHEN 6   THEN fa.RibaStage6Change
                WHEN 7   THEN fa.RibaStage7Change
                WHEN 99  THEN fa.PreConstructionStageChange
                WHEN 999 THEN fa.ConstructionStageChange
                WHEN -1  THEN fa.FeeCapChange
                ELSE 0
            END
          + ISNULL((SELECT SUM(fars.FeeChange)
                    FROM   SJob.FeeAmendmentRibaStages AS fars
                    WHERE  (fars.FeeAmendmentID = fa.ID)
                       AND (fars.RibaStageID = rs.ID)
                       AND (fars.RowStatus NOT IN (0,254))), 0)
          + ISNULL((SELECT SUM(cfa.StageChange)
                    FROM   SJob.CustomFeeAmendment AS cfa
                    WHERE  (cfa.FeeAmendmentId = fa.ID)
                       AND (cfa.StageId = rs.ID)
                       AND (cfa.RowStatus NOT IN (0,254))), 0) AS FeeChange
) AS chg
WHERE   (fa.RowStatus NOT IN (0,254))
    AND (fa.FeeAmendmentStatusID IN (SELECT cs.ID FROM #CountedStatus AS cs))
    AND (chg.FeeChange <> 0);

-- Original = grid Agreed less this and later changes to the stage; New = Original + this change.
SELECT  l.ID,
        l.[Guid],
        l.JobID,
        l.OriginalAgreedFee                               AS CurrentOriginalAgreedFee,
        l.NewTotalAgreedFee                               AS CurrentNewTotalAgreedFee,
        SUM(g.Agreed - laterChange.FeeChange)             AS CalcOriginalAgreedFee,
        SUM(g.Agreed - laterChange.FeeChange + sc.FeeChange) AS CalcNewTotalAgreedFee,
        STRING_AGG(sc.StageLabel, N', ')                  AS StagesAmended,
        COUNT(1)                                          AS StageCount
INTO    #Calculated
FROM    #Legacy AS l
JOIN    #StageChange AS sc ON (sc.FeeAmendmentID = l.ID)
JOIN    #Grid AS g ON (g.JobId = sc.JobId AND g.StageId = sc.StageId)
CROSS APPLY
(
    SELECT  SUM(later.FeeChange) AS FeeChange
    FROM    #StageChange AS later
    WHERE   (later.JobId = sc.JobId)
        AND (later.StageId = sc.StageId)
        AND (later.FeeAmendmentID >= l.ID)
) AS laterChange
GROUP BY l.ID, l.[Guid], l.JobID, l.OriginalAgreedFee, l.NewTotalAgreedFee;

DECLARE @LegacyCount     INT = (SELECT COUNT(1) FROM #Legacy),
        @UnresolvedCount INT = (SELECT COUNT(1) FROM #Legacy AS l WHERE NOT EXISTS (SELECT 1 FROM #Calculated AS c WHERE c.ID = l.ID)),
        @MultiStageCount INT = (SELECT COUNT(1) FROM #Calculated AS c WHERE c.StageCount > 1),
        @ToUpdate        INT = (SELECT COUNT(1)
                                FROM   #Calculated AS c
                                WHERE  (c.CurrentOriginalAgreedFee <> c.CalcOriginalAgreedFee)
                                    OR (c.CurrentNewTotalAgreedFee <> c.CalcNewTotalAgreedFee));

PRINT CONCAT(N'[CYB-237] Active legacy fee amendments: ', @LegacyCount,
             N'; needing update: ', @ToUpdate,
             N'; multi-stage: ', @MultiStageCount,
             N'; unresolved (no stage fee change): ', @UnresolvedCount,
             N'; mode: ', CASE WHEN @WhatIf = 1 THEN N'WhatIf (no changes)' ELSE N'Apply' END);

-- Preview of the rows that will change.
SELECT  c.ID,
        c.[Guid],
        j.Number AS JobNumber,
        c.StagesAmended,
        c.CurrentOriginalAgreedFee,
        c.CalcOriginalAgreedFee,
        c.CurrentNewTotalAgreedFee,
        c.CalcNewTotalAgreedFee
FROM    #Calculated AS c
JOIN    SJob.Jobs AS j ON (j.ID = c.JobID)
WHERE   (c.CurrentOriginalAgreedFee <> c.CalcOriginalAgreedFee)
    OR  (c.CurrentNewTotalAgreedFee <> c.CalcNewTotalAgreedFee)
ORDER BY c.JobID, c.ID;

-- Legacy amendments that cannot be sourced from a grid stage (left unchanged).
SELECT  l.ID,
        l.[Guid],
        j.Number AS JobNumber,
        l.OriginalAgreedFee,
        l.NewTotalAgreedFee
FROM    #Legacy AS l
JOIN    SJob.Jobs AS j ON (j.ID = l.JobID)
WHERE   NOT EXISTS (SELECT 1 FROM #Calculated AS c WHERE c.ID = l.ID)
ORDER BY l.JobID, l.ID;

IF (@WhatIf = 0)
BEGIN
    BEGIN TRANSACTION;

    UPDATE  fa
    SET     fa.OriginalAgreedFee = c.CalcOriginalAgreedFee,
            fa.NewTotalAgreedFee = c.CalcNewTotalAgreedFee
    FROM    SJob.FeeAmendment AS fa
    JOIN    #Calculated AS c ON (c.ID = fa.ID)
    WHERE   (fa.OriginalAgreedFee <> c.CalcOriginalAgreedFee)
        OR  (fa.NewTotalAgreedFee <> c.CalcNewTotalAgreedFee);

    PRINT CONCAT(N'[CYB-237] Rows updated: ', @@ROWCOUNT);

    COMMIT TRANSACTION;
END;

DROP TABLE IF EXISTS #CountedStatus;
DROP TABLE IF EXISTS #Legacy;
DROP TABLE IF EXISTS #Grid;
DROP TABLE IF EXISTS #StageChange;
DROP TABLE IF EXISTS #Calculated;

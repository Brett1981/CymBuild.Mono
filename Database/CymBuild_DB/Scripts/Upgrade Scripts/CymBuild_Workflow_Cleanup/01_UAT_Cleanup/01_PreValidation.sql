/*
    CymBuild Workflow Cleanup & Rationalisation
    Generated from UAT Workflows.zip export.
    Safety rules:
      - No direct entity current status update.
      - SCore.DataObjectTransition rows are preserved.
      - Duplicate status references are migrated before duplicate status rows are removed.
      - RowStatus filters use RowStatus NOT IN (0,254) for active checks.
      - No SELECT *.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

PRINT N'Workflow cleanup pre-validation';

DECLARE @Failures TABLE
(
    FailureCode nvarchar(100) NOT NULL,
    FailureDetail nvarchar(4000) NOT NULL
);

DECLARE @StatusMap TABLE
(
    OldStatusID int NOT NULL PRIMARY KEY,
    NewStatusID int NOT NULL,
    ExpectedOldName nvarchar(100) NOT NULL,
    ExpectedNewName nvarchar(100) NOT NULL
);

INSERT INTO @StatusMap (OldStatusID, NewStatusID, ExpectedOldName, ExpectedNewName)
VALUES
    (37, 3,  N'Declined',      N'Declined'),
    (53, 8,  N'Rejected',      N'Rejected'),
    (52, 14, N'Ready to Send', N'Ready to Send'),
    (29, 50, N'Quoting',       N'Quoting'),
    (33, 48, N'New',           N'New'),
    (41, 14, N'Ready to Send', N'Ready to Send');

INSERT INTO @Failures (FailureCode, FailureDetail)
SELECT
    N'MISSING_OR_CHANGED_STATUS_MAP',
    CONCAT(N'OldStatusID=', sm.OldStatusID, N', NewStatusID=', sm.NewStatusID, N' was not found with expected names.')
FROM @StatusMap AS sm
LEFT JOIN SCore.WorkflowStatus AS oldStatus
    ON oldStatus.ID = sm.OldStatusID
LEFT JOIN SCore.WorkflowStatus AS newStatus
    ON newStatus.ID = sm.NewStatusID
WHERE oldStatus.ID IS NULL
   OR newStatus.ID IS NULL
   OR oldStatus.Name <> sm.ExpectedOldName
   OR newStatus.Name <> sm.ExpectedNewName;

INSERT INTO @Failures (FailureCode, FailureDetail)
SELECT
    N'MISSING_RETIRED_TRANSITION',
    CONCAT(N'WorkflowTransition ID ', retire.ID, N' was not found.')
FROM (VALUES (395), (349), (439)) AS retire(ID)
LEFT JOIN SCore.WorkflowTransition AS wt
    ON wt.ID = retire.ID
WHERE wt.ID IS NULL;

INSERT INTO @Failures (FailureCode, FailureDetail)
SELECT
    N'MISSING_RETAINED_TRANSITION',
    CONCAT(N'Retained WorkflowTransition ID ', keep.ID, N' was not found.')
FROM (VALUES (242), (284), (423)) AS keep(ID)
LEFT JOIN SCore.WorkflowTransition AS wt
    ON wt.ID = keep.ID
WHERE wt.ID IS NULL;

INSERT INTO @Failures (FailureCode, FailureDetail)
SELECT
    N'UNEXPECTED_CURRENT_HIDDEN_STATUS',
    CONCAT(N'Hidden WorkflowStatus ID ', ws.ID, N' currently has latest transition usage and must not be removed without explicit approval.')
FROM SCore.WorkflowStatus AS ws
WHERE ws.RowStatus = 254
  AND EXISTS
  (
      SELECT 1
      FROM SCore.DataObjectTransition AS dot
      WHERE dot.StatusID = ws.ID
        AND dot.RowStatus NOT IN (0,254)
        AND NOT EXISTS
        (
            SELECT 1
            FROM SCore.DataObjectTransition AS newerDot
            WHERE newerDot.DataObjectGuid = dot.DataObjectGuid
              AND newerDot.RowStatus NOT IN (0,254)
              AND newerDot.ID > dot.ID
        )
  );

INSERT INTO @Failures (FailureCode, FailureDetail)
SELECT
    N'OBJECT_SECURITY_REFERENCES_REMOVED_GUIDS',
    N'SCore.ObjectSecurity contains RecordGuid references to rows proposed for deletion. Review before cleanup.'
WHERE OBJECT_ID(N'SCore.ObjectSecurity', N'U') IS NOT NULL
  AND COL_LENGTH(N'SCore.ObjectSecurity', N'RecordGuid') IS NOT NULL
  AND EXISTS
  (
      SELECT 1
      FROM SCore.ObjectSecurity AS os
      WHERE os.RecordGuid IN
      (
          SELECT ws.Guid
          FROM SCore.WorkflowStatus AS ws
          WHERE ws.ID IN (37,53,52,29,33,41)
          UNION ALL
          SELECT wt.Guid
          FROM SCore.WorkflowTransition AS wt
          WHERE wt.RowStatus = 254 OR wt.ID IN (395,349,439)
          UNION ALL
          SELECT wf.Guid
          FROM SCore.Workflow AS wf
          WHERE wf.RowStatus = 254
          UNION ALL
          SELECT ng.Guid
          FROM SCore.WorkflowStatusNotificationGroups AS ng
          WHERE ng.RowStatus = 254
                AND ng.ID <> -1
      )
  );

SELECT
    f.FailureCode,
    f.FailureDetail
FROM @Failures AS f
ORDER BY f.FailureCode, f.FailureDetail;

IF EXISTS (SELECT 1 FROM @Failures)
BEGIN
    THROW 61000, N'Workflow cleanup pre-validation failed. Review the returned failure rows.', 1;
END;

PRINT N'Workflow cleanup pre-validation passed.';

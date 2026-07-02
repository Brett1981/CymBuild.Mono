/*
    CymBuild Developer Inspector - read-only deployment smoke test.

    This script intentionally makes no schema or metadata changes.
    It exists so schema deployment can evidence that the resolver dependencies
    required by the DEV/QA-only inspector are present in the target database.
*/
SET NOCOUNT ON;

DECLARE @Missing TABLE
(
    ObjectName SYSNAME NOT NULL
);

INSERT @Missing (ObjectName)
SELECT N'SCore.EntityProperties'
WHERE OBJECT_ID(N'SCore.EntityProperties', N'U') IS NULL;

INSERT @Missing (ObjectName)
SELECT N'SCore.EntityHobts'
WHERE OBJECT_ID(N'SCore.EntityHobts', N'U') IS NULL;

INSERT @Missing (ObjectName)
SELECT N'SCore.EntityTypes'
WHERE OBJECT_ID(N'SCore.EntityTypes', N'U') IS NULL;

INSERT @Missing (ObjectName)
SELECT N'SCore.EntityDataTypes'
WHERE OBJECT_ID(N'SCore.EntityDataTypes', N'U') IS NULL;

INSERT @Missing (ObjectName)
SELECT N'SCore.DataObjects'
WHERE OBJECT_ID(N'SCore.DataObjects', N'U') IS NULL;

INSERT @Missing (ObjectName)
SELECT N'SCore.DataObjectTransition'
WHERE OBJECT_ID(N'SCore.DataObjectTransition', N'U') IS NULL;

INSERT @Missing (ObjectName)
SELECT N'SCore.WorkflowStatus'
WHERE OBJECT_ID(N'SCore.WorkflowStatus', N'U') IS NULL;

INSERT @Missing (ObjectName)
SELECT N'SUserInterface.DropDownListDefinitions'
WHERE OBJECT_ID(N'SUserInterface.DropDownListDefinitions', N'U') IS NULL;

IF EXISTS (SELECT 1 FROM @Missing)
BEGIN
    DECLARE @Message NVARCHAR(MAX) =
    (
        SELECT STRING_AGG(CONVERT(NVARCHAR(MAX), ObjectName), N', ')
        FROM @Missing
    );

    THROW 51000, @Message, 1;
END;

PRINT N'CymBuild Developer Inspector resolver dependencies are present.';

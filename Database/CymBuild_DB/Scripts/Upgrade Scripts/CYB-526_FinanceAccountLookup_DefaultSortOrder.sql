/*
    CYB-526 - The "LIVE_CRMSAGECOLOURAC" dropdown (SUserInterface.DropDownListDefinitions,
    Guid 0031902A-B82C-4B50-9B3D-194A5D30B931) backs FinanceAccountID and several other
    Sage-linked Account lookups (SCore.EntityProperties.DropDownListDefinitionID = 92). Its
    query is `SELECT TOP(10) ... FROM SCrm.LiveSageColourAccounts` with no ORDER BY and no
    DefaultSortColumnName configured, so the un-searched initial list returns an arbitrary,
    unordered 10 rows - it looks to users like the dropdown "isn't returning the full list of
    accounts" even though typing to search does correctly filter (the DropDownDataList
    pipeline in libs/Concursus.EF/UserInterface.cs appends a WHERE/ORDER BY around the base
    query regardless of DefaultSortColumnName being set).

    Fix: set DefaultSortColumnName to the same column already selected/displayed
    (ConcatenatedNameCode), so the initial TOP(10) is alphabetical and consistent, matching
    the pattern used by other dropdowns in this table.

    Idempotent by stable Guid: safe to re-run. Only this one row is affected.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET XACT_ABORT ON
GO

BEGIN TRANSACTION;

DECLARE @DropDownListDefinitionGuid UNIQUEIDENTIFIER = '0031902A-B82C-4B50-9B3D-194A5D30B931';
DECLARE @SortColumnName NVARCHAR(250) = N'ConcatenatedNameCode';
DECLARE @DropDownListDefinitionId INT;

SELECT
    @DropDownListDefinitionId = ddld.ID
FROM
    SUserInterface.DropDownListDefinitions AS ddld
WHERE
    ddld.Guid = @DropDownListDefinitionGuid
    AND ddld.RowStatus NOT IN (0, 254);

IF @DropDownListDefinitionId IS NULL
BEGIN
    THROW 51110, 'LIVE_CRMSAGECOLOURAC DropDownListDefinition (Guid 0031902A-B82C-4B50-9B3D-194A5D30B931) was not found. Cannot apply the default sort order.', 1;
END;

UPDATE ddld
SET
    ddld.DefaultSortColumnName = @SortColumnName
FROM
    SUserInterface.DropDownListDefinitions AS ddld
WHERE
    ddld.ID = @DropDownListDefinitionId
    AND ISNULL(ddld.DefaultSortColumnName, N'') <> @SortColumnName;

COMMIT TRANSACTION;
GO

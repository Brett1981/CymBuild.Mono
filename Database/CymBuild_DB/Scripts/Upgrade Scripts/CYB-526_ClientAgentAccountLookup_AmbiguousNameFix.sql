/*
    CYB-526 - The "LIVE_CRMACCOUNTS" dropdown (SUserInterface.DropDownListDefinitions,
    Guid 057273BC-3784-4F65-B0BD-D860D27D0667) backs ClientAccountID/AgentAccountID
    (SCore.EntityProperties.DropDownListDefinitionID = 62) - the "Client"/"Agent" fields on
    the Job tab.

    Its currently-deployed query (verified live in CymBuild_DEV, which differs from the
    source-controlled seed dump - this script brings the source of truth back in line) is:

        SELECT TOP(20) root_hobt.Guid, root_hobt.Name
        FROM SCrm.LiveAccounts root_hobt
        JOIN SCrm.Accounts ac ON (ac.Guid = root_hobt.Guid)
        JOIN SCrm.AccountStatus acs ON (ac.AccountStatusID = acs.ID)

    SCrm.LiveAccounts already joins to SCrm.AccountStatus internally and exposes Guid/
    RowStatus/Name on its own - the two extra joins to SCrm.Accounts/SCrm.AccountStatus
    contribute no column to the SELECT list and no WHERE condition, but SCrm.Accounts has
    its own Name column, so any unqualified `[Name]` reference (exactly what the generic
    dropdown search-filter builder in libs/Concursus.EF/Core.cs's CreatePropertyStatement
    produces - it does not table-qualify column names) becomes ambiguous between
    root_hobt.Name and ac.Name. Confirmed by reproducing the failing query directly against
    CymBuild_DEV: searching (typing in the combo) throws "Ambiguous column name 'Name'.";
    opening with no search text does not, because Name is then only referenced in the
    (unambiguous, output-list-resolved) ORDER BY, not a WHERE clause.

    Fix: drop the two redundant joins. Keeps the already-live TOP(20) (not reverting to the
    seed dump's TOP(10) - that part was never broken and is out of scope here).

    Idempotent by stable Guid: safe to re-run. Only this one row is affected.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET XACT_ABORT ON
GO

BEGIN TRANSACTION;

DECLARE @DropDownListDefinitionGuid UNIQUEIDENTIFIER = '057273BC-3784-4F65-B0BD-D860D27D0667';
DECLARE @NewSqlQuery NVARCHAR(MAX) = N'SELECT TOP(20)	root_hobt.Guid,
				root_hobt.Name
FROM	 SCrm.LiveAccounts root_hobt';
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
    THROW 51111, 'LIVE_CRMACCOUNTS DropDownListDefinition (Guid 057273BC-3784-4F65-B0BD-D860D27D0667) was not found. Cannot apply the ambiguous-column fix.', 1;
END;

UPDATE ddld
SET
    ddld.SqlQuery = @NewSqlQuery
FROM
    SUserInterface.DropDownListDefinitions AS ddld
WHERE
    ddld.ID = @DropDownListDefinitionId
    AND ISNULL(ddld.SqlQuery, N'') <> @NewSqlQuery;

COMMIT TRANSACTION;
GO

/*
    CYB-526 - A full sweep of every active SUserInterface.DropDownListDefinitions row (tested by
    reproducing, for each one, the exact search-filter shape the app builds at runtime - see
    libs/Concursus.EF/UserInterface.cs's DropDownDataList and Core.CreatePropertyStatement, which
    generates an UNQUALIFIED `[NameColumn]` reference with no table alias) found 4 dropdowns
    (beyond the already-fixed LIVE_CRMACCOUNTS/Guid 057273BC-3784-4F65-B0BD-D860D27D0667, and the
    already-fixed-for-sort-order-only LIVE_CRMSAGECOLOURAC) where a JOIN'd table exposes a second,
    real column with the exact same name as the dropdown's own NameColumn - so typing a search
    term throws "Ambiguous column name" and the UI silently shows "No matching records", even
    though the underlying data genuinely matches. Independently confirmed by Oliver in UAT for
    LIVE_CRMACCOUNTS, applied there as an untracked manual fix - this script (and the one for
    LIVE_CRMACCOUNTS already merged) is the source-controlled, idempotent equivalent so the same
    fix can be applied consistently to every environment.

    Each fix removes or narrows a JOIN to a derived table exposing only the columns the query
    actually uses - never behavior-changing, only removing an unused/colliding column from scope:

    1. MappedEntityProp (Guid 7A18B223-1408-4691-8E84-5A3BA2CCE266) - joins SCore.EntityQueries,
       which has its own Name column, colliding with root_hobt.Name (SCore.EntityProperties).
       eq.Name is never referenced; only eq.ID/Guid/EntityTypeID are.

    2. CrmAccounts (Guid BDE30F92-4CB9-4C53-A314-CB94747F0004) - joins SCrm.AccountStatus, which
       has its own Name column, colliding with root_hobt.Name (SCrm.Accounts). acs.Name IS used,
       in the WHERE clause's `acs.Name <> 'Prospect'` - renamed to acs.StatusName rather than
       removed. Used by 11 EntityProperties (ParentAccountID, Quote/Enquiry Client/AgentAccountId,
       Asset OwnerAccountID, Contact PrimaryAccountID, and others).

    3. AccountContact_Accou (Guid C056AC1D-2A30-474F-B37F-7385D8EF3B89, "account address" picker
       despite the Code) - joins SCrm.Addresses AND SCrm.Accounts, both of which have their own
       Name columns, colliding with each other (root_hobt/SCrm.AccountAddresses has no physical
       Name column at all - its "Name" is a SELECT-list-only computed alias, which is not a valid
       WHERE-clause target on its own). Fix moves the computed alias into a derived root_hobt
       subquery so it becomes a real, bindable, unambiguous output column - the narrower
       SCrm.Accounts join (acc) is also reduced to just the columns it actually uses (ID, Guid).

    4. LIVE_CRMSAGECOLOURAC (Guid 0031902A-B82C-4B50-9B3D-194A5D30B931) - already had its
       DefaultSortColumnName fixed by a separate CYB-526 script; this fixes a SEPARATE issue in
       the same row - it joins SCrm.Accounts, which also has a ConcatenatedNameCode column
       (colliding with root_hobt.ConcatenatedNameCode from SCrm.LiveSageColourAccounts). ac is
       narrowed to just Guid/AccountStatusID, which is all it's used for.

    Every fix verified directly against CymBuild_DEV: the exact rewritten query executes without
    error and returns the expected matching rows for a representative search term, where the
    unmodified query throws "Ambiguous column name" (or, for #3, "Invalid column name" once the
    ambiguity is naively removed without making Name a real bindable column).

    Idempotent by stable Guid: safe to re-run. Each UPDATE only fires if the stored SqlQuery
    doesn't already match.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET XACT_ABORT ON
GO

BEGIN TRANSACTION;

-- 1. MappedEntityProp
DECLARE @MappedEntityPropGuid UNIQUEIDENTIFIER = '7A18B223-1408-4691-8E84-5A3BA2CCE266';
DECLARE @MappedEntityPropSql NVARCHAR(MAX) = N'SELECT
        root_hobt.Guid,
        root_hobt.Name
FROM
        SCore.EntityProperties root_hobt
    JOIN
        SCore.EntityHoBTs      h
            ON (root_hobt.EntityHoBTID = h.ID)
    JOIN
        (SELECT ID, Guid, EntityTypeID FROM SCore.EntityQueries) eq
            ON (h.EntityTypeID = eq.EntityTypeID)
WHERE
        (
            (eq.Guid = ''[[ParentGuid]]'')
            AND (''[[ParentGuid]]'' != ''00000000-0000-0000-0000-000000000000'')
        )
        OR
            (
                (''[[ParentGuid]]'' = ''00000000-0000-0000-0000-000000000000'')
                AND ((EXISTS
    (
        SELECT
            1
        FROM
            SCore.EntityQueryParameters eqp
        WHERE
            (eqp.Guid = ''[[RecordGuid]]'')
            AND (eq.ID = eqp.EntityQueryID)
    )
                     )
                    )
            )';
DECLARE @MappedEntityPropId INT;

SELECT @MappedEntityPropId = ddld.ID FROM SUserInterface.DropDownListDefinitions AS ddld
WHERE ddld.Guid = @MappedEntityPropGuid AND ddld.RowStatus NOT IN (0, 254);

IF @MappedEntityPropId IS NULL
    THROW 51112, 'MappedEntityProp DropDownListDefinition (Guid 7A18B223-1408-4691-8E84-5A3BA2CCE266) was not found.', 1;

UPDATE ddld SET ddld.SqlQuery = @MappedEntityPropSql
FROM SUserInterface.DropDownListDefinitions AS ddld
WHERE ddld.ID = @MappedEntityPropId AND ISNULL(ddld.SqlQuery, N'') <> @MappedEntityPropSql;

-- 2. CrmAccounts
DECLARE @CrmAccountsGuid UNIQUEIDENTIFIER = 'BDE30F92-4CB9-4C53-A314-CB94747F0004';
DECLARE @CrmAccountsSql NVARCHAR(MAX) = N'SELECT  TOP(20) root_hobt.Guid, root_hobt.Name
FROM    SCrm.Accounts root_hobt
JOIN (SELECT ID, Name AS StatusName FROM SCrm.AccountStatus) as acs ON (root_hobt.AccountStatusID = acs.ID)
WHERE
		(root_hobt.Id = root_hobt.ID)
	AND (acs.StatusName <> N''Prospect'')';
DECLARE @CrmAccountsId INT;

SELECT @CrmAccountsId = ddld.ID FROM SUserInterface.DropDownListDefinitions AS ddld
WHERE ddld.Guid = @CrmAccountsGuid AND ddld.RowStatus NOT IN (0, 254);

IF @CrmAccountsId IS NULL
    THROW 51113, 'CrmAccounts DropDownListDefinition (Guid BDE30F92-4CB9-4C53-A314-CB94747F0004) was not found.', 1;

UPDATE ddld SET ddld.SqlQuery = @CrmAccountsSql
FROM SUserInterface.DropDownListDefinitions AS ddld
WHERE ddld.ID = @CrmAccountsId AND ISNULL(ddld.SqlQuery, N'') <> @CrmAccountsSql;

-- 3. AccountContact_Accou (AccountAddresses picker)
DECLARE @AccountAddressGuid UNIQUEIDENTIFIER = 'C056AC1D-2A30-474F-B37F-7385D8EF3B89';
DECLARE @AccountAddressSql NVARCHAR(MAX) = N'SELECT root_hobt.Id, root_hobt.Guid, root_hobt.Name
FROM (
    SELECT aa.Id, aa.Guid, aa.AddressID, aa.AccountID, aa.RowStatus,
           CONVERT(nvarchar(100), a.Number) + N'' - '' + a.FormattedAddressComma AS Name
    FROM SCrm.AccountAddresses aa
    JOIN SCrm.Addresses a ON (a.ID = aa.AddressID)
) root_hobt
JOIN (SELECT ID, Guid FROM SCrm.Accounts) acc ON (acc.ID = root_hobt.AccountID)
WHERE (root_hobt.RowStatus NOT IN (0, 254))
	AND	(acc.Guid = ''[[ParentGuid]]'')';
DECLARE @AccountAddressId INT;

SELECT @AccountAddressId = ddld.ID FROM SUserInterface.DropDownListDefinitions AS ddld
WHERE ddld.Guid = @AccountAddressGuid AND ddld.RowStatus NOT IN (0, 254);

IF @AccountAddressId IS NULL
    THROW 51114, 'AccountContact_Accou DropDownListDefinition (Guid C056AC1D-2A30-474F-B37F-7385D8EF3B89) was not found.', 1;

UPDATE ddld SET ddld.SqlQuery = @AccountAddressSql
FROM SUserInterface.DropDownListDefinitions AS ddld
WHERE ddld.ID = @AccountAddressId AND ISNULL(ddld.SqlQuery, N'') <> @AccountAddressSql;

-- 4. LIVE_CRMSAGECOLOURAC (separate issue from the DefaultSortColumnName fix already applied)
DECLARE @SageColourGuid UNIQUEIDENTIFIER = '0031902A-B82C-4B50-9B3D-194A5D30B931';
DECLARE @SageColourSql NVARCHAR(MAX) = N'SELECT TOP(10)
             root_hobt.ConcatenatedNameCode,
             root_hobt.Guid,
             root_hobt.ColourHex
FROM SCrm.LiveSageColourAccounts root_hobt
JOIN (SELECT Guid, AccountStatusID FROM SCrm.Accounts) ac ON (ac.Guid = root_hobt.Guid)
JOIN SCrm.AccountStatus acs ON (ac.AccountStatusID = acs.ID)
WHERE
		(acs.Name <> N''Prospect'')
	AND (acs.RowStatus NOT IN (0,254))';
DECLARE @SageColourId INT;

SELECT @SageColourId = ddld.ID FROM SUserInterface.DropDownListDefinitions AS ddld
WHERE ddld.Guid = @SageColourGuid AND ddld.RowStatus NOT IN (0, 254);

IF @SageColourId IS NULL
    THROW 51115, 'LIVE_CRMSAGECOLOURAC DropDownListDefinition (Guid 0031902A-B82C-4B50-9B3D-194A5D30B931) was not found.', 1;

UPDATE ddld SET ddld.SqlQuery = @SageColourSql
FROM SUserInterface.DropDownListDefinitions AS ddld
WHERE ddld.ID = @SageColourId AND ISNULL(ddld.SqlQuery, N'') <> @SageColourSql;

COMMIT TRANSACTION;
GO

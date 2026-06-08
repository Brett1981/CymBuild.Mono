BEGIN TRANSACTION;

/*
    Creates/repairs the SVC user if not already in the system.

    Important:
IF(EXISTS(SELECT 1 FROM SCore.Identities WHERE EmailAddress = N'SVC_Concursus@socotec.co.uk'))
	BEGIN
		DELETE FROM SCore.Identities WHERE EmailAddress = N'SVC_Concursus@socotec.co.uk'
	END
*/

DECLARE 
    @FullName NVARCHAR(250) = N'SVC_Concursus',
    @EmailAddress NVARCHAR(150) = N'SVC_Concursus@socotec.co.uk',
    @JobTitle NVARCHAR(50) = N'',
    @OrganisationalUnitGuid UNIQUEIDENTIFIER = N'B60A3EB9-7925-4B71-80B6-205CB2F9B742',
    @IsActive BIT = 1,
    @ContactGuid UNIQUEIDENTIFIER = N'00000000-0000-0000-0000-000000000000',
    @BillableRate DECIMAL(19,2) = 0.00,
    @Guid UNIQUEIDENTIFIER = N'1E7A4894-54AA-4CB4-9E54-C697ABB32F74';

IF EXISTS
(
    SELECT 1
    FROM SCore.Identities i
    WHERE i.EmailAddress = @EmailAddress
      AND i.Guid <> @Guid
      AND i.RowStatus NOT IN (0,254)
)
BEGIN
    ROLLBACK;
    THROW 60001, 'SVC_Concursus email already exists against a different active identity Guid. Manual data review required.', 1;
END;

IF EXISTS
(
    SELECT 1
    FROM SCore.DataObjects do
    WHERE do.Guid = @Guid
)
AND NOT EXISTS
(
    SELECT 1
    FROM SCore.Identities i
    WHERE i.Guid = @Guid
)
BEGIN
    DECLARE 
        @OrganisationalUnitId INT,
        @ContactId INT = NULL,
        @UserID INT;

    SELECT
        @OrganisationalUnitId = ou.ID
    FROM SCore.OrganisationalUnits ou
    WHERE ou.Guid = @OrganisationalUnitGuid
      AND ou.RowStatus NOT IN (0,254);

    SELECT
        @ContactId = c.ID
    FROM SCrm.Contacts c
    WHERE c.Guid = @ContactGuid
      AND c.RowStatus NOT IN (0,254);

    INSERT INTO SCore.Identities
    (
        Guid,
        RowStatus,
        FullName,
        EmailAddress,
        JobTitle,
        OriganisationalUnitId,
        ContactId,
        IsActive,
        BillableRate
    )
    VALUES
    (
        @Guid,
        1,
        @FullName,
        @EmailAddress,
        @JobTitle,
        @OrganisationalUnitId,
        @ContactId,
        @IsActive,
        @BillableRate
    );

    SET @UserID = SCOPE_IDENTITY();

    IF NOT EXISTS
    (
        SELECT 1
        FROM SCore.UserPreferences up
        WHERE up.ID = @UserID
    )
    BEGIN
        INSERT INTO SCore.UserPreferences
        (
            ID,
            Guid,
            RowStatus,
            SystemLanguageID
        )
        VALUES
        (
            @UserID,
            @Guid,
            1,
            1
        );
    END;
END;
ELSE
BEGIN
    EXEC SCore.IdentityUpsert
        @FullName,
        @EmailAddress,
        @JobTitle,
        @OrganisationalUnitGuid,
        @IsActive,
        @ContactGuid,
        @BillableRate,
        @Guid;
END;

COMMIT;
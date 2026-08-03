SET XACT_ABORT ON;
SET NOCOUNT ON;

/*
    CymBuild OnBoarding R2B F3
    Corrects the separation between:
      - SCore.EntityTypes.IsOnBoarding: global eligibility for additional entity types
      - SMigration.Onboarding_RunEntitySelections: run-specific scope selection

    Addresses and Contacts remain internal support/staged data for current OnBoarding procedures,
    but they are not top-level OnBoarding entity types.
*/

IF COL_LENGTH(N'SCore.EntityTypes', N'IsOnBoarding') IS NULL
BEGIN
    ALTER TABLE SCore.EntityTypes
        ADD IsOnBoarding BIT NOT NULL CONSTRAINT DF_EntityTypes_IsOnBoarding DEFAULT (0);
END;

UPDATE et
SET IsOnBoarding = 0
FROM SCore.EntityTypes AS et
WHERE et.RowStatus NOT IN (0,254)
  AND et.Name IN (N'Addresses', N'Contacts')
  AND ISNULL(et.IsOnBoarding, 0) <> 0;

IF OBJECT_ID(N'SMigration.Onboarding_EntityScope', N'U') IS NOT NULL
BEGIN
    UPDATE scopeRows
    SET
        RowStatus = 254,
        UpdatedUtc = SYSUTCDATETIME()
    FROM SMigration.Onboarding_EntityScope AS scopeRows
    WHERE scopeRows.RowStatus NOT IN (0,254)
      AND scopeRows.Code IN (N'Addresses', N'Contacts')
      AND scopeRows.StageTableName IN (N'SMigration.Onboarding_Addresses', N'SMigration.Onboarding_Contacts');
END;

IF OBJECT_ID(N'SMigration.OnboardingEntityScope_Seed', N'P') IS NOT NULL
BEGIN
    EXEC SMigration.OnboardingEntityScope_Seed;
END;
GO

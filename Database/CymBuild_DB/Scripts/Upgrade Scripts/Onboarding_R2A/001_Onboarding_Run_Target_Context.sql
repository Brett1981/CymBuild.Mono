SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'SMigration.Onboarding_Run', N'U') IS NOT NULL
BEGIN
    IF COL_LENGTH(N'SMigration.Onboarding_Run', N'SourceServerName') IS NULL
    BEGIN
        ALTER TABLE SMigration.Onboarding_Run
        ADD SourceServerName SYSNAME NOT NULL
            CONSTRAINT DF_SMigration_Onboarding_Run_SourceServerName DEFAULT (N'') WITH VALUES;
    END;

    IF COL_LENGTH(N'SMigration.Onboarding_Run', N'TargetServerName') IS NULL
    BEGIN
        ALTER TABLE SMigration.Onboarding_Run
        ADD TargetServerName SYSNAME NOT NULL
            CONSTRAINT DF_SMigration_Onboarding_Run_TargetServerName DEFAULT (N'') WITH VALUES;
    END;

    IF COL_LENGTH(N'SMigration.Onboarding_Run', N'TargetDatabaseName') IS NULL
    BEGIN
        ALTER TABLE SMigration.Onboarding_Run
        ADD TargetDatabaseName SYSNAME NOT NULL
            CONSTRAINT DF_SMigration_Onboarding_Run_TargetDatabaseName DEFAULT (N'') WITH VALUES;
    END;
END;
GO

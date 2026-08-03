SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'OnBoarding R4 F5 - add staged OU parent name')
GO

IF COL_LENGTH(N'SMigration.Onboarding_OrganisationalUnits', N'ParentOrganisationalUnitName') IS NULL
BEGIN
    ALTER TABLE SMigration.Onboarding_OrganisationalUnits
        ADD ParentOrganisationalUnitName NVARCHAR(250) NULL;
END;
GO

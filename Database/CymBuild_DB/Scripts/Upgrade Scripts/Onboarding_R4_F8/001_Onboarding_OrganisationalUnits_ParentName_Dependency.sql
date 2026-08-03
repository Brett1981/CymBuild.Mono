SET XACT_ABORT ON;
GO

PRINT (N'Ensure column [SMigration].[Onboarding_OrganisationalUnits].[ParentOrganisationalUnitName] exists')
GO

IF COL_LENGTH(N'SMigration.Onboarding_OrganisationalUnits', N'ParentOrganisationalUnitName') IS NULL
BEGIN
    ALTER TABLE [SMigration].[Onboarding_OrganisationalUnits]
        ADD [ParentOrganisationalUnitName] [nvarchar](250) NULL;
END;
GO

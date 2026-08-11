/*
    CymBuild Metadata Migration workbench schema bootstrap.

    This script is embedded into the controlled API/EF bootstrap path. It only
    creates the SMigration schema when it is absent and never changes schema
    ownership when the schema already exists.
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;
GO

IF SCHEMA_ID(N'SMigration') IS NULL
BEGIN
    EXEC sys.sp_executesql
        N'CREATE SCHEMA [SMigration] AUTHORIZATION [dbo];';
END;
GO

IF SCHEMA_ID(N'SMigration') IS NULL
    THROW 52920, 'Metadata Migration bootstrap could not create schema [SMigration].', 1;
GO

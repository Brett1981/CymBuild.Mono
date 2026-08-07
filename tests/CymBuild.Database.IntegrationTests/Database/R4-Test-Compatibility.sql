SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() NOT LIKE N'CymBuild[_]Test[_]%'
   AND DB_NAME() <> TRY_CONVERT(nvarchar(128), SESSION_CONTEXT(N'CYMBUILD_SQL_TEST_ALLOWED_DATABASE'))
BEGIN
    THROW 62030, N'R4 compatibility schema is restricted to CymBuild_Test_* databases.', 1;
END;

/*
    These empty compatibility tables satisfy deferred references in the current
    canonical SCore.UpsertDataObject and SCore.DataObjectTransitionUpsert bodies.
    The 22 R4 cases never enter these legacy Quote, Job, Enquiry, or default
    security branches. No business fixture rows are inserted into these tables.
*/

IF OBJECT_ID(N'SCore.ObjectSecurity', N'U') IS NULL
BEGIN
    CREATE TABLE SCore.ObjectSecurity
    (
        ID bigint IDENTITY NOT NULL,
        RowStatus tinyint NOT NULL,
        Guid uniqueidentifier NOT NULL,
        ObjectGuid uniqueidentifier NOT NULL,
        UserId int NOT NULL,
        GroupId int NOT NULL,
        CanRead bit NOT NULL,
        DenyRead bit NOT NULL,
        CanWrite bit NOT NULL,
        DenyWrite bit NOT NULL
    );
END;

IF OBJECT_ID(N'SJob.Jobs', N'U') IS NULL
BEGIN
    CREATE TABLE SJob.Jobs
    (
        ID int IDENTITY NOT NULL,
        RowStatus tinyint NOT NULL,
        Guid uniqueidentifier NOT NULL,
        JobDormant datetime2 NULL,
        JobCompleted datetime2 NULL,
        JobCancelled datetime2 NULL,
        DeadDate datetime2 NULL
    );
END;

IF OBJECT_ID(N'SSop.Enquiries', N'U') IS NULL
BEGIN
    CREATE TABLE SSop.Enquiries
    (
        ID int IDENTITY NOT NULL,
        RowStatus tinyint NOT NULL,
        Guid uniqueidentifier NOT NULL
    );
END;

IF OBJECT_ID(N'SSop.EnquiryServices', N'U') IS NULL
BEGIN
    CREATE TABLE SSop.EnquiryServices
    (
        ID int IDENTITY NOT NULL,
        RowStatus tinyint NOT NULL,
        Guid uniqueidentifier NOT NULL,
        EnquiryId int NOT NULL
    );
END;

IF OBJECT_ID(N'SSop.Quotes', N'U') IS NULL
BEGIN
    CREATE TABLE SSop.Quotes
    (
        ID int IDENTITY NOT NULL,
        RowStatus tinyint NOT NULL,
        Guid uniqueidentifier NOT NULL,
        EnquiryServiceID int NOT NULL
    );
END;

IF OBJECT_ID(N'SSop.QuoteItems', N'U') IS NULL
BEGIN
    CREATE TABLE SSop.QuoteItems
    (
        ID int IDENTITY NOT NULL,
        RowStatus tinyint NOT NULL,
        QuoteId int NOT NULL,
        CreatedJobId int NULL
    );
END;

IF OBJECT_ID(N'SSop.QuoteItemTotals', N'U') IS NULL
BEGIN
    CREATE TABLE SSop.QuoteItemTotals
    (
        ID int NOT NULL,
        LineNet decimal(19, 2) NULL
    );
END;

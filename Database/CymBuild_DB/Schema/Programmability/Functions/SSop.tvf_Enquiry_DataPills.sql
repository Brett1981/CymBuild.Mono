SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
PRINT (N'Create function [SSop].[tvf_Enquiry_DataPills]')
GO



CREATE FUNCTION [SSop].[tvf_Enquiry_DataPills]
(
    @Guid UNIQUEIDENTIFIER,
    @RowStatus TINYINT,
    @Number NVARCHAR(50),
    @AddressLine1 NVARCHAR(50),
    @AddressLine2 NVARCHAR(50),
    @AddressLine3 NVARCHAR(50),
    @Town NVARCHAR(50),
    @CountyGuid UNIQUEIDENTIFIER,
    @PostCode NVARCHAR(50),
    @ClientAccountGuid UNIQUEIDENTIFIER,
    @ClientName NVARCHAR(250),
    @AgentAccountGuid UNIQUEIDENTIFIER,
    @AgentName NVARCHAR(250),
    @ProjectGuid UNIQUEIDENTIFIER,
    @IsSubjectToNDA BIT,
    @FinanceAccountGuid UNIQUEIDENTIFIER,
    @UseClientAsFinance BIT,
    @ContractGuid UNIQUEIDENTIFIER,
    @AgentContractGuid UNIQUEIDENTIFIER
)
RETURNS @DataPills TABLE
(
    ID INT IDENTITY(1, 1) NOT NULL,
    Label NVARCHAR(50) NOT NULL,
    Class NVARCHAR(50) NOT NULL,
    SortOrder INT NOT NULL
)
 --WITH SCHEMABINDING
AS
   
BEGIN

    DECLARE @CountyName NVARCHAR(50);

    SELECT @CountyName = Name
    FROM SCrm.Counties
    WHERE Guid = @CountyGuid;

    -------------------------------------------------------------------------
    -- (Existing duplicate/property/account warnings) (preserved)
    -------------------------------------------------------------------------
    IF (
           @Number <> N''
        OR @AddressLine1 <> N''
        OR @AddressLine2 <> N''
        OR @AddressLine3 <> N''
        OR @Town <> N''
        OR @PostCode <> N''
       )
    BEGIN
        IF (EXISTS
        (
            SELECT 1
            FROM SJob.Assets AS p
            WHERE (DIFFERENCE(p.Number, @Number) = 4)
              AND (
                    @AddressLine1 IS NULL OR @AddressLine1 <> N''
                  AND p.AddressLine1 <> N''
                  AND DIFFERENCE(p.AddressLine1, @AddressLine1) = 4
                  )
              AND (
                    @AddressLine2 IS NULL OR @AddressLine2 <> N''
                  AND p.AddressLine2 <> N''
                  AND DIFFERENCE(p.AddressLine2, @AddressLine2) = 4
                  )
              AND (
                    @AddressLine3 IS NULL OR @AddressLine3 <> N''
                  AND p.AddressLine3 <> N''
                  AND DIFFERENCE(p.AddressLine3, @AddressLine3) = 4
                  )
              AND (
                    @Town IS NULL OR @Town <> N''
                  AND p.Town <> N''
                  AND DIFFERENCE(p.Town, @Town) = 4
                  )
              AND (
                    @PostCode IS NULL OR @PostCode <> N''
                  AND p.Postcode <> N''
                  AND DIFFERENCE(p.Postcode, @PostCode) = 4
                  )
              AND p.RowStatus NOT IN (0, 254)
              AND p.ID > 0
              AND p.Guid <> @Guid
        ))
        BEGIN
            INSERT @DataPills (Label, Class, SortOrder)
            VALUES (N'A similar property to this already exists!', N'bg-warning', 1);
        END
    END

    -------------------------------------------------------------------------
    -- Similar Accounts (REMOVED FULL-TEXT SEARCH entirely)
    -------------------------------------------------------------------------
    DECLARE @ClientNameNorm NVARCHAR(250) = NULL;
    DECLARE @AgentNameNorm  NVARCHAR(250) = NULL;

    IF (@ClientName IS NOT NULL AND LTRIM(RTRIM(@ClientName)) <> N'')
        SET @ClientNameNorm = UPPER(LTRIM(RTRIM(@ClientName)));

    IF (@AgentName IS NOT NULL AND LTRIM(RTRIM(@AgentName)) <> N'')
        SET @AgentNameNorm = UPPER(LTRIM(RTRIM(@AgentName)));

    -- Client similar account warning
    IF (@ClientAccountGuid = '00000000-0000-0000-0000-000000000000' AND @ClientNameNorm IS NOT NULL)
    BEGIN
        IF (EXISTS
        (
            SELECT 1
            FROM SCrm.Accounts AS a
            WHERE a.RowStatus NOT IN (0, 254)
              AND a.ID > 0
              AND a.Name IS NOT NULL
              AND
              (
                    DIFFERENCE(a.Name, @ClientNameNorm) >= 3
                 OR (LEN(@ClientNameNorm) >= 5 AND UPPER(a.Name) LIKE N'%' + @ClientNameNorm + N'%')
              )
        ))
        BEGIN
            INSERT @DataPills (Label, Class, SortOrder)
            VALUES (N'A similar account to the client already exists!', N'bg-warning', 1);
        END
    END

    -- Agent similar account warning
    IF (@AgentAccountGuid = '00000000-0000-0000-0000-000000000000' AND @AgentNameNorm IS NOT NULL)
    BEGIN
        IF (EXISTS
        (
            SELECT 1
            FROM SCrm.Accounts AS a
            WHERE a.RowStatus NOT IN (0, 254)
              AND a.ID > 0
              AND a.Name IS NOT NULL
              AND
              (
                    DIFFERENCE(a.Name, @AgentNameNorm) >= 3
                 OR (LEN(@AgentNameNorm) >= 5 AND UPPER(a.Name) LIKE N'%' + @AgentNameNorm + N'%')
              )
        ))
        BEGIN
            INSERT @DataPills (Label, Class, SortOrder)
            VALUES (N'A similar account to the agent already exists!', N'bg-warning', 1);
        END
    END

    -------------------------------------------------------------------------
    -- NDA (preserved)
    -------------------------------------------------------------------------
    IF (@ProjectGuid <> '00000000-0000-0000-0000-000000000000' AND @IsSubjectToNDA = 0)
    BEGIN
        SELECT @IsSubjectToNDA = p.IsSubjectToNDA
        FROM SSop.Projects AS p
        WHERE p.Guid = @ProjectGuid;
    END

    IF (@IsSubjectToNDA = 1)
    BEGIN
        INSERT @DataPills (Label, Class, SortOrder)
        VALUES (N'NDA', N'bg-danger', 1);
    END

    -------------------------------------------------------------------------
    -- Account hold pills (preserved)
    -------------------------------------------------------------------------
    IF (EXISTS
    (
        SELECT 1
        FROM SCrm.Accounts AS a
        JOIN SCrm.AccountStatus AS st ON st.ID = a.AccountStatusID
        WHERE a.Guid = @ClientAccountGuid
          AND st.IsHold = 1
    ))
    BEGIN
        INSERT @DataPills (Label, Class, SortOrder)
        VALUES (N'Client Account Hold', N'bg-danger', 1);
    END

    IF (EXISTS
    (
        SELECT 1
        FROM SCrm.Accounts AS a
        JOIN SCrm.AccountStatus AS st ON st.ID = a.AccountStatusID
        WHERE a.Guid = @AgentAccountGuid
          AND st.IsHold = 1
    ))
    BEGIN
        INSERT @DataPills (Label, Class, SortOrder)
        VALUES (N'Agent Account Hold', N'bg-danger', 1);
    END

    -------------------------------------------------------------------------
    -- Finance Credit Hold (preserved)
    -------------------------------------------------------------------------
    IF (EXISTS (SELECT 1 FROM SCrm.Accounts Ac WHERE Ac.Guid = @FinanceAccountGuid AND Ac.AccountStatusID = 4))
    BEGIN
        INSERT @DataPills (Label, Class, SortOrder)
        VALUES (N'Credit Hold', N'bg-danger', 1);
    END

    IF (@UseClientAsFinance = 1)
    BEGIN
        IF (EXISTS (SELECT 1 FROM SCrm.Accounts Ac WHERE Ac.Guid = @ClientAccountGuid AND Ac.AccountStatusID = 4))
        BEGIN
            INSERT @DataPills (Label, Class, SortOrder)
            VALUES (N'Credit Hold', N'bg-danger', 1);
        END
    END

    -------------------------------------------------------------------------
    -- Jobs pending creation (BUG FIXED: CORRELATED EXISTS) (preserved)
    -------------------------------------------------------------------------
    DECLARE @JobsToCreate INT;

    SELECT @JobsToCreate = COUNT(1)
    FROM SSop.Quote_JobsSummary AS js
    JOIN SSop.Quotes AS q ON q.Guid = js.QuoteGuid
    JOIN SSop.EnquiryService_ExtendedInfo AS esei ON esei.QuoteID = q.ID
    JOIN SSop.EnquiryServices AS es ON es.ID = esei.Id
    JOIN SSop.Enquiries AS e ON e.ID = es.EnquiryId
    WHERE e.Guid = @Guid
      AND q.ID > 0
      AND q.DateAccepted IS NOT NULL
      AND EXISTS
      (
          SELECT 1
          FROM SSop.QuoteItems AS qi
          WHERE qi.QuoteId = q.ID
            AND qi.CreatedJobId < 0
            AND qi.RowStatus NOT IN (0, 254)
      );

    IF (@JobsToCreate > 0)
    BEGIN
        INSERT @DataPills (Label, Class, SortOrder)
        VALUES (CONVERT(NVARCHAR(50), @JobsToCreate) + N' job(s) pending creation.', N'bg-warning', 1);
    END

    -------------------------------------------------------------------------
    -- Latest enquiry workflow status (GUID) for colour hardening
    -------------------------------------------------------------------------
    DECLARE @LatestEnquiryStatusGuid UNIQUEIDENTIFIER = NULL;

    SELECT TOP (1)
        @LatestEnquiryStatusGuid = wfs.Guid
    FROM SCore.DataObjectTransition dot
    JOIN SCore.WorkflowStatus wfs ON wfs.ID = dot.StatusID
    WHERE dot.DataObjectGuid = @Guid
      AND dot.RowStatus NOT IN (0,254)
      AND wfs.RowStatus NOT IN (0,254)
    ORDER BY dot.DateTimeUTC DESC, dot.ID DESC;

    -------------------------------------------------------------------------
    -- Enquiry status pill (label preserved; colour mapping hardened)
    -------------------------------------------------------------------------
    INSERT @DataPills (Label, Class, SortOrder)
    SELECT
        ecf1.EnquiryStatus,
        CASE
            WHEN ecf1.EnquiryStatus IN (N'Complete', N'Accepted') THEN N'bg-success'
            WHEN ecf1.EnquiryStatus IN (N'Part Complete', N'Ready to Send', N'Ready To Send', N'Deadline Approaching') THEN N'bg-warning'
            WHEN @LatestEnquiryStatusGuid IS NOT NULL
                 AND @LatestEnquiryStatusGuid IN
                 (
                     CONVERT(UNIQUEIDENTIFIER, '02A2237F-2AE7-4E05-926F-38E8B7D050A0')
                 )
            THEN N'bg-warning'
            WHEN ecf1.EnquiryStatus IN (N'Rejected', N'Declined', N'Dead', N'Deadline Missed', N'Expired') THEN N'bg-danger'
            ELSE N'bg-info'
        END,
        1
    FROM SSop.Enquiries AS e
    OUTER APPLY (SELECT EnquiryStatus FROM SSop.Enquiry_CalculatedFields AS ecf WHERE ecf.ID = e.ID) AS ecf1
    WHERE e.Guid = @Guid;

    -------------------------------------------------------------------------
    -- Contract pills (preserved)
    -------------------------------------------------------------------------
    IF(@ContractGuid <> '00000000-0000-0000-0000-000000000000'
       OR @AgentContractGuid <> '00000000-0000-0000-0000-000000000000')
    BEGIN
        INSERT @DataPills (Label, Class, SortOrder)
        VALUES (N'Contract In Place', N'bg-warning', 2);

        DECLARE @EndDate DATE, @NextReviewDate DATE;

        IF(@ContractGuid <> '00000000-0000-0000-0000-000000000000')
        BEGIN
            SELECT @EndDate = EndDate, @NextReviewDate = NextReviewDate
            FROM SSop.Contracts
            WHERE Guid = @ContractGuid;
        END
        ELSE
        BEGIN
            SELECT @EndDate = EndDate, @NextReviewDate = NextReviewDate
            FROM SSop.Contracts
            WHERE Guid = @AgentContractGuid;
        END

        IF (@EndDate IS NOT NULL AND DATEDIFF(DAY, GETDATE(), @EndDate) <= 30)
        BEGIN
            INSERT @DataPills (Label, Class, SortOrder)
            VALUES (N'Contract Ending In ' + CONVERT(NVARCHAR(10), DATEDIFF(DAY, GETDATE(), @EndDate)) + N' Days', N'bg-danger', 8);
        END

        IF (@NextReviewDate IS NOT NULL AND DATEDIFF(DAY, GETDATE(), @NextReviewDate) <= 30)
        BEGIN
            INSERT @DataPills (Label, Class, SortOrder)
            VALUES (N'Contract Needs Reviewing By ' + CONVERT(NVARCHAR(10), @NextReviewDate, 23), N'bg-danger', 9);
        END
    END

    -------------------------------------------------------------------------
    -- Latest-only: User Action Required / Customer Waiting (preserved)
    -------------------------------------------------------------------------
    DECLARE @LatestRequiresUsersAction BIT = 0;
    DECLARE @LatestIsCustomerWaiting BIT = 0;

    SELECT TOP (1)
        @LatestRequiresUsersAction = ISNULL(wfs.RequiresUsersAction, 0),
        @LatestIsCustomerWaiting   = ISNULL(wfs.IsCustomerWaitingStatus, 0)
    FROM SCore.DataObjectTransition dot
    JOIN SCore.WorkflowStatus wfs ON wfs.ID = dot.StatusID
    WHERE dot.DataObjectGuid = @Guid
      AND dot.RowStatus NOT IN (0,254)
      AND wfs.RowStatus NOT IN (0,254)
    ORDER BY dot.DateTimeUTC DESC, dot.ID DESC;

    IF (@LatestRequiresUsersAction = 1)
    BEGIN
        INSERT @DataPills (Label, Class, SortOrder)
        VALUES (N'User Action Required', N'bg-warning', 0);
    END

    IF (@LatestIsCustomerWaiting = 1)
    BEGIN
        INSERT @DataPills (Label, Class, SortOrder)
        VALUES (N'Awaiting Customer', N'bg-warning', 0);
    END

    RETURN;
END
GO
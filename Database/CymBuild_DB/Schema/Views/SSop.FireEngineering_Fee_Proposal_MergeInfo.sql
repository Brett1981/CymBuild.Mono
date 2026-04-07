SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SSop].[FireEngineering_Fee_Proposal_MergeInfo]
    --WITH SCHEMABINDING
AS
SELECT
    /* QUOTE */
    q.ID,
    q.RowStatus,
    q.RowVersion,
    q.Guid,
    q.Number AS QuoteNumber,
    e.DescriptionOfWorks AS QuoteOverview,
    ISNULL(CONVERT(NVARCHAR(10), q.Date, 103), '') AS QuoteDate,
    ISNULL(CONVERT(NVARCHAR(11), CASE
        WHEN LatestWorkflowStatus.Guid = Statuses.Sent OR q.DateSent IS NOT NULL
            THEN LatestWorkflowStatus.Date
        ELSE GETDATE()
    END , 106), '') AS QuoteDateSent,
    ISNULL(CONVERT(NVARCHAR(2), q.RevisionNumber), '0') AS RevisionNumber,
    q.FeeCap,

    ISNULL(CONVERT(NVARCHAR(11), CASE
        WHEN LatestWorkflowStatus.Guid = Statuses.Sent OR q.DateSent IS NOT NULL
            THEN LatestWorkflowStatus.Date
        ELSE GETDATE()
    END , 106), '') AS DateQuoteSent,

    /* PROJECT (concat-safe) */
    RTRIM(REPLACE(projAgg.ProjectName, ' -','')) AS ProjectName,

    /* STRUCTURE */
    uprn.Number AS UPRN,
    uprn.AddressLine1 AS PropertyAddressLine1,
    uprn.AddressLine2 AS PropertyAddressLine2,
    uprn.AddressLine3 AS PropertyAddressLine3,
    uprn.Town         AS PropertyTown,
    uprnc.Name        AS PropertyCounty,
    uprn.Postcode     AS PropertyPostcode,
    uprn.FormattedAddressComma AS PropertyAddress,
    uprn.FormattedAddressCR    AS PropertyAddressBlock,
    COALESCE(uprn.Name + ' ', '') + COALESCE(uprn.Number + ' ', '') + uprn.AddressLine1 AS PropertyShortAddress,

    /* Client */
    LTRIM(cacc.Name) AS ClientName,
    cacc.CompanyRegistrationNumber AS ClientCompanyRegNo,
    cadd.AddressLine1 AS ClientAddressLine1,
    cadd.AddressLine2 AS ClientAddressLine2,
    cadd.AddressLine3 AS ClientAddressLine3,
    cadd.Town         AS ClientTown,
    caddc.Name        AS ClientCounty,
    cadd.Postcode     AS ClientPostcode,
    cadd.FormattedAddressComma AS ClientAddress,
    cadd.FormattedAddressCR    AS ClientAddressBlock,
    ccon.DisplayName  AS ClientContactName,
    ccon.FirstName    AS ClientFirstName,
    ccon.Surname      AS ClientSurname,
    ISNULL(ccon.Email  , '')      AS ClientEmail,
    ISNULL(ccon.Phone  , '')      AS ClientPhone,
    ISNULL(ccon.Mobile , '')      AS ClientMobile,

    CASE WHEN q.SendInfoToClient = 1 THEN cacc.Name ELSE aacc.Name END AS RecipientName,
    CASE WHEN q.SendInfoToClient = 1 THEN cacc.CompanyRegistrationNumber ELSE aacc.CompanyRegistrationNumber END AS RecipientCompanyRegNo,
    CASE WHEN q.SendInfoToClient = 1 THEN cadd.AddressLine1 ELSE aadd.AddressLine1 END AS RecipientAddressLine1,
    CASE WHEN q.SendInfoToClient = 1 THEN cadd.AddressLine2 ELSE aadd.AddressLine2 END AS RecipientAddressLine2,
    CASE WHEN q.SendInfoToClient = 1 THEN cadd.AddressLine3 ELSE aadd.AddressLine3 END AS RecipientAddressLine3,
    CASE WHEN q.SendInfoToClient = 1 THEN cadd.Town        ELSE aadd.Town        END AS RecipientTown,
    CASE WHEN q.SendInfoToClient = 1 THEN caddc.Name       ELSE aaddc.Name       END AS RecipientCounty,
    CASE WHEN q.SendInfoToClient = 1 THEN cadd.Postcode    ELSE aadd.Postcode    END AS RecipientPostcode,
    CASE WHEN q.SendInfoToClient = 1 THEN cadd.FormattedAddressComma ELSE aadd.FormattedAddressComma END AS RecipientAddress,
    CASE WHEN q.SendInfoToClient = 1 THEN cadd.FormattedAddressCR    ELSE aadd.FormattedAddressCR    END AS RecipientAddressBlock,
    CASE WHEN q.SendInfoToClient = 1 THEN ccon.DisplayName ELSE acon.DisplayName END AS RecipientContactName,
    CASE WHEN q.SendInfoToClient = 1 THEN ccon.FirstName   ELSE acon.FirstName   END AS RecipientFirstName,
    CASE WHEN q.SendInfoToClient = 1 THEN ccon.Surname     ELSE acon.Surname     END AS RecipientSurname,
    ISNULL(CASE WHEN q.SendInfoToClient = 1 THEN ccon.Email       ELSE acon.Email       END , '') AS RecipientEmail,
    ISNULL(CASE WHEN q.SendInfoToClient = 1 THEN ccon.Phone       ELSE acon.Phone       END , '') AS RecipientPhone,
    ISNULL(CASE WHEN q.SendInfoToClient = 1 THEN ccon.Mobile      ELSE acon.Mobile      END , '') AS RecipientMobile,

    /* Company */
    offa.Name        AS OfficialName,
    offa.AddressLine1 AS OfficialAddressLine1,
    offa.AddressLine2 AS OfficialAddressLine2,
    offa.AddressLine3 AS OfficialAddressLine3,
    offa.Town         AS OfficialTown,
    offac.Name        AS OfficialCounty,
    offa.Postcode     AS OfficialPostcode,
    offcon.Email      AS OfficialEmail,
    offcon.Phone      AS OfficialPhone,
    offcon.Mobile     AS OfficialMobile,

    /* Fee Drawdown */
    DrawDown.Stage1Net,
    DrawDown.Stage2Net,
    DrawDown.Stage3Net,
    DrawDown.Stage4Net,
    DrawDown.Stage5Net,
    DrawDown.Stage6Net,
    DrawDown.Stage7Net,
    DrawDown.PreConstruction,
    DrawDown.Construction,
    DrawDown.Stage1Net + DrawDown.Stage2Net + DrawDown.Stage3Net + DrawDown.Stage4Net + DrawDown.Stage5Net
    + DrawDown.Stage6Net + DrawDown.Stage7Net + DrawDown.PreConstruction + DrawDown.Construction AS TotalNetFees,

    /* Quoting User */
    quconm.Email AS QuotingUserEmail,
    qu.FullName  AS QuotingUserName,
    qu.FullName + N' ' + COALESCE(qucon.PostNominals, '') AS QuotingUserPostNominals,
    qucon.Initials AS QuotingUserInitials,
    qu.JobTitle    AS QuotingUserJobTitle,

    qcconm.Email AS QuotingConsultantEmail,
    qc.FullName  AS QuotingConsultantName,
    qc.FullName + N' ' + COALESCE(qccon.PostNominals, '') AS QuotingConsultantPostNominals,
    qccon.Initials AS QuotingConsultantInitials,
    qc.JobTitle    AS QuotingConsultantJobTitle,

    aacc.Name             AS AgentAccountName,
    aacon.DisplayName     AS AgentContact,
    aaconadd.AddressLine1 AS AgentAddressLineOne,
    aaconadd.AddressLine2 AS AgentAddressLineTwo,
    aaconadd.AddressLine3 AS AgentAddressLineThree,
    aaconadd.Postcode     AS AgentPostcode,

    cacc.Name             AS ClientAccountName,
    cacon.DisplayName     AS ClientContact,
    caconadd.AddressLine1 AS ClientAddressLineOne,
    caconadd.AddressLine2 AS ClientAddressLineTwo,
    caconadd.AddressLine3 AS ClientAddressLineThree

FROM SSop.Quotes AS q
JOIN SSop.EnquiryServices AS es ON es.ID = q.EnquiryServiceID
JOIN SSop.Enquiries       AS e  ON e.ID  = es.EnquiryId
JOIN SCore.OrganisationalUnits AS ou ON ou.ID = q.OrganisationalUnitID
JOIN SCrm.Contact_MergeInfo AS offcon ON offcon.ID = ou.OfficialContactId
JOIN SCrm.Addresses        AS offa   ON offa.ID = ou.OfficialAddressId
JOIN SCrm.Counties         AS offac  ON offac.ID = offa.CountyID
JOIN SJob.Assets           AS uprn   ON uprn.ID = e.PropertyId
JOIN SCrm.Counties         AS uprnc  ON uprnc.ID = uprn.CountyId
JOIN SCrm.Accounts         AS cacc   ON cacc.ID = e.ClientAccountId
JOIN SCrm.AccountAddresses AS caad   ON caad.ID = e.ClientAddressId
JOIN SCrm.Addresses        AS cadd   ON cadd.ID = caad.AddressID
JOIN SCrm.AccountContacts  AS cac    ON cac.ID = e.ClientAccountContactId
JOIN SCrm.Contact_MergeInfo AS ccon  ON ccon.ID = cac.ContactID
JOIN SCrm.Counties         AS caddc  ON caddc.ID = cadd.CountyID
JOIN SCore.Identities      AS qu     ON qu.ID = q.QuotingUserId
JOIN SCrm.Accounts         AS aacc   ON aacc.ID = e.AgentAccountId
JOIN SCrm.AccountAddresses AS aaad   ON aaad.ID = e.AgentAddressId
JOIN SCrm.Addresses        AS aadd   ON aadd.ID = aaad.AddressID
JOIN SCrm.AccountContacts  AS aac    ON aac.ID = e.AgentAccountContactId
JOIN SCrm.Contact_MergeInfo AS acon  ON acon.ID = aac.ContactID
JOIN SCrm.Counties         AS aaddc  ON aaddc.ID = aadd.CountyID
LEFT JOIN SCrm.Contacts        AS qucon  ON qucon.ID = qu.ContactId
LEFT JOIN SCrm.Contact_MergeInfo AS quconm ON quconm.ID = qucon.ID
JOIN SCore.Identities      AS qc     ON qc.ID = q.QuotingConsultantId
LEFT JOIN SCrm.Contacts        AS qccon  ON qccon.ID = qc.ContactId
LEFT JOIN SCrm.Contact_MergeInfo AS qcconm ON qcconm.ID = qccon.ID
JOIN SCrm.Contacts         AS aacon  ON aacon.ID = aac.ContactID
JOIN SCrm.Addresses        AS aaconadd ON aaconadd.ID = aaad.AddressID
JOIN SCrm.Contacts         AS cacon  ON cacon.ID = cac.ContactID
JOIN SCrm.Addresses        AS caconadd ON caconadd.ID = caad.AddressID

/* FIX: project lookup must reference proj table; concat-safe in case of data issues */
OUTER APPLY
(
    SELECT
        ProjectName =
            STUFF((
                SELECT DISTINCT
                    ',' + p.ProjectDescription
                FROM SSop.Projects p
                WHERE p.ID = q.ProjectId   -- or p.ID = e.ProjectId if that’s the canonical relationship
                FOR XML PATH(''), TYPE
            ).value('.', 'nvarchar(max)'), 1, 1, '')
) AS projAgg

OUTER APPLY
(
    SELECT
        ID,
        ISNULL([1],   0) AS Stage1Net,
        ISNULL([2],   0) AS Stage2Net,
        ISNULL([3],   0) AS Stage3Net,
        ISNULL([4],   0) AS Stage4Net,
        ISNULL([5],   0) AS Stage5Net,
        ISNULL([6],   0) AS Stage6Net,
        ISNULL([7],   0) AS Stage7Net,
        ISNULL([99],  0) AS PreConstruction,
        ISNULL([999], 0) AS Construction
    FROM
    (
        SELECT ID, Stage, Quoted
        FROM SSop.tvf_QuoteFeeDrawdown(q.QuotingUserId, q.Guid)
    ) AS d
    PIVOT
    (
        MIN(Quoted) FOR Stage IN ([1],[2],[3],[4],[5],[6],[7],[99],[999])
    ) AS qfd
) AS DrawDown

OUTER APPLY
(
    SELECT
        Declined    = CONVERT(UNIQUEIDENTIFIER, '708C00E6-F45F-4CB2-8E91-A80B8B8E802E'),
        Dead        = CONVERT(UNIQUEIDENTIFIER, '8C7F7526-559F-4CCF-8FC2-DB0DA67E793D'),
        Accepted    = CONVERT(UNIQUEIDENTIFIER, '21A29AEE-2D99-4DA3-8182-F31813B0C498'),
        ReadyToSend = CONVERT(UNIQUEIDENTIFIER, '02A2237F-2AE7-4E05-926F-38E8B7D050A0'),
        Rejected    = CONVERT(UNIQUEIDENTIFIER, '0A6A71F7-B39F-4213-997E-2B3A13B6144C'),
        Sent        = CONVERT(UNIQUEIDENTIFIER, '25D5491C-42A8-4B04-B3AC-D648AF0F8032')
) AS Statuses

OUTER APPLY
(
    SELECT TOP (1)
        Name = wfs.Name,
        Guid = wfs.Guid,
        Date = dot.DateTimeUTC
    FROM SCore.DataObjectTransition dot
    JOIN SCore.WorkflowStatus wfs ON wfs.ID = dot.StatusID
    WHERE dot.DataObjectGuid = q.Guid
      AND dot.RowStatus NOT IN (0,254)
      AND wfs.RowStatus NOT IN (0,254)
    ORDER BY dot.DateTimeUTC DESC, dot.ID DESC
) AS LatestWorkflowStatus;
GO
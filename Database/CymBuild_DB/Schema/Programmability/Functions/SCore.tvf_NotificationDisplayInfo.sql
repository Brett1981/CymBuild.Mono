SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SCore].[tvf_NotificationDisplayInfo]')
GO



/* =============================================================================
   SCore.tvf_NotificationDisplayInfo

   Purpose:
   - Central, canonical "display fields" resolver for Kafka workflow notifications
     (Option A: enrich in publisher worker via a single SQL call).

   Inputs:
   - @EntityTypeId: SCore.EntityTypes.ID (helps choose best branch, but function is robust)
   - @RecordGuid:   DataObjectGuid / record Guid

   Output:
   - Single row with DisplayRef, DisplayTitle, DisplayOrganisationName, DisplayProjectName,
     DisplayClientName, DisplayAgentName, DisplayAddress
============================================================================= */
CREATE FUNCTION [SCore].[tvf_NotificationDisplayInfo]
(
      @EntityTypeId INT
    , @RecordGuid   UNIQUEIDENTIFIER
)
RETURNS TABLE
AS
RETURN
(
    /* -----------------------------
       1) ENQUIRIES (EntityTypeId=83)
       ----------------------------- */
    SELECT TOP (1)
          CAST(em.EnquiryNumber AS NVARCHAR(50))                           AS DisplayRef
        , NULLIF(LTRIM(RTRIM(em.DescriptionOfWorks)), N'')                 AS DisplayTitle
        , ou.Name                                                         AS DisplayOrganisationName
        , prj.ProjectDescription                                           AS DisplayProjectName
        , NULLIF(LTRIM(RTRIM(em.ClientName)), N'')                         AS DisplayClientName
        , NULLIF(LTRIM(RTRIM(em.AgentName)), N'')                          AS DisplayAgentName
        , NULLIF(LTRIM(RTRIM(em.PropertyAddress)), N'')                    AS DisplayAddress
        , NULLIF(LTRIM(RTRIM(em.DescriptionOfWorks)), N'')                 AS Description
    FROM SSop.Enquiry_MergeInfo em
    JOIN SSop.Enquiries e
        ON e.RowStatus NOT IN (0,254)
       AND e.Guid = em.Guid
    LEFT JOIN SCore.OrganisationalUnits ou
        ON ou.RowStatus NOT IN (0,254)
       AND ou.ID = e.OrganisationalUnitID
    LEFT JOIN SSop.Projects prj
        ON prj.RowStatus NOT IN (0,254)
       AND prj.ID = e.ProjectId
    WHERE em.RowStatus NOT IN (0,254)
      AND em.Guid = @RecordGuid
      AND (@EntityTypeId = 83 OR @EntityTypeId IS NULL)

    UNION ALL

    /* -----------------------------
       2) QUOTES (EntityTypeId varies)
       Robust fallback if entityTypeId not known.
       ----------------------------- */
    SELECT TOP (1)
          CAST(qm.QuoteNumber AS NVARCHAR(50))                              AS DisplayRef
        , NULLIF(LTRIM(RTRIM(qm.QuoteOverview)), N'')                       AS DisplayTitle
        , ou.Name                                                          AS DisplayOrganisationName
        , prj.ProjectDescription                                            AS DisplayProjectName
        , NULLIF(LTRIM(RTRIM(qm.ClientName)), N'')                          AS DisplayClientName
        , NULLIF(LTRIM(RTRIM(qm.RecipientName)), N'')                       AS DisplayAgentName
        , NULLIF(LTRIM(RTRIM(qm.PropertyAddress)), N'')                     AS DisplayAddress
        , NULLIF(LTRIM(RTRIM(q.DescriptionOfWorks)), N'')                   AS Description
    FROM SSop.Quote_MergeInfo qm
    JOIN SSop.Quotes q
        ON q.RowStatus NOT IN (0,254)
       AND q.Guid = qm.Guid
    LEFT JOIN SCore.OrganisationalUnits ou
        ON ou.RowStatus NOT IN (0,254)
       AND ou.ID = q.OrganisationalUnitID
    /* Quote_MergeInfo comes from Enquiry/Service; safest project source is the underlying Enquiry */
    LEFT JOIN SSop.EnquiryServices es
        ON es.RowStatus NOT IN (0,254)
       AND es.ID = q.EnquiryServiceID
    LEFT JOIN SSop.Enquiries e
        ON e.RowStatus NOT IN (0,254)
       AND e.ID = es.EnquiryId
    LEFT JOIN SSop.Projects prj
        ON prj.RowStatus NOT IN (0,254)
       AND prj.ID = e.ProjectId
    WHERE qm.RowStatus NOT IN (0,254)
      AND qm.Guid = @RecordGuid

    UNION ALL

    /* -----------------------------
       3) JOBS (EntityTypeId=9 per your worker mapping)
       ----------------------------- */
    SELECT TOP (1)
          CAST(j.Number AS NVARCHAR(50))                                    AS DisplayRef
        , NULLIF(LTRIM(RTRIM(j.JobDescription)), N'')                       AS DisplayTitle
        , ou.Name                                                          AS DisplayOrganisationName
        , prj.ProjectDescription                                           AS DisplayProjectName
        , cli.Name                                                         AS DisplayClientName
        , agt.Name                                                         AS DisplayAgentName
        , a.FormattedAddressComma                                           AS DisplayAddress
        , NULLIF(LTRIM(RTRIM(j.BillingInstruction)), N'')                       AS Description
    FROM SJob.Jobs j
    LEFT JOIN SCore.OrganisationalUnits ou
        ON ou.RowStatus NOT IN (0,254)
       AND ou.ID = j.OrganisationalUnitID
    LEFT JOIN SSop.Projects prj
        ON prj.RowStatus NOT IN (0,254)
       AND prj.ID = j.ProjectId
    LEFT JOIN SCrm.Accounts cli
        ON cli.RowStatus NOT IN (0,254)
       AND cli.ID = j.ClientAccountID
    LEFT JOIN SCrm.Accounts agt
        ON agt.RowStatus NOT IN (0,254)
       AND agt.ID = j.AgentAccountID
    LEFT JOIN SJob.Assets a
        ON a.RowStatus NOT IN (0,254)
       AND a.ID = j.UprnID
    WHERE j.RowStatus NOT IN (0,254)
      AND j.Guid = @RecordGuid
      AND (@EntityTypeId = 9 OR @EntityTypeId IS NULL)
);
GO
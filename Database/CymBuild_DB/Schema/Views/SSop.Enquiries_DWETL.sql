SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create view [SSop].[Enquiries_DWETL]')
GO



CREATE OR ALTER VIEW [SSop].[Enquiries_DWETL]
     --WITH SCHEMABINDING
AS
SELECT
    e.ID,
    e.Number,
    e.CreatedByUserId SurveyorId,
    e.ClientAccountId,
    e.OrganisationalUnitID,
    ou.Name as OUName,
    ISNULL(enquiry_value.net, 0) value,
    e.date,
    wfd_current_status.Name as status
FROM SSop.Enquiries e
JOIN SCore.OrganisationalUnits ou
    ON ou.ID = e.OrganisationalUnitID

-- Net: aggregate section totals WITHOUT joining to items
OUTER APPLY
(
    SELECT
        SUM(es_xi.QuoteNet) AS Net
    FROM SSop.EnquiryServices es
    JOIN SSop.EnquiryService_ExtendedInfo es_xi on (es.id = es_xi.Id)
    WHERE es.EnquiryId = e.ID
      AND es.RowStatus NOT IN (0,254)
) enquiry_value

-- Workflow date for Sent (by GUID)
OUTER APPLY
(
    SELECT TOP (1)
        dot.DateTimeUTC AS DateSentUtc,
        wfs.Name,
        wfs.Guid AS StatusGuid
    FROM SCore.DataObjectTransition dot
    JOIN SCore.WorkflowStatus wfs ON wfs.ID = dot.StatusID
    WHERE dot.RowStatus NOT IN (0,254)
      AND wfs.RowStatus NOT IN (0,254)
      AND dot.DataObjectGuid = e.Guid
    ORDER BY dot.DateTimeUTC DESC, dot.ID DESC
) AS wfd_current_status
WHERE
        e.RowStatus NOT IN (0,254)
    AND ou.RowStatus NOT IN (0,254)

    -- CYB-553-SHORE-LEGACY-EXCLUSION: leave out Shore CDM legacy enquiries
    -- (their quote has LegacySystemID 1) that were never converted to a job and
    -- are now Expired; the business asked for these to be removed from reporting.
    AND NOT
    (
        ISNULL(wfd_current_status.StatusGuid, '00000000-0000-0000-0000-000000000000') = 'E6FAC201-F98B-4B3A-AB55-83DC9F802D00' -- Expired
        AND EXISTS
        (
            SELECT 1
            FROM SSop.EnquiryServices AS legacyService
            JOIN SSop.Quotes AS legacyQuote
                ON legacyQuote.EnquiryServiceID = legacyService.ID
               AND legacyQuote.RowStatus NOT IN (0,254)
            WHERE legacyService.EnquiryId = e.ID
              AND legacyService.RowStatus NOT IN (0,254)
              AND legacyQuote.LegacySystemID = 1
        )
        AND NOT EXISTS
        (
            SELECT 1
            FROM SSop.EnquiryServices AS legacyService
            JOIN SSop.Quotes AS legacyQuote
                ON legacyQuote.EnquiryServiceID = legacyService.ID
               AND legacyQuote.RowStatus NOT IN (0,254)
            JOIN SSop.QuoteItems AS legacyItem
                ON legacyItem.QuoteId = legacyQuote.ID
               AND legacyItem.RowStatus NOT IN (0,254)
               AND legacyItem.CreatedJobId > 0
            WHERE legacyService.EnquiryId = e.ID
              AND legacyService.RowStatus NOT IN (0,254)
        )
    )


GO
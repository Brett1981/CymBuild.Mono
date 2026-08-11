SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SJob].[AssetDuplicateCheck]')
GO
PRINT (N'Create function [SJob].[AssetDuplicateCheck]')
GO

/*
USUAGE:

SELECT
    r.SourceType,
    r.RecordGuid,
    r.RecordId,
    r.AssetNumber,
    r.Name,
    r.Number,
    r.AddressLine1,
    r.Town,
    r.Postcode,
    r.GovernmentUPRN,
    r.FormattedAddress,
    r.MatchScore,
    r.MatchDetails
FROM SJob.AssetDuplicateCheck(
    N'Cymru House',
    N'10',
    N'Cathedral Road',
    NULL,
    NULL,
    N'Cardiff',
    N'CF11 9LJ',
    N'12345678',
    42,
    51.481583,
    -3.190000
) AS r
ORDER BY r.MatchScore DESC;

*/

CREATE FUNCTION [SJob].[AssetDuplicateCheck]
(
    @Name               NVARCHAR(100)   = NULL,
    @Number             NVARCHAR(50)    = NULL,
    @AddressLine1       NVARCHAR(50)    = NULL,
    @AddressLine2       NVARCHAR(50)    = NULL,
    @AddressLine3       NVARCHAR(50)    = NULL,
    @Town               NVARCHAR(50)    = NULL,
    @Postcode           NVARCHAR(50)    = NULL,
    @GovernmentUPRN     NVARCHAR(20)    = NULL,
    @OwnerAccountId     INT             = NULL,
    @Latitude           DECIMAL(9,6)    = NULL,
    @Longitude          DECIMAL(9,6)    = NULL
)
RETURNS @Results TABLE
(
    SourceType          NVARCHAR(20),           -- 'Asset' or 'Enquiry'
    RecordGuid          UNIQUEIDENTIFIER,
    RecordId            INT,
    AssetNumber         INT             NULL,
    Name                NVARCHAR(100),
    Number              NVARCHAR(50),
    AddressLine1        NVARCHAR(255),
    AddressLine2        NVARCHAR(255),
    AddressLine3        NVARCHAR(255),
    Town                NVARCHAR(255),
    Postcode            NVARCHAR(50),
    GovernmentUPRN      NVARCHAR(20),
    OwnerAccountId      INT             NULL,
    FormattedAddress    NVARCHAR(600),
    Latitude            DECIMAL(9,6)    NULL,
    Longitude           DECIMAL(9,6)    NULL,
    MatchScore          INT,                    -- Higher = more likely duplicate
    MatchDetails        NVARCHAR(MAX)           -- Diagnostic: which fields matched
)
    --WITH SCHEMABINDING
AS
BEGIN

    -- ===================================================================
    -- Normalised input variables for consistent comparison
    -- ===================================================================
    DECLARE @NormPostcode   NVARCHAR(50)  = REPLACE(UPPER(LTRIM(RTRIM(ISNULL(@Postcode, '')))), ' ', '');
    DECLARE @NormName       NVARCHAR(100) = UPPER(LTRIM(RTRIM(ISNULL(@Name, ''))));
    DECLARE @NormNumber     NVARCHAR(50)  = UPPER(LTRIM(RTRIM(ISNULL(@Number, ''))));
    DECLARE @NormAddr1      NVARCHAR(50)  = UPPER(LTRIM(RTRIM(ISNULL(@AddressLine1, ''))));
    DECLARE @NormTown       NVARCHAR(50)  = UPPER(LTRIM(RTRIM(ISNULL(@Town, ''))));
    DECLARE @NormUPRN       NVARCHAR(20)  = LTRIM(RTRIM(ISNULL(@GovernmentUPRN, '')));

    -- ===================================================================
    -- SECTION 1: Match against existing Assets (SJob.Assets)
    -- (Also known as Properties / Structures)
    -- ===================================================================
    INSERT INTO @Results
    (
        SourceType, RecordGuid, RecordId, AssetNumber,
        Name, Number, AddressLine1, AddressLine2, AddressLine3,
        Town, Postcode, GovernmentUPRN, OwnerAccountId,
        FormattedAddress, Latitude, Longitude,
        MatchScore, MatchDetails
    )
    SELECT
        'Asset'                                 AS SourceType,
        a.[Guid]                                AS RecordGuid,
        a.ID                                    AS RecordId,
        a.AssetNumber,
        a.Name,
        a.Number,
        a.AddressLine1,
        a.AddressLine2,
        a.AddressLine3,
        a.Town,
        a.Postcode,
        a.GovernmentUPRN,
        a.OwnerAccountId,
        a.FormattedAddressComma,
        a.Latitude,
        a.Longitude,

        -- === Weighted scoring ===
        (
            -- UPRN exact match (strongest unique identifier)
            CASE WHEN @NormUPRN <> ''
                 AND LTRIM(RTRIM(a.GovernmentUPRN)) <> ''
                 AND LTRIM(RTRIM(a.GovernmentUPRN)) = @NormUPRN
                 THEN 100 ELSE 0 END

            -- Geo-coordinate proximity (within ~50m ≈ 0.0005 degrees)
            + CASE WHEN @Latitude IS NOT NULL AND @Longitude IS NOT NULL
                   AND @Latitude <> 0 AND @Longitude <> 0
                   AND a.Latitude <> 0 AND a.Longitude <> 0
                   AND ABS(a.Latitude - @Latitude) < 0.0005
                   AND ABS(a.Longitude - @Longitude) < 0.0005
                   THEN 50 ELSE 0 END

            -- Exact postcode match (normalised, spaces removed)
            + CASE WHEN @NormPostcode <> ''
                   AND REPLACE(UPPER(LTRIM(RTRIM(a.Postcode))), ' ', '') = @NormPostcode
                   THEN 30 ELSE 0 END

            -- Exact Name match
            + CASE WHEN @NormName <> ''
                   AND UPPER(LTRIM(RTRIM(a.Name))) = @NormName
                   THEN 40 ELSE 0 END

            -- SOUNDEX Name match (fuzzy, only if not exact)
            + CASE WHEN @NormName <> ''
                   AND a.Name <> ''
                   AND SOUNDEX(a.Name) = SOUNDEX(@Name)
                   AND UPPER(LTRIM(RTRIM(a.Name))) <> @NormName
                   THEN 15 ELSE 0 END

            -- Exact Number (building number) match
            + CASE WHEN @NormNumber <> ''
                   AND UPPER(LTRIM(RTRIM(a.Number))) = @NormNumber
                   THEN 20 ELSE 0 END

            -- Exact AddressLine1 match
            + CASE WHEN @NormAddr1 <> ''
                   AND UPPER(LTRIM(RTRIM(a.AddressLine1))) = @NormAddr1
                   THEN 25 ELSE 0 END

            -- SOUNDEX AddressLine1 match (fuzzy, only if not exact)
            + CASE WHEN @NormAddr1 <> ''
                   AND a.AddressLine1 <> ''
                   AND SOUNDEX(a.AddressLine1) = SOUNDEX(@AddressLine1)
                   AND UPPER(LTRIM(RTRIM(a.AddressLine1))) <> @NormAddr1
                   THEN 10 ELSE 0 END

            -- Exact Town match
            + CASE WHEN @NormTown <> ''
                   AND UPPER(LTRIM(RTRIM(a.Town))) = @NormTown
                   THEN 10 ELSE 0 END

            -- SOUNDEX Town match
            + CASE WHEN @NormTown <> ''
                   AND a.Town <> ''
                   AND SOUNDEX(a.Town) = SOUNDEX(@Town)
                   AND UPPER(LTRIM(RTRIM(a.Town))) <> @NormTown
                   THEN 5 ELSE 0 END

            -- Owner account match
            + CASE WHEN @OwnerAccountId IS NOT NULL
                   AND @OwnerAccountId > 0
                   AND a.OwnerAccountId = @OwnerAccountId
                   THEN 15 ELSE 0 END
        )                                       AS MatchScore,

        -- === Diagnostic match details ===
        CONCAT_WS(', ',
            CASE WHEN @NormUPRN <> '' AND LTRIM(RTRIM(a.GovernmentUPRN)) = @NormUPRN
                 THEN 'UPRN:Exact' END,
            CASE WHEN @Latitude IS NOT NULL AND @Longitude IS NOT NULL
                 AND @Latitude <> 0 AND @Longitude <> 0
                 AND a.Latitude <> 0 AND a.Longitude <> 0
                 AND ABS(a.Latitude - @Latitude) < 0.0005
                 AND ABS(a.Longitude - @Longitude) < 0.0005
                 THEN 'GeoProximity:<50m' END,
            CASE WHEN @NormPostcode <> ''
                 AND REPLACE(UPPER(LTRIM(RTRIM(a.Postcode))), ' ', '') = @NormPostcode
                 THEN 'Postcode:Exact' END,
            CASE WHEN @NormName <> '' AND UPPER(LTRIM(RTRIM(a.Name))) = @NormName
                 THEN 'Name:Exact'
                 WHEN @NormName <> '' AND a.Name <> '' AND SOUNDEX(a.Name) = SOUNDEX(@Name)
                 THEN 'Name:Soundex' END,
            CASE WHEN @NormNumber <> '' AND UPPER(LTRIM(RTRIM(a.Number))) = @NormNumber
                 THEN 'Number:Exact' END,
            CASE WHEN @NormAddr1 <> '' AND UPPER(LTRIM(RTRIM(a.AddressLine1))) = @NormAddr1
                 THEN 'Addr1:Exact'
                 WHEN @NormAddr1 <> '' AND a.AddressLine1 <> '' AND SOUNDEX(a.AddressLine1) = SOUNDEX(@AddressLine1)
                 THEN 'Addr1:Soundex' END,
            CASE WHEN @NormTown <> '' AND UPPER(LTRIM(RTRIM(a.Town))) = @NormTown
                 THEN 'Town:Exact'
                 WHEN @NormTown <> '' AND a.Town <> '' AND SOUNDEX(a.Town) = SOUNDEX(@Town)
                 THEN 'Town:Soundex' END,
            CASE WHEN @OwnerAccountId IS NOT NULL AND @OwnerAccountId > 0
                 AND a.OwnerAccountId = @OwnerAccountId
                 THEN 'Owner:Match' END
        )                                       AS MatchDetails

    FROM SJob.Assets AS a
    WHERE a.RowStatus NOT IN (0, 254)
      -- Pre-filter: at least one meaningful criterion must match
      AND (
            (@NormUPRN <> '' AND LTRIM(RTRIM(a.GovernmentUPRN)) <> '' AND LTRIM(RTRIM(a.GovernmentUPRN)) = @NormUPRN)
         OR (@NormPostcode <> '' AND REPLACE(UPPER(LTRIM(RTRIM(a.Postcode))), ' ', '') = @NormPostcode)
         OR (@NormName <> '' AND a.Name <> '' AND SOUNDEX(a.Name) = SOUNDEX(@Name))
         OR (@NormAddr1 <> '' AND a.AddressLine1 <> '' AND SOUNDEX(a.AddressLine1) = SOUNDEX(@AddressLine1))
         OR (@OwnerAccountId IS NOT NULL AND @OwnerAccountId > 0 AND a.OwnerAccountId = @OwnerAccountId)
         OR (@Latitude IS NOT NULL AND @Longitude IS NOT NULL AND @Latitude <> 0 AND @Longitude <> 0
             AND a.Latitude <> 0 AND a.Longitude <> 0
             AND ABS(a.Latitude - @Latitude) < 0.0005
             AND ABS(a.Longitude - @Longitude) < 0.0005)
      );


    -- ===================================================================
    -- SECTION 2: Match against Enquiries with new structure/property
    -- details that have NOT yet been converted to a Quote.
    --
    -- Conversion detection: An enquiry is "converted" when ANY of its
    -- active EnquiryServices rows has QuoteId <> -1.
    -- We only include enquiries where NO active EnquiryService has been
    -- linked to a Quote yet.
    -- ===================================================================
    INSERT INTO @Results
    (
        SourceType, RecordGuid, RecordId, AssetNumber,
        Name, Number, AddressLine1, AddressLine2, AddressLine3,
        Town, Postcode, GovernmentUPRN, OwnerAccountId,
        FormattedAddress, Latitude, Longitude,
        MatchScore, MatchDetails
    )
    SELECT
        'Enquiry'                               AS SourceType,
        e.[Guid]                                AS RecordGuid,
        e.ID                                    AS RecordId,
        NULL                                    AS AssetNumber,
        e.PropertyNameNumber                    AS Name,
        ''                                      AS Number,
        e.PropertyAddressLine1                  AS AddressLine1,
        e.PropertyAddressLine2                  AS AddressLine2,
        e.PropertyAddressLine3                  AS AddressLine3,
        e.PropertyTown                          AS Town,
        e.PropertyPostCode                      AS Postcode,
        ''                                      AS GovernmentUPRN,  -- No UPRN on Enquiries
        e.ClientAccountId                       AS OwnerAccountId,
        CONCAT_WS(', ',
            NULLIF(e.PropertyNameNumber, ''),
            NULLIF(e.PropertyAddressLine1, ''),
            NULLIF(e.PropertyTown, ''),
            NULLIF(e.PropertyPostCode, '')
        )                                       AS FormattedAddress,
        NULL                                    AS Latitude,
        NULL                                    AS Longitude,

        -- === Weighted scoring (no UPRN/Geo available on enquiries) ===
        (
            -- Exact postcode match
            CASE WHEN @NormPostcode <> ''
                 AND REPLACE(UPPER(LTRIM(RTRIM(e.PropertyPostCode))), ' ', '') = @NormPostcode
                 THEN 30 ELSE 0 END

            -- Exact PropertyNameNumber match (equivalent to Asset.Name)
            + CASE WHEN @NormName <> ''
                   AND UPPER(LTRIM(RTRIM(e.PropertyNameNumber))) = @NormName
                   THEN 40 ELSE 0 END

            -- SOUNDEX PropertyNameNumber match
            + CASE WHEN @NormName <> ''
                   AND e.PropertyNameNumber <> ''
                   AND SOUNDEX(e.PropertyNameNumber) = SOUNDEX(@Name)
                   AND UPPER(LTRIM(RTRIM(e.PropertyNameNumber))) <> @NormName
                   THEN 15 ELSE 0 END

            -- Exact AddressLine1 match
            + CASE WHEN @NormAddr1 <> ''
                   AND UPPER(LTRIM(RTRIM(e.PropertyAddressLine1))) = @NormAddr1
                   THEN 25 ELSE 0 END

            -- SOUNDEX AddressLine1 match
            + CASE WHEN @NormAddr1 <> ''
                   AND e.PropertyAddressLine1 <> ''
                   AND SOUNDEX(e.PropertyAddressLine1) = SOUNDEX(@AddressLine1)
                   AND UPPER(LTRIM(RTRIM(e.PropertyAddressLine1))) <> @NormAddr1
                   THEN 10 ELSE 0 END

            -- Exact Town match
            + CASE WHEN @NormTown <> ''
                   AND UPPER(LTRIM(RTRIM(e.PropertyTown))) = @NormTown
                   THEN 10 ELSE 0 END

            -- SOUNDEX Town match
            + CASE WHEN @NormTown <> ''
                   AND e.PropertyTown <> ''
                   AND SOUNDEX(e.PropertyTown) = SOUNDEX(@Town)
                   AND UPPER(LTRIM(RTRIM(e.PropertyTown))) <> @NormTown
                   THEN 5 ELSE 0 END

            -- Client/owner account match
            + CASE WHEN @OwnerAccountId IS NOT NULL
                   AND @OwnerAccountId > 0
                   AND e.ClientAccountId = @OwnerAccountId
                   THEN 15 ELSE 0 END
        )                                       AS MatchScore,

        -- === Diagnostic match details ===
        CONCAT_WS(', ',
            CASE WHEN @NormPostcode <> ''
                 AND REPLACE(UPPER(LTRIM(RTRIM(e.PropertyPostCode))), ' ', '') = @NormPostcode
                 THEN 'Postcode:Exact' END,
            CASE WHEN @NormName <> '' AND UPPER(LTRIM(RTRIM(e.PropertyNameNumber))) = @NormName
                 THEN 'Name:Exact'
                 WHEN @NormName <> '' AND e.PropertyNameNumber <> '' AND SOUNDEX(e.PropertyNameNumber) = SOUNDEX(@Name)
                 THEN 'Name:Soundex' END,
            CASE WHEN @NormAddr1 <> '' AND UPPER(LTRIM(RTRIM(e.PropertyAddressLine1))) = @NormAddr1
                 THEN 'Addr1:Exact'
                 WHEN @NormAddr1 <> '' AND e.PropertyAddressLine1 <> '' AND SOUNDEX(e.PropertyAddressLine1) = SOUNDEX(@AddressLine1)
                 THEN 'Addr1:Soundex' END,
            CASE WHEN @NormTown <> '' AND UPPER(LTRIM(RTRIM(e.PropertyTown))) = @NormTown
                 THEN 'Town:Exact'
                 WHEN @NormTown <> '' AND e.PropertyTown <> '' AND SOUNDEX(e.PropertyTown) = SOUNDEX(@Town)
                 THEN 'Town:Soundex' END,
            CASE WHEN @OwnerAccountId IS NOT NULL AND @OwnerAccountId > 0
                 AND e.ClientAccountId = @OwnerAccountId
                 THEN 'Client:Match' END
        )                                       AS MatchDetails

    FROM SSop.Enquiries AS e
    WHERE e.RowStatus NOT IN (0, 254)
      -- Only enquiries that entered NEW structure/property details
      AND (e.EnterNewStructureDetails = 1 OR e.PropertyId = -1)
      -- Only enquiries where NO active EnquiryService has been linked to a Quote
      AND NOT EXISTS (
          SELECT 1
          FROM SSop.EnquiryServices AS es
          WHERE es.EnquiryId = e.ID
            AND es.RowStatus NOT IN (0, 254)
            AND es.QuoteId <> -1
      )
      -- Pre-filter: at least one meaningful criterion must match
      AND (
            (@NormPostcode <> '' AND REPLACE(UPPER(LTRIM(RTRIM(e.PropertyPostCode))), ' ', '') = @NormPostcode)
         OR (@NormName <> '' AND e.PropertyNameNumber <> '' AND SOUNDEX(e.PropertyNameNumber) = SOUNDEX(@Name))
         OR (@NormAddr1 <> '' AND e.PropertyAddressLine1 <> '' AND SOUNDEX(e.PropertyAddressLine1) = SOUNDEX(@AddressLine1))
         OR (@OwnerAccountId IS NOT NULL AND @OwnerAccountId > 0 AND e.ClientAccountId = @OwnerAccountId)
      );


    -- ===================================================================
    -- Remove any zero-score rows (safety net)
    -- ===================================================================
    DELETE FROM @Results WHERE MatchScore <= 0;

    RETURN;
END;
GO
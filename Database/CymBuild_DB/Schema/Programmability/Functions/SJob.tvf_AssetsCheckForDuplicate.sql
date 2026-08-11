SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SJob].[tvf_AssetsCheckForDuplicate]')
GO
PRINT (N'Create function [SJob].[tvf_AssetsCheckForDuplicate]')
GO


CREATE FUNCTION [SJob].[tvf_AssetsCheckForDuplicate] 
(
   @Name    NVARCHAR(100)   = NULL,
   @Number NVARCHAR(50) = NULL,
   @AddressLine1 NVARCHAR(100) = N'',
   @AddressLine2 NVARCHAR(100) = N'',
   @AddressLine3 NVARCHAR(100) = N'',
   @Town NVARCHAR(100) = N'',
   @CountyGuid UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000000',
   @Postcode NVARCHAR(100) = N''
)
RETURNS @Results TABLE
(
	Guid UNIQUEIDENTIFIER,
	FormattedAddress NVARCHAR(600),
	MatchScore INT
)
AS
BEGIN

	--Normalise values
	DECLARE @NormPostcode   NVARCHAR(50)  = REPLACE(UPPER(LTRIM(RTRIM(ISNULL(@Postcode, '')))), ' ', '');
    DECLARE @NormNumber     NVARCHAR(50)  = UPPER(LTRIM(RTRIM(ISNULL(@Number, ''))));
    DECLARE @NormAddr1      NVARCHAR(50)  = UPPER(LTRIM(RTRIM(ISNULL(@AddressLine1, ''))));
    DECLARE @NormTown       NVARCHAR(50)  = UPPER(LTRIM(RTRIM(ISNULL(@Town, ''))));
	DECLARE @NormName       NVARCHAR(100) = UPPER(LTRIM(RTRIM(ISNULL(@Name, ''))));


INSERT INTO @Results
(
	Guid,
	FormattedAddress,
	MatchScore
)
 SELECT 
        root_hobt.Guid,
        root_hobt.FormattedAddressComma,
		(

			-- Exact Name match
            + CASE WHEN @NormName <> ''
                   AND UPPER(LTRIM(RTRIM(root_hobt.Name))) = @NormName
                   THEN 40 ELSE 0 END

			+ CASE WHEN @NormPostcode <> ''
                   AND REPLACE(UPPER(LTRIM(RTRIM(root_hobt.Postcode))), ' ', '') = @NormPostcode
                   THEN 30 ELSE 0 END

            -- Exact Number (building number) match
            + CASE WHEN @NormNumber <> ''
                   AND UPPER(LTRIM(RTRIM(root_hobt.Number))) = @NormNumber
                   THEN 20 ELSE 0 END

            -- SOUNDEX Name match (fuzzy, only if not exact)
            + CASE WHEN @NormName <> ''
                   AND root_hobt.Name <> ''
                   AND SOUNDEX(root_hobt.Name) = SOUNDEX(@Name)
                   AND UPPER(LTRIM(RTRIM(root_hobt.Name))) <> @NormName
                   THEN 15 ELSE 0 END


            -- Exact AddressLine1 match
            + CASE WHEN @NormAddr1 <> ''
                   AND UPPER(LTRIM(RTRIM(root_hobt.AddressLine1))) = @NormAddr1
                   THEN 25 ELSE 0 END

            -- SOUNDEX AddressLine1 match (fuzzy, only if not exact)
            + CASE WHEN @NormAddr1 <> ''
                   AND root_hobt.AddressLine1 <> ''
                   AND SOUNDEX(root_hobt.AddressLine1) = SOUNDEX(@AddressLine1)
                   AND UPPER(LTRIM(RTRIM(root_hobt.AddressLine1))) <> @NormAddr1
                   THEN 10 ELSE 0 END

            -- Exact Town match
            + CASE WHEN @NormTown <> ''
                   AND UPPER(LTRIM(RTRIM(root_hobt.Town))) = @NormTown
                   THEN 30 ELSE 0 END

            -- SOUNDEX Town match
            + CASE WHEN @NormTown <> ''
                   AND root_hobt.Town <> ''
                   AND SOUNDEX(root_hobt.Town) = SOUNDEX(@Town)
                   AND UPPER(LTRIM(RTRIM(root_hobt.Town))) <> @NormTown
                   THEN 30 ELSE 0 END

           
        ) AS MatchScore

    FROM SJob.Assets AS root_hobt
    LEFT JOIN SCrm.Counties AS county ON root_hobt.CountyId = county.ID
    WHERE
			root_hobt.RowStatus NOT IN (0,254)
		AND (
					(@Number = N'' OR root_hobt.Number LIKE N'%' + @Number + N'%')
				OR (@AddressLine1 <> N'' OR root_hobt.AddressLine1 LIKE N'%' + @AddressLine1 + N'%')
				OR (@AddressLine2 <> N'' OR root_hobt.AddressLine2 LIKE N'%' + @AddressLine2 + N'%')
				OR (@AddressLine3 <> N'' OR root_hobt.AddressLine3 LIKE N'%' + @AddressLine3 + N'%')
				OR (@Town <> N'' AND root_hobt.Town LIKE N'%' + @Town + N'%')
				OR (@NormAddr1 <> '' AND root_hobt.AddressLine1 <> '' AND SOUNDEX(root_hobt.AddressLine1) = SOUNDEX(@AddressLine1))
				OR (
					@CountyGuid = '00000000-0000-0000-0000-000000000000'
					OR county.Guid = @CountyGuid
				)
				OR (@Postcode <> N'' AND REPLACE(UPPER(LTRIM(RTRIM(root_hobt.Postcode))), ' ', '') = @NormPostcode)
			)


		INSERT INTO @Results
		(
			Guid,
			FormattedAddress,
			MatchScore
		)
		SELECT
		'00000000-0000-0000-0000-000000000000',
        CONCAT_WS(', ',
            NULLIF(e.PropertyNameNumber, ''),
            NULLIF(e.PropertyAddressLine1, ''),
            NULLIF(e.PropertyTown, ''),
            NULLIF(e.PropertyPostCode, '')
        )                                       AS FormattedAddress,
		
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

        )                                       AS MatchScore

       
         

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
      );
		DELETE FROM @Results WHERE MatchScore <= 20;
		

		RETURN;

END;
GO
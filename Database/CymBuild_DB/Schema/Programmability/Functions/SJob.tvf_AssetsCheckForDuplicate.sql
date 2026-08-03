SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SJob].[tvf_AssetsCheckForDuplicate]')
GO


CREATE FUNCTION [SJob].[tvf_AssetsCheckForDuplicate] 
(
   @Number NVARCHAR(50),
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
            -- Exact postcode match (normalised, spaces removed)
            + CASE WHEN @NormPostcode <> ''
                   AND REPLACE(UPPER(LTRIM(RTRIM(root_hobt.Postcode))), ' ', '') = @NormPostcode
                   THEN 30 ELSE 0 END

          

            -- Exact Number (building number) match
            + CASE WHEN @NormNumber <> ''
                   AND UPPER(LTRIM(RTRIM(root_hobt.Number))) = @NormNumber
                   THEN 20 ELSE 0 END

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
                   THEN 10 ELSE 0 END

            -- SOUNDEX Town match
            + CASE WHEN @NormTown <> ''
                   AND root_hobt.Town <> ''
                   AND SOUNDEX(root_hobt.Town) = SOUNDEX(@Town)
                   AND UPPER(LTRIM(RTRIM(root_hobt.Town))) <> @NormTown
                   THEN 5 ELSE 0 END

           
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
		

		RETURN;

END;
GO
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCrm].[AddressUpsert]
(
	@AddressNumber INT,
    @Name NVARCHAR(100),
	@Number NVARCHAR(100),
	@AddressLine1 NVARCHAR(255),
	@AddressLine2 NVARCHAR(255),
	@AddressLine3 NVARCHAR(255),
	@Town NVARCHAR(255),
	@CountyGuid UNIQUEIDENTIFIER,
	@Postcode NVARCHAR(50),
	@CountryGuid UNIQUEIDENTIFIER,
    @Guid UNIQUEIDENTIFIER OUT
)
AS
BEGIN
    DECLARE @ProcessMessages SCore.ProcessMessages,
			@CountyId INT,
			@CountyName NVARCHAR(50),
			@CountryId INT
            
	SELECT	@CountyId = c.ID,
			@CountyName = c.Name
	FROM	SCrm.Counties c
	WHERE	(c.Guid = @CountyGuid)

	SELECT	@CountryId = c.ID
	FROM	SCrm.Countries c
	WHERE	(c.Guid = @CountryGuid)

    DECLARE	@IsInsert bit
	EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
							@SchemeName = N'SCrm',				-- nvarchar(255)
							@ObjectName = N'Addresses',				-- nvarchar(255)
							@IsInsert = @IsInsert OUTPUT,	-- bit
							@IncludeDefaultSecurity = 0

    IF (@IsInsert = 1)
    BEGIN 
		INSERT	SCrm.Addresses
			 (RowStatus, Guid, AddressNumber, Name, Number, AddressLine1, AddressLine2, AddressLine3, Town, CountyID, Postcode, CountryID, LegacyID, FormattedAddressCR, FormattedAddressComma)
		VALUES
			 (
				 1,	-- RowStatus - tinyint
				 @Guid,	-- Guid - uniqueidentifier
				 @AddressNumber,	-- AddressNumber - int
				 @Name,	-- Name - nvarchar(100)
				 @Number,	-- Number - nvarchar(50)
				 @AddressLine1,	-- AddressLine1 - nvarchar(255)
				 @AddressLine2,	-- AddressLine2 - nvarchar(255)
				 @AddressLine3,	-- AddressLine3 - nvarchar(255)
				 @Town,	-- Town - nvarchar(255)
				 @CountyId,	-- CountyID - int
				 @Postcode,	-- Postcode - nvarchar(50)
				 @CountryId,	-- CountryID - int
				 NULL,		-- LegacyID - int
				 SCore.FormatAddress(N'', @Number, @AddressLine1, @AddressLine2, @AddressLine3, @Town, @CountyName, @Postcode, CHAR(13)),	-- FormattedAddressCR - nvarchar(600)
				 SCore.FormatAddress(N'', @Number, @AddressLine1, @AddressLine2, @AddressLine3, @Town, @CountyName, @Postcode, N',')	-- FormattedAddressComma - nvarchar(600)
			 )

    END
    ELSE
    BEGIN 
        UPDATE  SCrm.Addresses
        SET     AddressNumber = @AddressNumber,
				Name = @Name,
				Number = @Number,
				AddressLine1 = @AddressLine1, 
				AddressLine2 = @AddressLine2,
				AddressLine3 = @AddressLine3,
				Town = @Town,
				CountyID = @CountyId,
				PostCode = @Postcode,
				CountryID = @CountryId,
				FormattedAddressCR = SCore.FormatAddress(N'', @Number, @AddressLine1, @AddressLine2, @AddressLine3, @Town, @CountyName, @Postcode, CHAR(13)),	-- FormattedAddressCR - nvarchar(600)
				FormattedAddressComma = SCore.FormatAddress(N'', @Number, @AddressLine1, @AddressLine2, @AddressLine3, @Town, @CountyName, @Postcode, N',')
        WHERE   ([Guid] = @Guid)
    END

    IF (EXISTS (SELECT 1 FROM @ProcessMessages))
    BEGIN 
        DECLARE @UserID INT,
                @ProcessGuid UNIQUEIDENTIFIER

        SELECT @UserID = CONVERT(INT, SESSION_CONTEXT(N'user_id')); 

        SELECT @ProcessGuid = CONVERT(UNIQUEIDENTIFIER, SESSION_CONTEXT(N'process_guid')); 

        IF (@@ROWCOUNT > 0)
        BEGIN 
            INSERT SCore.SystemLog ([UserID], [Severity], Message, ProcessGuid)
            SELECT  @UserID, [Type], [Message], @ProcessGuid
            FROM    @ProcessMessages
        END
    END
END
GO
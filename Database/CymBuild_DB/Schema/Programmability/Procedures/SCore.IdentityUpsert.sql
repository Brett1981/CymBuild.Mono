SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO




CREATE PROCEDURE [SCore].[IdentityUpsert]
  (
    @FullName               NVARCHAR(250),
    @EmailAddress           NVARCHAR(150),
    @JobTitle               NVARCHAR(50),
    @OrganisationalUnitGuid UNIQUEIDENTIFIER,
    @IsActive               BIT,
    @ContactGuid            UNIQUEIDENTIFIER,
	@BillableRate			DECIMAL(19,2),
    @Guid                   UNIQUEIDENTIFIER
  )
AS
  BEGIN
    SET NOCOUNT ON

    DECLARE @OrganisationalUnitId INT,
            @ContactId            INT,
            @UserID               INT;

    SELECT
            @OrganisationalUnitId = ou.ID
    FROM
            SCore.OrganisationalUnits AS ou
    WHERE
            (ou.Guid = @OrganisationalUnitGuid);

    SELECT  @ContactId = Id
    FROM    SCrm.Contacts c 
    WHERE   guid = @ContactGuid

    DECLARE @IsInsert BIT = 0;
    EXEC SCore.UpsertDataObject
      @Guid       = @Guid,					-- uniqueidentifier
      @SchemeName = N'SCore',			-- nvarchar(255)
      @ObjectName = N'Identities',	-- nvarchar(255)
      @IsInsert   = @IsInsert OUTPUT;	-- bit

    IF (@IsInsert = 1)
      BEGIN
        INSERT SCore.Identities
              (
                Guid,
                RowStatus,
                FullName,
                EmailAddress,
                JobTitle,
                OriganisationalUnitId,
                ContactId,
                IsActive,
				BillableRate
              )
        VALUES
                (
                  @Guid,
                  1,
                  @FullName,
                  @EmailAddress,
                  @JobTitle,
                  @OrganisationalUnitId,
                  @ContactId,
                  @IsActive,
				  @BillableRate
                );

        SELECT
                @UserID = SCOPE_IDENTITY();

        INSERT SCore.UserPreferences
              (
                ID,
                Guid,
                RowStatus,
                SystemLanguageID
              )
        VALUES
                (
                  @UserID,	-- ID - int
                  @Guid,	-- Guid - uniqueidentifier
                  1,			-- RowStatus - tinyint
                  1			-- SystemLanguageID - int
                );

      END;
    ELSE
      BEGIN
        UPDATE  SCore.Identities
        SET     FullName = @FullName,
                EmailAddress = @EmailAddress,
                JobTitle = @JobTitle,
                OriganisationalUnitId = @OrganisationalUnitId,
                ContactId = @ContactId,
                IsActive = @IsActive,
				BillableRate = @BillableRate
        WHERE
          (Guid = @Guid);
      END;

  END;
GO
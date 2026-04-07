SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCrm].[ContactUpsert]
(
    @FirstName NVARCHAR(250),
	@Surname NVARCHAR(250),
	@DisplayName NVARCHAR(250),
	@IsPerson BIT,
	@PrimaryAccountGuid UNIQUEIDENTIFIER,
	@PrimaryAddressGuid UNIQUEIDENTIFIER,
	@TitleGuid UNIQUEIDENTIFIER,
	@PositionGuid UNIQUEIDENTIFIER,
	@Initials NVARCHAR(10),
	@PostNominals NVARCHAR(250),
    @Guid UNIQUEIDENTIFIER OUT
)
AS
BEGIN
    DECLARE @ProcessMessages SCore.ProcessMessages,
			@PrimaryAccountId INT,
			@PrimaryAddressId INT,
			@TitleId INT,
			@PositionId INT
           

	SELECT	@PrimaryAccountId = ID
	FROM	SCrm.Accounts
	WHERE	(Guid = @PrimaryAccountGuid)

	SELECT	@PrimaryAddressId = ID
	FROM	SCrm.Addresses
	WHERE	(Guid = @PrimaryAddressGuid)

	SELECT	@TitleId = ID
	FROM	SCrm.ContactTitles
	WHERE	(Guid = @TitleGuid)

	SELECT	@PositionId = ID
	FROM	SCrm.ContactPositions
	WHERE	(Guid = @PositionGuid)


    DECLARE	@IsInsert bit
	EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
							@SchemeName = N'SCrm',				-- nvarchar(255)
							@ObjectName = N'Contacts',				-- nvarchar(255)
							@IsInsert = @IsInsert OUTPUT,	-- bit
							@IncludeDefaultSecurity = 0

    IF (@IsInsert = 1)
    BEGIN 
		INSERT SCrm.Contacts
			 (RowStatus, Guid, PrimaryAccountID, PrimaryAddressID, FirstName, Surname, TitleId, DisplayName, IsPerson, PositionID, Initials, PostNominals)
		VALUES
			 (
				 1,	-- RowStatus - tinyint
				 @Guid,	-- Guid - uniqueidentifier
				 @PrimaryAccountId,	-- PrimaryAccountID - int
				 @PrimaryAddressId,	-- PrimaryAddressID - int
				 @FirstName,	-- FirstName - nvarchar(250)
				 @Surname,	-- Surname - nvarchar(250)
				 @TitleId,	-- TitleId - smallint
				 @DisplayName,	-- DisplayName - nvarchar(250)
				 @IsPerson,	-- IsPerson - bit
				 @PositionId,	-- PositionID - int
				 @Initials,
				 @PostNominals
			 )
    END
    ELSE
    BEGIN 
        UPDATE  SCrm.Contacts
        SET     PrimaryAccountID = @PrimaryAccountId,
				PrimaryAddressID = @PrimaryAddressId,
				FirstName = @FirstName,
				Surname = @Surname, 
				TitleId = @TitleId,
				DisplayName = @DisplayName,
				IsPerson = @IsPerson,
				PositionID = 				 @PositionId,	-- PositionID - int
				Initials = @Initials,
				PostNominals = @PostNominals
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
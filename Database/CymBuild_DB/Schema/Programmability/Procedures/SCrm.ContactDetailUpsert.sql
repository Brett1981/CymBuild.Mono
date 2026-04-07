SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCrm].[ContactDetailUpsert]
  (
    @Name                  NVARCHAR(100),
    @Value                 NVARCHAR(250),
    @ContactGuid           UNIQUEIDENTIFIER,
    @ContactDetailTypeGuid UNIQUEIDENTIFIER,
    @IsDefault             BIT,
    @Guid                  UNIQUEIDENTIFIER OUT
  )
AS
  BEGIN
    DECLARE @ProcessMessages     SCore.ProcessMessages,
            @ContactId           INT,
            @ContactDetailTypeId INT;

    SELECT
            @ContactId = ID
    FROM
            SCrm.Contacts
    WHERE
            (Guid = @ContactGuid)

    SELECT
            @ContactDetailTypeId = ID
    FROM
            SCrm.ContactDetailTypes
    WHERE
            (Guid = @ContactDetailTypeGuid)

    IF (@IsDefault = 0) 
    BEGIN  
      IF (NOT EXISTS
          (
            SELECT  1
            FROM    SCrm.ContactDetails cde
            WHERE   (cde.ContactDetailTypeID = @ContactDetailTypeId)
                AND (cde.ContactID = @ContactId)
                AND (cde.RowStatus IN (0, 254))
                AND (cde.Guid <> @Guid)
          )
          )
      BEGIN 
        SET @IsDefault = 1;
      END   
    END
    


    DECLARE @IsInsert BIT
    EXEC SCore.UpsertDataObject
      @Guid       = @Guid,					-- uniqueidentifier
      @SchemeName = N'SCrm',				-- nvarchar(255)
      @ObjectName = N'ContactDetails',				-- nvarchar(255)
      @IsInsert   = @IsInsert OUTPUT,	-- bit
	  @IncludeDefaultSecurity = 0

    IF (@IsInsert = 1)
      BEGIN
        INSERT SCrm.ContactDetails
              (
                RowStatus,
                Guid,
                ContactID,
                ContactDetailTypeID,
                Name,
                Value,
                IsDefault
              )
        VALUES
                (
                  1,	-- RowStatus - tinyint
                  @Guid,	-- Guid - uniqueidentifier
                  @ContactId,	-- ContactID - int
                  @ContactDetailTypeId,	-- ContactDetailTypeID - smallint
                  @Name,	-- Name - nvarchar(100)
                  @Value,	-- Value - nvarchar(250)
                  @IsDefault
                )
      END
    ELSE
      BEGIN
        UPDATE  SCrm.ContactDetails
        SET     ContactID = @ContactId,
                ContactDetailTypeID = @ContactDetailTypeId,
                Name = @Name,
                Value = @Value,
                IsDefault = @IsDefault
        WHERE
          ([Guid] = @Guid)
      END

    IF (EXISTS
      (
          SELECT
                  1
          FROM
                  @ProcessMessages
      )
      )
      BEGIN
        DECLARE @UserID      INT,
                @ProcessGuid UNIQUEIDENTIFIER

        SELECT
                @UserID = CONVERT(INT, SESSION_CONTEXT(N'user_id'));

        SELECT
                @ProcessGuid = CONVERT(UNIQUEIDENTIFIER, SESSION_CONTEXT(N'process_guid'));

        IF (@@ROWCOUNT > 0)
          BEGIN
            INSERT SCore.SystemLog
                  (
                    [UserID],
                    [Severity],
                    Message,
                    ProcessGuid
                  )
                SELECT
                        @UserID,
                        [Type],
                        [Message],
                        @ProcessGuid
                FROM
                        @ProcessMessages
          END
      END
  END
GO
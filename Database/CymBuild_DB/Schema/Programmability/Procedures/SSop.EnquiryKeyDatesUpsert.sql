SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO








CREATE PROCEDURE [SSop].[EnquiryKeyDatesUpsert]
  (
    @EnquiryGuid UNIQUEIDENTIFIER,
    @Details     NVARCHAR(500),
    @DateTime    DATETIME2,
    @Guid        UNIQUEIDENTIFIER
  )
AS
  BEGIN
    DECLARE @EnquiryId INT = -1,
            @IsInsert  BIT;

    SELECT
            @EnquiryId = ID
    FROM
            SSop.Enquiries
    WHERE
            (Guid = @EnquiryGuid);


    EXEC SCore.UpsertDataObject
      @Guid       = @Guid,					-- uniqueidentifier
      @SchemeName = N'SSop',				-- nvarchar(255)
      @ObjectName = N'EnquiryKeyDates',				-- nvarchar(255)
      @IsInsert   = @IsInsert OUTPUT;	-- bit

    IF (@IsInsert = 1)
      BEGIN
        INSERT SSop.EnquiryKeyDates
              (
                RowStatus,
                Guid,
                EnquiryId,
                Details,
                DateTime
              )
        VALUES
                (
                  1,
                  @Guid,
                  @EnquiryId,
                  @Details,
                  @DateTime
                )
      END;
    ELSE
      BEGIN
        UPDATE  SSop.EnquiryKeyDates
        SET     EnquiryId = @EnquiryId,
                Details = @Details,
                DateTime = @DateTime
        WHERE
          (Guid = @Guid);
      END;

  END;
GO
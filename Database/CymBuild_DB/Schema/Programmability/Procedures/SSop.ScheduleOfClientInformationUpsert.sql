SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SSop].[ScheduleOfClientInformationUpsert]
  (
    @EnquiryGuid        UNIQUEIDENTIFIER,
    @Item				NVARCHAR(200),
    @Guid               UNIQUEIDENTIFIER
  )
AS
  BEGIN
    DECLARE @EnquiryId        INT = -1,
            @IsInsert         BIT;

    SELECT
            @EnquiryId = ID
    FROM
            SSop.Enquiries
    WHERE
            (Guid = @EnquiryGuid);


    EXEC SCore.UpsertDataObject
      @Guid       = @Guid,					-- uniqueidentifier
      @SchemeName = N'SSop',				-- nvarchar(255)
      @ObjectName = N'ScheduleOfClientInformation',				-- nvarchar(255)
	  @IncludeDefaultSecurity = 0,
      @IsInsert   = @IsInsert OUTPUT;	-- bit

    IF (@IsInsert = 1)
      BEGIN
        INSERT SSop.ScheduleOfClientInformation
              (
                RowStatus,
                Guid,
                EnquiryId,
                Item
              )
        VALUES
                (
                  1,	-- RowStatus - tinyint
                  @Guid,	-- Guid - uniqueidentifier
                  @EnquiryId,	-- EnquiryId - int
                  @Item
                )
      END;
    ELSE
      BEGIN
        UPDATE  SSop.ScheduleOfClientInformation
        SET     EnquiryId = @EnquiryId,
                Item = @Item
        WHERE
          (Guid = @Guid);
      END;

  END;
GO
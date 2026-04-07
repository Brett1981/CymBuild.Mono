SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO



CREATE PROCEDURE [SSop].[QuoteMemosUpsert]
  (
    @QuoteGuid            UNIQUEIDENTIFIER,
    @Memo               NVARCHAR(MAX),
    @CreatedDateTimeUTC DATETIME2,
    @CreatedByUserGuid  UNIQUEIDENTIFIER,
    @Guid               UNIQUEIDENTIFIER
  )
AS
  BEGIN
    DECLARE @CreatedByUserID INT,
            @QuoteID           INT

    SELECT
            @CreatedByUserID = ID
    FROM
            SCore.Identities
    WHERE
            ([Guid] = @CreatedByUserGuid)

    SELECT
            @QuoteID = ID
    FROM
            SSop.Quotes
    WHERE
            ([Guid] = @QuoteGuid)

    IF (@CreatedDateTimeUTC IS NULL)
      BEGIN
        SET @CreatedDateTimeUTC = GETUTCDATE()
      END

    DECLARE @IsInsert BIT
    EXEC SCore.UpsertDataObject
      @Guid       = @Guid,					-- uniqueidentifier
      @SchemeName = N'SSop',				-- nvarchar(255)
      @ObjectName = N'QuoteMemos',				-- nvarchar(255)
      @IsInsert   = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
      BEGIN
        INSERT SSop.QuoteMemos
              (
                RowStatus,
                Guid,
                QuoteID,
                Memo,
                CreatedDateTimeUTC,
                CreatedByUserId
              )
        VALUES
                (
                  1,	-- RowStatus - tinyint
                  @Guid,	-- Guid - uniqueidentifier
                  @QuoteID,	-- QuoteID - int
                  @Memo,	-- Memo - nvarchar(max)
                  @CreatedDateTimeUTC,	-- CreatedDateTimeUTC - datetime2(7)
                  @CreatedByUserID	-- CreatedByUserId - int
                )
      END
    ELSE
      BEGIN
        UPDATE  SSop.QuoteMemos
        SET     QuoteID = @QuoteID,
                Memo = @Memo
        WHERE
          ([Guid] = @Guid)
      END
  END
GO
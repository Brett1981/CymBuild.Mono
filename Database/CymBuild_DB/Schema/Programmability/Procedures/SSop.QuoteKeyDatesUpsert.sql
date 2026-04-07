SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO





CREATE PROCEDURE [SSop].[QuoteKeyDatesUpsert]
  (
    @QuoteGuid              UNIQUEIDENTIFIER,
    @Detail                NVARCHAR(500),
    @DateTime               datetime2,                 
    @Guid                   UNIQUEIDENTIFIER
  )
AS
  BEGIN
    DECLARE @QuoteId              INT,
            @IsInsert             BIT;

    SELECT
            @QuoteId = ID
    FROM
            SSop.Quotes
    WHERE
            ([Guid] = @QuoteGuid)

   
    EXEC SCore.UpsertDataObject
      @Guid       = @Guid,					-- uniqueidentifier
      @SchemeName = N'SSop',				-- nvarchar(255)
      @ObjectName = N'QuoteKeyDates',				-- nvarchar(255)
      @IsInsert   = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
      BEGIN
        INSERT SSop.QuoteKeyDates
              (
                RowStatus,
                Guid,
                QuoteId,
                Detail,
                DateTime
              )
        VALUES
                (
                  1,	-- RowStatus - tinyint
                  @Guid,	-- Guid - uniqueidentifier
                  @QuoteId,	-- QuoteId - int
                  @Detail,
                  @DateTime
                )
      END
    ELSE
      BEGIN
        UPDATE  SSop.QuoteKeyDates
        SET     QuoteId = @QuoteId,
                Detail = @Detail,
                DateTime = @DateTime
        WHERE
          ([Guid] = @Guid)
      END
  END
GO
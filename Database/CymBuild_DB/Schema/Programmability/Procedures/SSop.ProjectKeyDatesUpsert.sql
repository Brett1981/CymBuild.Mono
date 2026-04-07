SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SSop].[ProjectKeyDatesUpsert]
  (
    @ProjectGuid              UNIQUEIDENTIFIER,
    @Detail                NVARCHAR(500),
    @DateTime               DATETIME2,                 
    @Guid                   UNIQUEIDENTIFIER
  )
AS
  BEGIN
    DECLARE @ProjectId              INT,
            @IsInsert             BIT;

    SELECT
            @ProjectId = ID
    FROM
            SSop.Projects
    WHERE
            ([Guid] = @ProjectGuid)

	IF @ProjectId IS NULL
		BEGIN
			RAISERROR('ProjectId not found for the provided ProjectGuid.', 16, 1);
			RETURN;
		END


   
    EXEC SCore.UpsertDataObject
      @Guid       = @Guid,					-- uniqueidentifier
      @SchemeName = N'SSop',				-- nvarchar(255)
      @ObjectName = N'ProjectKeyDates',				-- nvarchar(255)
	  @IncludeDefaultSecurity = 0,
      @IsInsert   = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
      BEGIN
        INSERT SSop.ProjectKeyDates
              (
                RowStatus,
                Guid,
                ProjectId,
                Detail,
                DateTime
              )
        VALUES
                (
                  1,	-- RowStatus - tinyint
                  @Guid,	-- Guid - uniqueidentifier
                  @ProjectId,	-- QuoteId - int
                  @Detail,
                  @DateTime
                )
      END
    ELSE
      BEGIN
        UPDATE  SSop.ProjectKeyDates
        SET     ProjectId = @ProjectId,
                Detail = @Detail,
                DateTime = @DateTime
        WHERE
          ([Guid] = @Guid)
      END
  END
GO
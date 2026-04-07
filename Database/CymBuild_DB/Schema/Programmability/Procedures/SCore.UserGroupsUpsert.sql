SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCore].[UserGroupsUpsert]
  @UserGuid  UNIQUEIDENTIFIER,
  @GroupGuid UNIQUEIDENTIFIER,
  @Guid      UNIQUEIDENTIFIER
AS
  BEGIN
    DECLARE @IsInsert BIT = 0,
            @UserId   INT,
            @GroupId  INT;

    SELECT
            @UserId = ID
    FROM
            SCore.Identities i
    WHERE
            (Guid = @UserGuid);

    SELECT
            @GroupId = ID
    FROM
            SCore.Groups g
    WHERE
            (Guid = @GroupGuid);

    EXEC SCore.UpsertDataObject
      @Guid       = @Guid,					-- uniqueidentifier
      @SchemeName = N'SCore',				-- nvarchar(255)
      @ObjectName = N'UserGroups',				-- nvarchar(255)
	  @IncludeDefaultSecurity = 0,      -- bit
      @IsInsert   = @IsInsert OUTPUT	-- bit

    IF @IsInsert = 1
      BEGIN
        INSERT INTO SCore.UserGroups
                  (
                    Guid,
                    RowStatus,
                    IdentityID,
                    GroupID
                  )
        VALUES
                (
                  @Guid,
                  1,
                  @UserId,
                  @GroupId
                );
      END;
    ELSE
      BEGIN
        UPDATE  SCore.UserGroups
        SET     IdentityID = @UserId,
                GroupID = @GroupId
        WHERE
          Guid = @Guid;
      END;

  END;

GO
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
PRINT (N'Create function [SCore].[GetCurrentUserDefaultGroup]')
GO

CREATE FUNCTION [SCore].[GetCurrentUserDefaultGroup]()
RETURNS INT
AS
BEGIN
    DECLARE
        @UserId                 INT,
        @DefaultSecurityGroupId INT,
        @NewEntityTypeGuid      UNIQUEIDENTIFIER,
        @RecordGuid             UNIQUEIDENTIFIER,
        @OrgUnitId              INT,
        @OrgUnitName            NVARCHAR(250),
        @OrgUnitDefaultGroupId  INT;

    SET @UserId = ISNULL(CONVERT(INT, SESSION_CONTEXT(N'user_id')), -1);
    SET @NewEntityTypeGuid = TRY_CONVERT(UNIQUEIDENTIFIER, SESSION_CONTEXT(N'new_entity_type_guid'));
    SET @RecordGuid        = TRY_CONVERT(UNIQUEIDENTIFIER, SESSION_CONTEXT(N'record_guid'));

    -------------------------------------------------------------------------
    -- Quote create
    -------------------------------------------------------------------------
    IF (@NewEntityTypeGuid = '1C4794C1-F956-4C32-B886-5500AC778A56' AND @RecordGuid IS NOT NULL)
    BEGIN
        -- Preferred: record_guid is EnquiryService.Guid
        SELECT TOP (1)
            @OrgUnitId             = ou.ID,
            @OrgUnitName           = ou.[Name],
            @OrgUnitDefaultGroupId = ou.DefaultSecurityGroupId
        FROM SSop.EnquiryServices es
        JOIN SJob.JobTypes jt ON jt.ID = es.JobTypeId
        JOIN SCore.OrganisationalUnits ou ON ou.ID = jt.OrganisationalUnitID
        WHERE es.Guid = @RecordGuid
          AND es.RowStatus NOT IN (0,254);

        -- Fallback: record_guid is Enquiry.Guid -> resolve via EnquiryServices.EnquiryGuid
        IF (ISNULL(@OrgUnitId, -1) = -1)
        BEGIN
            DECLARE @DistinctOuCount INT, @ResolvedOuId INT;

            ;WITH CandidateOus AS
            (
                SELECT DISTINCT ou.ID AS OrgUnitId
                FROM SSop.EnquiryServices es
                JOIN SJob.JobTypes jt ON jt.ID = es.JobTypeId
                JOIN SCore.OrganisationalUnits ou ON ou.ID = jt.OrganisationalUnitID
                WHERE es.Guid = @RecordGuid
                  AND es.RowStatus NOT IN (0,254)
                  AND es.JobTypeId IS NOT NULL
            )
            SELECT
                @DistinctOuCount = COUNT(*),
                @ResolvedOuId    = MAX(OrgUnitId)
            FROM CandidateOus;

            IF (@DistinctOuCount = 1)
            BEGIN
                SELECT TOP (1)
                    @OrgUnitId             = ou.ID,
                    @OrgUnitName           = ou.[Name],
                    @OrgUnitDefaultGroupId = ou.DefaultSecurityGroupId
                FROM SCore.OrganisationalUnits ou
                WHERE ou.ID = @ResolvedOuId
                  AND ou.RowStatus NOT IN (0,254);
            END
            ELSE IF (@DistinctOuCount > 1)
            BEGIN
                -- Ambiguous: enquiry spans multiple OUs => block Quote create
                RETURN -1;
            END
            -- else none => fall through to legacy default
        END

        IF (ISNULL(@OrgUnitId, -1) <> -1 AND ISNULL(@OrgUnitDefaultGroupId, -1) <> -1)
        BEGIN
            IF EXISTS
            (
                SELECT 1
                FROM SCore.UserGroups ug
                WHERE ug.IdentityID = @UserId
                  AND ug.GroupID    = @OrgUnitDefaultGroupId
            )
                RETURN @OrgUnitDefaultGroupId;

            RETURN -1;
        END
    END

    -------------------------------------------------------------------------
    -- Job create
    -------------------------------------------------------------------------
    IF (@NewEntityTypeGuid = '63542427-46AB-4078-ABD1-1D583C24315C' AND @RecordGuid IS NOT NULL)
    BEGIN
        SELECT TOP (1)
            @OrgUnitId             = ou.ID,
            @OrgUnitName           = ou.[Name],
            @OrgUnitDefaultGroupId = ou.DefaultSecurityGroupId
        FROM SSop.Quotes q
        JOIN SCore.OrganisationalUnits ou ON ou.ID = q.OrganisationalUnitID
        WHERE q.Guid = @RecordGuid
          AND q.RowStatus NOT IN (0,254);

        IF (ISNULL(@OrgUnitId, -1) <> -1 AND ISNULL(@OrgUnitDefaultGroupId, -1) <> -1)
        BEGIN
            IF EXISTS
            (
                SELECT 1
                FROM SCore.UserGroups ug
                WHERE ug.IdentityID = @UserId
                  AND ug.GroupID    = @OrgUnitDefaultGroupId
            )
                RETURN @OrgUnitDefaultGroupId;

            RETURN -1;
        END
    END

    -------------------------------------------------------------------------
    -- Legacy default (unchanged behaviour)
    -------------------------------------------------------------------------
    SELECT @DefaultSecurityGroupId = ou.DefaultSecurityGroupId
    FROM SCore.Identities i
    JOIN SCore.OrganisationalUnits ou ON ou.ID = i.OriganisationalUnitId
    WHERE i.ID = @UserId;

    RETURN ISNULL(@DefaultSecurityGroupId, -1);
END;
GO
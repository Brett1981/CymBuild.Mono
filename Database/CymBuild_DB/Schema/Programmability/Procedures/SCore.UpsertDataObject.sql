SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
PRINT (N'Create procedure [SCore].[UpsertDataObject]')
GO

CREATE PROCEDURE [SCore].[UpsertDataObject]
(
    @Guid UNIQUEIDENTIFIER,
    @SchemeName NVARCHAR(255),
    @ObjectName NVARCHAR(255),
    @IncludeDefaultSecurity BIT = 1,
    @IsInsert BIT OUT
)
AS
BEGIN
    SET NOCOUNT ON;

    PRINT N'Running upsert data object for ' + CONVERT(NVARCHAR(MAX), @Guid) + N' [' + @SchemeName + N'].[' + @ObjectName + N']';

    IF (EXISTS
    (
        SELECT 1
        FROM SCore.DataObjects
        WHERE (Guid = @Guid)
    ))
    BEGIN
        SET @IsInsert = 0;

        DECLARE @stmt NVARCHAR(4000) =
            N'SELECT @existingId = id FROM [' + @SchemeName + N'].[' + @ObjectName + N'] WHERE Guid = ''' + CONVERT(NVARCHAR(4000), @Guid) + '''',
            @existingId BIGINT;

        EXEC sp_executesql @stmt, N'@existingId BIGINT OUT', @existingId = @existingId OUTPUT;

        IF (ISNULL(@existingId, -1) < 0)
        BEGIN
            ;THROW 60000, N'Error in data object upsert. The record to update does not exist.', 1;
        END

        RETURN;
    END
    ELSE
    BEGIN
        DECLARE @EntityTypeId INT;

        SELECT @EntityTypeId = eh.EntityTypeID
        FROM SCore.EntityHobts AS eh
        WHERE (eh.SchemaName = @SchemeName)
          AND (eh.ObjectName = @ObjectName);

        INSERT SCore.DataObjects
            (Guid, RowStatus, EntityTypeId)
        VALUES
            (@Guid, 1, @EntityTypeId);

        IF (@IncludeDefaultSecurity = 1)
        BEGIN
            /*
                Default security record based on user profile.

                IMPORTANT:
                - The new OrgUnit enforcement must ONLY apply when creating:
                    Quotes: 1c4794c1-f956-4c32-b886-5500ac778a56
                    Jobs:   63542427-46ab-4078-abd1-1d583c24315c
                - All other entity creates (Enquiries, etc.) must continue the legacy path.
                - We clear session context keys when not in-scope to prevent stale pooled-connection values.
            */

            DECLARE
                @OsGuid UNIQUEIDENTIFIER = NEWID(),
                @DefaultSecurityGroupId INT,
                @NewEntityTypeGuid UNIQUEIDENTIFIER,
                @EnforceOrgUnit BIT = 0;

            SELECT @NewEntityTypeGuid = et.[Guid]
            FROM SCore.EntityTypes et
            WHERE et.ID = @EntityTypeId;

            -- Only enforce OrgUnit membership for Quote/Job creates
            IF (@NewEntityTypeGuid IN
                (
                    '1C4794C1-F956-4C32-B886-5500AC778A56', -- Quote
                    '63542427-46AB-4078-ABD1-1D583C24315C'  -- Job
                ))
            BEGIN
                SET @EnforceOrgUnit = 1;

                EXEC sys.sp_set_session_context
                    @key = N'new_entity_type_guid',
                    @value = @NewEntityTypeGuid,
                    @read_only = 0;

                -- only set record_guid if caller hasn't already supplied it
                IF (SESSION_CONTEXT(N'record_guid') IS NULL)
                BEGIN
                    EXEC sys.sp_set_session_context
                        @key = N'record_guid',
                        @value = @Guid,
                        @read_only = 0;
                END
            END
            ELSE
            BEGIN
                -- Ensure legacy path for non Quote/Job inserts
                EXEC sys.sp_set_session_context @key = N'new_entity_type_guid', @value = NULL, @read_only = 0;
                EXEC sys.sp_set_session_context @key = N'record_guid',         @value = NULL, @read_only = 0;
            END

            SET @DefaultSecurityGroupId = SCore.GetCurrentUserDefaultGroup();

            -- Block only for Quote/Job creates when membership fails
            /*IF (@EnforceOrgUnit = 1 AND @DefaultSecurityGroupId = -1)
            BEGIN
                ;THROW 60010, N'Unable to create record (Job/Quote) as user does not belong to required OrgUnit group.', 1;
            END*/

            IF (@DefaultSecurityGroupId > 0)
            BEGIN
                INSERT INTO SCore.DataObjects
                    (Guid, RowStatus, EntityTypeId)
                SELECT
                    @OsGuid,
                    1,
                    et.ID
                FROM SCore.EntityHobts AS eh
                JOIN SCore.EntityTypes AS et ON (et.ID = eh.EntityTypeID)
                WHERE (eh.SchemaName = N'SCore')
                  AND (eh.ObjectName = N'ObjectSecurity');

                /* Add the default Security */
                INSERT SCore.ObjectSecurity
                    (RowStatus, Guid, ObjectGuid, UserId, GroupId, CanRead, DenyRead, CanWrite, DenyWrite)
                VALUES
                    (1, @OsGuid, @Guid, -1, @DefaultSecurityGroupId, 1, 0, 1, 0);
            END

            -- Always clear after use to prevent cross-call contamination (pooling)
            EXEC sys.sp_set_session_context @key = N'new_entity_type_guid', @value = NULL, @read_only = 0;
            EXEC sys.sp_set_session_context @key = N'record_guid',         @value = NULL, @read_only = 0;
        END;

        SET @IsInsert = 1;
        RETURN;
    END
END;
GO
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[tvf_WorkflowValidate]
(
    @Guid            UNIQUEIDENTIFIER,
    @Name            NVARCHAR(200),
    @Description     NVARCHAR(800),
    @EntityTypeGuid  UNIQUEIDENTIFIER,
    @IsEnabled       BIT,
    @OrgUnitGuid     UNIQUEIDENTIFIER
)
RETURNS @ValidationResult TABLE
(
    ID INT IDENTITY(1, 1) NOT NULL,
    TargetGuid UNIQUEIDENTIFIER NOT NULL DEFAULT ('00000000-0000-0000-0000-000000000000'),
    TargetType CHAR(1) NOT NULL DEFAULT (''),
    IsReadOnly BIT NOT NULL DEFAULT ((0)),
    IsHidden BIT NOT NULL DEFAULT ((0)),
    IsInvalid BIT NOT NULL DEFAULT ((0)),
    IsInformationOnly BIT NOT NULL DEFAULT ((0)),
    Message NVARCHAR(2000) NOT NULL DEFAULT ('')
)
    --WITH SCHEMABINDING
AS
BEGIN
    -- Get the entity type we work with - just the "Name" field.
    DECLARE @EntityTypeForWorkflow NVARCHAR(250) = N'';
    DECLARE @EntityTypeID INT = NULL;
    DECLARE @OrgUnitID INT = NULL;
    DECLARE @WorkflowID INT = NULL;

    -- SYSADM check (session-context user)
    DECLARE @UserID INT = -1;
    SELECT @UserID = ISNULL(CONVERT(INT, SESSION_CONTEXT(N'user_id')), -1);

    DECLARE @IsUserSysAdmin BIT = 0;
    IF EXISTS
    (
        SELECT 1
        FROM SCore.UserGroups ug
        JOIN SCore.Groups g ON g.ID = ug.GroupID
        WHERE ug.IdentityID = @UserID
          AND g.Code = N'SYSADM'
          AND ug.RowStatus = 1
          AND g.RowStatus = 1
    )
    BEGIN
        SET @IsUserSysAdmin = 1;
    END;

    -- Entity type name + ID.
    SELECT
        @EntityTypeForWorkflow = et.Name,
        @EntityTypeID = et.ID
    FROM SCore.EntityTypes et
    WHERE et.Guid = @EntityTypeGuid;

    -- Get the workflow ID (if exists)
    SELECT @WorkflowID = w.ID
    FROM SCore.Workflow w
    WHERE w.Guid = @Guid;

    -- OrgUnit ID
    SELECT @OrgUnitID = ou.ID
    FROM SCore.OrganisationalUnits ou
    WHERE ou.Guid = @OrgUnitGuid;

    -------------------------------------------------------------------------
    -- NEW WORKFLOW: show only basic fields and validate compulsory fields
    -------------------------------------------------------------------------
    IF (NOT EXISTS (SELECT 1 FROM SCore.Workflow WHERE Guid = @Guid))
    BEGIN
        -- Only show basic info fields.
        INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, IsInformationOnly, Message)
        SELECT DISTINCT
            epfvv.Guid,
            'P',
            0,
            1,
            0,
            0,
            N''
        FROM SCore.EntityPropertiesForValidationV epfvv
        WHERE epfvv.[Schema] = N'SCore'
          AND epfvv.Hobt     = N'Workflow'
          AND epfvv.Name NOT IN (N'Name', N'Description', N'EntityTypeID', N'OrganisationalUnitId');

        IF (@Name = N'')
        BEGIN
            INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, IsInformationOnly, Message)
            SELECT DISTINCT
                epfvv.Guid,
                'P',
                0,
                0,
                1,
                0,
                N'Name is compulsory.'
            FROM SCore.EntityPropertiesForValidationV epfvv
            WHERE epfvv.[Schema] = N'SCore'
              AND epfvv.Hobt     = N'Workflow'
              AND epfvv.Name IN (N'Name');
        END;

        IF (@EntityTypeGuid = '00000000-0000-0000-0000-000000000000')
        BEGIN
            INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, IsInformationOnly, Message)
            SELECT DISTINCT
                epfvv.Guid,
                'P',
                0,
                0,
                1,
                0,
                N'Entity Type is compulsory.'
            FROM SCore.EntityPropertiesForValidationV epfvv
            WHERE epfvv.[Schema] = N'SCore'
              AND epfvv.Hobt     = N'Workflow'
              AND epfvv.Name IN (N'EntityTypeID');
        END;
    END;

    -------------------------------------------------------------------------
    -- EXISTING WORKFLOW: lock EntityTypeID always + apply SYSADM readonly rule
    -------------------------------------------------------------------------
    IF (EXISTS (SELECT 1 FROM SCore.Workflow WHERE Guid = @Guid))
    BEGIN
        -- Lock entity type field (always, for everyone)
        INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, IsInformationOnly, Message)
        SELECT DISTINCT
            epfvv.Guid,
            'P',
            1,
            0,
            0,
            0,
            N''
        FROM SCore.EntityPropertiesForValidationV epfvv
        WHERE epfvv.[Schema] = N'SCore'
          AND epfvv.Hobt     = N'Workflow'
          AND epfvv.Name IN (N'EntityTypeID');

        -- System Default workflow rules
        IF (@OrgUnitID = -1 AND @IsUserSysAdmin = 0)
        BEGIN
            -- Non-SYSADM: make entire record readonly
            INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, IsInformationOnly, Message)
            SELECT DISTINCT
                epfvv.Guid,
                'P',
                1,
                0,
                0,
                0,
                N''
            FROM SCore.EntityPropertiesForValidationV epfvv
            WHERE epfvv.[Schema] = N'SCore'
              AND epfvv.Hobt     = N'Workflow';

            -- Hide org unit
            INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, IsInformationOnly, Message)
            SELECT DISTINCT
                epfvv.Guid,
                'P',
                1,
                1,
                0,
                0,
                N''
            FROM SCore.EntityPropertiesForValidationV epfvv
            WHERE epfvv.[Schema] = N'SCore'
              AND epfvv.Hobt     = N'Workflow'
              AND epfvv.Name IN (N'OrganisationalUnitId');
        END;
    END;

    -------------------------------------------------------------------------
    -- ENABLE RULES (unchanged behaviour, applies to SYSADM too)
    -------------------------------------------------------------------------
    IF (@IsEnabled = 1)
    BEGIN
        -- Already an enabled one for the entity type + org unit
        IF EXISTS
        (
            SELECT 1
            FROM SCore.Workflow
            WHERE Enabled = 1
              AND EntityTypeID = @EntityTypeID
              AND OrganisationalUnitId = @OrgUnitID
              AND Guid <> @Guid
        )
        BEGIN
            INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, IsInformationOnly, Message)
            SELECT DISTINCT
                epfvv.Guid,
                'P',
                0,
                0,
                1,
                0,
                N'There is already an active workflow for this entity type.'
            FROM SCore.EntityPropertiesForValidationV epfvv
            WHERE epfvv.[Schema] = N'SCore'
              AND epfvv.Hobt     = N'Workflow'
              AND epfvv.Name IN (N'Enabled');
        END
        -- No transitions for workflow
        ELSE IF (NOT EXISTS (SELECT 1 FROM SCore.WorkflowTransition wft WHERE wft.WorkflowID = @WorkflowID))
        BEGIN
            INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, IsInformationOnly, Message)
            SELECT DISTINCT
                epfvv.Guid,
                'P',
                0,
                0,
                1,
                0,
                N'No transitions for workflow - please, add transitions before enabling the workflow!'
            FROM SCore.EntityPropertiesForValidationV epfvv
            WHERE epfvv.[Schema] = N'SCore'
              AND epfvv.Hobt     = N'Workflow'
              AND epfvv.Name IN (N'Enabled');
        END;
    END;

    RETURN;
END;
GO
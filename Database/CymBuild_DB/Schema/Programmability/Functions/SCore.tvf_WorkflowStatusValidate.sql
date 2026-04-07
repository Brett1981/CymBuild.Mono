SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[tvf_WorkflowStatusValidate]
(
    @Guid UNIQUEIDENTIFIER,
    @OrganisationalUnitGuid UNIQUEIDENTIFIER
)
RETURNS @ValidationResult TABLE
(
    ID INT IDENTITY(1,1) NOT NULL,
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
    DECLARE @UserID INT = -1;

    SELECT @UserID =
        ISNULL(CONVERT(INT, SESSION_CONTEXT(N'user_id')), -1);

    DECLARE @IsUserSysAdmin BIT = 0;

    -- Check if the current user has System Admin privileges
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

    -- Non SYSADM: system-default WorkflowStatus records are read-only
    IF (@IsUserSysAdmin = 0)
    BEGIN
        IF (@OrganisationalUnitGuid = '00000000-0000-0000-0000-000000000000')
        BEGIN
            -- Disable fields (all properties)
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
              AND epfvv.Hobt     = N'WorkflowStatus';

            -- Add validation message on Enabled (use info-only rather than invalid, unless you WANT a hard error)
            INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, IsInformationOnly, Message)
            SELECT DISTINCT
                   epfvv.Guid,
                   'P',
                   0,
                   0,
                   0,
                   1,
                   N'Read-only. System default statuses cannot be edited!'
            FROM SCore.EntityPropertiesForValidationV epfvv
            WHERE epfvv.[Schema] = N'SCore'
              AND epfvv.Hobt     = N'WorkflowStatus'
              AND epfvv.Name     = N'Enabled';
        END;
    END;

    RETURN;
END;
GO
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[tvf_DataObjectTransitionValidate]
(
    @Guid           UNIQUEIDENTIFIER,
    @DataObjectGuid UNIQUEIDENTIFIER,
    @NewStatusGuid  UNIQUEIDENTIFIER,
    @Comment        NVARCHAR(MAX)
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
AS
BEGIN

    DECLARE @UserID INT = -1;

    SELECT
        @UserID = ISNULL(CONVERT(INT, SESSION_CONTEXT(N'user_id')), -1);

    -------------------------------------------------------------------------
    -- Hide everything but the comment when first saving the transition record
    -------------------------------------------------------------------------
    IF NOT EXISTS
    (
        SELECT 1
        FROM SCore.DataObjectTransition
        WHERE Guid = @Guid
    )
    BEGIN
        INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
        SELECT  epfvv.Guid,
                N'P',
                0,
                1,
                0,
                N''
        FROM SCore.EntityPropertiesForValidationV AS epfvv
        WHERE epfvv.[Schema] = N'SCore'
          AND epfvv.Hobt     = N'DataObjectTransition'
          AND epfvv.Name NOT IN (N'Comment');
    END;

    -------------------------------------------------------------------------
    -- Read-only -> if the user is not part of the SU group, they cannot edit
    -------------------------------------------------------------------------
    IF
    (
        @NewStatusGuid <> '00000000-0000-0000-0000-000000000000'
        AND EXISTS (SELECT 1 FROM SCore.DataObjectTransition WHERE Guid = @Guid)
        AND NOT EXISTS
        (
            SELECT 1
            FROM SCore.UserGroups AS ug
            JOIN SCore.Groups     AS g ON g.ID = ug.GroupID
            WHERE ug.IdentityID = @UserID
              AND g.Code = N'SU'
        )
    )
    BEGIN
        INSERT @ValidationResult (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
        SELECT  epfvv.Guid,
                N'P',
                1,
                0,
                0,
                N''
        FROM SCore.EntityPropertiesForValidationV AS epfvv
        WHERE epfvv.[Schema] = N'SCore'
          AND epfvv.Hobt     = N'DataObjectTransition';
    END;

    -------------------------------------------------------------------------
    -- Block Quote status "Ready to Send" unless Quote net value > 0
    -------------------------------------------------------------------------
    DECLARE @QuoteEntityTypeGuid UNIQUEIDENTIFIER = NULL;

    SELECT @QuoteEntityTypeGuid = et.Guid
    FROM SCore.EntityTypes et
    WHERE et.Name = N'Quotes';

    DECLARE @RecordEntityTypeGuid UNIQUEIDENTIFIER = NULL;

    SELECT TOP (1) @RecordEntityTypeGuid = et.Guid
    FROM SCore.DataObjects dob
    JOIN SCore.EntityTypes et ON et.ID = dob.EntityTypeId
    WHERE dob.Guid = @DataObjectGuid
      AND dob.RowStatus NOT IN (0,254);

    DECLARE @ReadyToSendStatusGuid UNIQUEIDENTIFIER = '02A2237F-2AE7-4E05-926F-38E8B7D050A0';

    IF (@RecordEntityTypeGuid = @QuoteEntityTypeGuid AND @NewStatusGuid = @ReadyToSendStatusGuid)
    BEGIN
        DECLARE @QuoteNetValue DECIMAL(18,2) = 0;

        SELECT
            @QuoteNetValue =
                ISNULL
                (
                    (
                        SELECT SUM(qit.LineNet)
                        FROM SSop.QuoteItemTotals AS qit
                        JOIN SSop.QuoteItems      AS qi ON qi.ID = qit.ID
                        JOIN SSop.Quotes          AS q  ON q.ID  = qi.QuoteId
                        WHERE q.Guid = @DataObjectGuid
                          AND qi.RowStatus NOT IN (0,254)
                    ),
                    0
                );

        IF (@QuoteNetValue <= 0)
        BEGIN
            DECLARE @StatusPropertyGuid UNIQUEIDENTIFIER = NULL;

            -- Prefer to attach to the StatusID field on the transition editor
            SELECT TOP (1) @StatusPropertyGuid = epfvv.Guid
            FROM SCore.EntityPropertiesForValidationV epfvv
            WHERE epfvv.[Schema] = N'SCore'
              AND epfvv.Hobt     = N'DataObjectTransition'
              AND epfvv.Name     = N'StatusID';

            IF (@StatusPropertyGuid IS NOT NULL)
            BEGIN
                INSERT @ValidationResult
                    (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, IsInformationOnly, Message)
                VALUES
                    (
                        @StatusPropertyGuid,
                        N'P',
                        0,
                        0,
                        1,
                        0,
                        N'Cannot set status to "Ready to Send" until the quote has at least one Quote Item with a net value greater than 0.'
                    );
            END
            ELSE
            BEGIN
                -- fallback: entity-level error
                INSERT @ValidationResult
                    (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, IsInformationOnly, Message)
                VALUES
                    (
                        '00000000-0000-0000-0000-000000000000',
                        N'E',
                        0,
                        0,
                        1,
                        0,
                        N'Cannot set status to "Ready to Send" until the quote has at least one Quote Item with a net value greater than 0.'
                    );
            END
        END
    END

    RETURN;
END;
GO
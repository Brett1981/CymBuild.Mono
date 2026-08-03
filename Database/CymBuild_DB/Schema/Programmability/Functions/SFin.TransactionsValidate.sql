SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SFin].[TransactionsValidate]')
GO
PRINT (N'Create function [SFin].[TransactionsValidate]')
GO
PRINT (N'Create function [SFin].[TransactionsValidate]')
GO

CREATE FUNCTION [SFin].[TransactionsValidate]
(
    @Guid UNIQUEIDENTIFIER,
    @AccountGuid UNIQUEIDENTIFIER,
    @TransactionTypeGuid UNIQUEIDENTIFIER,
    @Batched BIT
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
    DECLARE
        @EntityPropertyGuid UNIQUEIDENTIFIER,
        @TransactionsHoBTGuid UNIQUEIDENTIFIER,
        @CurrentUserId INT = SCore.GetCurrentUserId(),
        @CurrentUserIsFinance BIT = 0,
        @ExistingTransaction BIT = 0,
        @PersistedIsBatched BIT = 0,
        @PersistedIsApprovedFromBatch BIT = 0;

    SELECT
        @TransactionsHoBTGuid = eh.Guid
    FROM SCore.EntityHobts AS eh
    WHERE eh.SchemaName = N'SFin'
      AND eh.ObjectName = N'Transactions'
      AND eh.RowStatus NOT IN (0, 254);

    SELECT
        @ExistingTransaction = CONVERT(BIT, 1),
        @PersistedIsBatched = CONVERT(BIT, t.Batched)
    FROM SFin.Transactions AS t
    WHERE t.Guid = @Guid
      AND t.RowStatus NOT IN (0, 254);

    SELECT
        @CurrentUserIsFinance = CONVERT(BIT, 1)
    WHERE EXISTS
    (
        SELECT 1
        FROM SCore.UserGroups AS ug
        JOIN SCore.Groups AS g
          ON g.ID = ug.GroupID
        WHERE ug.IdentityID = @CurrentUserId
          AND ug.RowStatus NOT IN (0, 254)
          AND g.RowStatus NOT IN (0, 254)
          AND
          (
              g.Code = N'FINANCE'
              OR g.Name IN (N'Finance', N'Finance Group')
          )
    );

    /*
        Important:
        Use the persisted SFin.Transactions.Batched value, not the incoming @Batched value.

        This means a new unsaved transaction is never locked by this rule, even if
        the form currently has @Batched = 0.
    */
    IF @ExistingTransaction = 1
       AND @PersistedIsBatched = 0
    BEGIN
        SET @PersistedIsApprovedFromBatch = 1;
    END;

    /*
        Full transaction read-only rules:

        1. Existing approved/unbatched transactions are read-only for everyone.
        2. Existing transactions are read-only for non-Finance users.
        3. New transactions are not blocked because @ExistingTransaction must be 1.
    */
    IF @TransactionsHoBTGuid IS NOT NULL
       AND @ExistingTransaction = 1
       AND
       (
           @PersistedIsApprovedFromBatch = 1
           OR @CurrentUserIsFinance = 0
       )
    BEGIN
        INSERT @ValidationResult
        (
            TargetGuid,
            TargetType,
            IsReadOnly,
            IsHidden,
            IsInvalid,
            Message
        )
        VALUES
        (
            @TransactionsHoBTGuid,
            N'H',
            1,
            0,
            0,
            N''
        );
    END;

    -- Hide Terms for Bank Transactions
    IF EXISTS
    (
        SELECT 1
        FROM SFin.TransactionTypes AS tt
        WHERE tt.Guid = @TransactionTypeGuid
          AND tt.IsBank = 1
          AND tt.RowStatus NOT IN (0, 254)
    )
    BEGIN
        SELECT
            @EntityPropertyGuid = SCore.GetEntityPropertyGuid(N'SFin', N'Transactions', N'CreditTermsId');

        IF @EntityPropertyGuid IS NOT NULL
        BEGIN
            INSERT @ValidationResult
            (
                TargetGuid,
                TargetType,
                IsReadOnly,
                IsHidden,
                IsInvalid,
                Message
            )
            VALUES
            (
                @EntityPropertyGuid,
                N'P',
                0,
                1,
                0,
                N''
            );
        END;
    END;

    -- Account must have a Sage account code before use on transactions.
    IF EXISTS
    (
        SELECT 1
        FROM SCrm.Accounts AS a
        WHERE a.Guid = @AccountGuid
          AND a.Code = N''
          AND a.RowStatus NOT IN (0, 254)
    )
    BEGIN
        SELECT
            @EntityPropertyGuid = ep.Guid
        FROM SCore.EntityPropertiesV AS ep
        JOIN SCore.EntityHobtsV AS eh
          ON eh.ID = ep.EntityHoBTID
        WHERE eh.SchemaName = N'SFin'
          AND eh.ObjectName = N'Transactions'
          AND ep.Name = N'AccountID';

        IF @EntityPropertyGuid IS NOT NULL
        BEGIN
            INSERT @ValidationResult
            (
                TargetGuid,
                TargetType,
                IsReadOnly,
                IsHidden,
                IsInvalid,
                Message
            )
            VALUES
            (
                @EntityPropertyGuid,
                N'P',
                0,
                0,
                1,
                N'An account must have a Sage Account Code before it can be used on transactions.'
            );
        END;
    END;

    RETURN;
END;
GO
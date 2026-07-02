SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SFin].[TransactionDetailsValidate]')
GO

CREATE FUNCTION [SFin].[TransactionDetailsValidate]
(
    @Guid UNIQUEIDENTIFIER,
    @TransactionGuid UNIQUEIDENTIFIER
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
        @CurrentUserId INT = SCore.GetCurrentUserId(),
        @CurrentUserIsFinance BIT = 0,
        @TransactionDetailsHoBTGuid UNIQUEIDENTIFIER,
        @ExistingTransactionDetail BIT = 0,
        @ParentIsBatched BIT = NULL,
        @IsReadOnly BIT = 0,
        @IsInvalid BIT = 0,
        @ValidationMessage NVARCHAR(2000) = N'';

    SELECT
        @TransactionDetailsHoBTGuid = eh.Guid
    FROM SCore.EntityHobts AS eh
    WHERE eh.SchemaName = N'SFin'
      AND eh.ObjectName = N'TransactionDetails'
      AND eh.RowStatus NOT IN (0, 254);

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
        Existing detail row:
        Resolve the parent transaction from the persisted TransactionID.
    */
    SELECT
        @ExistingTransactionDetail = CONVERT(BIT, 1),
        @ParentIsBatched = CONVERT(BIT, t.Batched)
    FROM SFin.TransactionDetails AS td
    JOIN SFin.Transactions AS t
      ON t.ID = td.TransactionID
    WHERE td.Guid = @Guid
      AND td.RowStatus NOT IN (0, 254)
      AND t.RowStatus NOT IN (0, 254);

    /*
        New detail row:
        Resolve the parent transaction from the incoming TransactionGuid.
    */
    IF @ExistingTransactionDetail = 0
       AND @TransactionGuid IS NOT NULL
       AND @TransactionGuid <> '00000000-0000-0000-0000-000000000000'
    BEGIN
        SELECT
            @ParentIsBatched = CONVERT(BIT, t.Batched)
        FROM SFin.Transactions AS t
        WHERE t.Guid = @TransactionGuid
          AND t.RowStatus NOT IN (0, 254);
    END;

    /*
        Non-Finance:
          - Existing detail rows are read-only.
          - New detail rows are blocked.

        Finance:
          - Existing detail rows remain editable, even when parent transaction is approved / Batched = 0.
          - New detail rows are blocked once parent transaction is approved / Batched = 0.
    */
    IF @CurrentUserIsFinance = 0
    BEGIN
        SET @IsReadOnly = 1;

        IF @ExistingTransactionDetail = 0
        BEGIN
            SET @IsInvalid = 1;
            SET @ValidationMessage = N'Only Finance users can create transaction details.';
        END;
    END;

    IF @CurrentUserIsFinance = 1
       AND @ExistingTransactionDetail = 0
       AND @ParentIsBatched = 0
    BEGIN
        SET @IsInvalid = 1;
        SET @ValidationMessage = N'Transaction details cannot be added once the transaction has been approved from batched status.';
    END;

    IF @TransactionDetailsHoBTGuid IS NOT NULL
       AND
       (
           @IsReadOnly = 1
           OR @IsInvalid = 1
       )
    BEGIN
        INSERT @ValidationResult
        (
            TargetGuid,
            TargetType,
            IsReadOnly,
            IsHidden,
            IsInvalid,
            IsInformationOnly,
            Message
        )
        VALUES
        (
            @TransactionDetailsHoBTGuid,
            N'H',
            @IsReadOnly,
            0,
            @IsInvalid,
            0,
            @ValidationMessage
        );
    END;

    RETURN;
END;
GO
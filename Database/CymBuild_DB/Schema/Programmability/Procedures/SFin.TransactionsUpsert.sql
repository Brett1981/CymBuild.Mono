SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[TransactionsUpsert]')
GO
CREATE PROCEDURE [SFin].[TransactionsUpsert]
(
    @AccountGuid UNIQUEIDENTIFIER,
    @JobGuid UNIQUEIDENTIFIER,
    @TransactionTypeGuid UNIQUEIDENTIFIER,
    @Date DATE,
    @PurchaseOrderNumber NVARCHAR(28),
    @SageTransactionReference NVARCHAR(50),
    @OrganisationalUnitGuid UNIQUEIDENTIFIER,
    @CreatedByUserGuid UNIQUEIDENTIFIER,
    @SurveyorGuid UNIQUEIDENTIFIER,
    @CreditTermsGuid UNIQUEIDENTIFIER,
    @Guid UNIQUEIDENTIFIER,
    @Batched BIT,
	@ExpectedDate DATE
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AccountID INT,
            @JobID INT,
            @TransactionTypeId SMALLINT,
            @IsInsert BIT = 0,
            @TranNo INT,
            @OrganisationalUnitId INT,
            @DepartmentPrefix NVARCHAR(10),
            @CreatedByUserId INT,
            @SurveyorUserId INT,
            @CreditTermsId INT,
            @ExistingBatched BIT,
            @ExistingAccountID INT,
            @ExistingJobID INT,
            @TransactionID BIGINT,
            @EnsureQueuedComment NVARCHAR(MAX);

    SELECT  @AccountID = ID
    FROM    SCrm.Accounts
    WHERE   [Guid] = @AccountGuid;

    SELECT  @JobID = ID
    FROM    SJob.Jobs
    WHERE   [Guid] = @JobGuid;

    SELECT  @TransactionTypeId = ID
    FROM    SFin.TransactionTypes
    WHERE   [Guid] = @TransactionTypeGuid;

    SELECT  @CreatedByUserId = ID
    FROM    SCore.Identities
    WHERE   [Guid] = @CreatedByUserGuid;

    SELECT  @SurveyorUserId = ID
    FROM    SCore.Identities
    WHERE   [Guid] = @SurveyorGuid;

    SELECT  @CreditTermsId = ID
    FROM    SFin.CreditTerms
    WHERE   [Guid] = @CreditTermsGuid;

    SELECT  @OrganisationalUnitId = ID,
            @DepartmentPrefix = DepartmentPrefix
    FROM    SCore.OrganisationalUnits ou
    WHERE   ou.Guid = @OrganisationalUnitGuid;

    EXEC SCore.UpsertDataObject
         @Guid = @Guid,
         @SchemeName = N'SFin',
         @ObjectName = N'Transactions',
         @IsInsert = @IsInsert OUTPUT;

    IF (@IsInsert = 1)
    BEGIN
        INSERT SFin.Transactions
        (
            RowStatus,
            Guid,
            TransactionTypeID,
            AccountID,
            JobID,
            Number,
            Date,
            PurchaseOrderNumber,
            SageTransactionReference,
            OrganisationalUnitId,
            CreatedByUserId,
            SurveyorUserId,
            CreditTermsId,
            Batched,
			ExpectedDate
        )
        VALUES
        (
            0,
            @Guid,
            @TransactionTypeId,
            @AccountID,
            @JobID,
            0,
            @Date,
            @PurchaseOrderNumber,
            @SageTransactionReference,
            @OrganisationalUnitId,
            @CreatedByUserId,
            @SurveyorUserId,
            @CreditTermsId,
            1,
			@ExpectedDate
        );
    END
    ELSE
    BEGIN
        SELECT  @TransactionID = t.ID,
                @ExistingBatched = t.Batched,
                @ExistingAccountID = t.AccountID,
                @ExistingJobID = t.JobID
        FROM    SFin.Transactions t
        WHERE   t.Guid = @Guid;

        UPDATE  SFin.Transactions
        SET     Date = @Date,
                JobID = @JobID,
                PurchaseOrderNumber = @PurchaseOrderNumber,
                SageTransactionReference = @SageTransactionReference,
                SurveyorUserId = @SurveyorUserId,
                CreditTermsId = @CreditTermsId,
                Batched = @Batched,
				ExpectedDate = @ExpectedDate,
                AccountID = CASE
                                WHEN @ExistingBatched = 1 THEN @AccountID
                                ELSE AccountID
                            END
        WHERE   [Guid] = @Guid;

        IF (@ExistingBatched = 1 AND ISNULL(@ExistingAccountID, -1) <> ISNULL(@AccountID, -1))
        BEGIN
            UPDATE  SJob.Jobs
            SET     FinanceAccountID = @AccountID
            WHERE   ID = @ExistingJobID;
        END

        IF (ISNULL(@Batched, 1) = 0)
        BEGIN
            SET @EnsureQueuedComment =
                CASE
                    WHEN ISNULL(@ExistingBatched, 0) = 1
                        THEN N'Finance approval detected from TransactionsUpsert Batched 1 to 0.'
                    ELSE N'Finance approval repair detected from TransactionsUpsert for already unbatched transaction.'
                END;

            EXEC SFin.TransactionSageSubmission_EnsureQueued
                 @TransactionID = @TransactionID,
                 @TransactionGuid = @Guid,
                 @CreatedByUserId = @CreatedByUserId,
                 @SurveyorUserId = @SurveyorUserId,
                 @Comment = @EnsureQueuedComment,
                 @SuppressResult = 1;
        END
    END

    IF (@IsInsert = 1)
    BEGIN
        SELECT @TranNo = NEXT VALUE FOR SFin.TransactionNumber;

        UPDATE  SFin.Transactions
        SET     Number = @DepartmentPrefix + CONVERT(NVARCHAR(30), @TranNo),
                RowStatus = 1
        WHERE   [Guid] = @Guid;
    END
END
GO
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
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
	@Batched BIT
)
AS 
BEGIN 
    DECLARE @AccountID INT,
			@JobID INT,
			@TransactionTypeId SMALLINT,
			@IsInsert BIT = 0,
			@TranNo INT,
			@OrganisationalUnitId INT,
			@DepartmentPrefix NVARCHAR(10),
			@CreatedByUserId INT,
			@SurveyorUserId INT,
			@CreditTermsId INT

    SELECT  @AccountID = ID 
    FROM    SCrm.Accounts
    WHERE   ([Guid] = @AccountGuid)

	SELECT  @JobID = ID 
    FROM    SJob.Jobs
    WHERE   ([Guid] = @JobGuid)

	SELECT  @TransactionTypeId = ID 
    FROM    SFin.TransactionTypes
    WHERE   ([Guid] = @TransactionTypeGuid)

	SELECT	@CreatedByUserId = ID 
	FROM	SCore.Identities 
	WHERE	(GUID = @CreatedByUserGuid)

	SELECT	@SurveyorUserId = ID 
	FROM	SCore.Identities 
	WHERE	(Guid = @SurveyorGuid)

	SELECT	@CreditTermsId = ID 
	FROM	SFin.CreditTerms
	WHERE	(Guid = @CreditTermsGuid)

	SELECT	@OrganisationalUnitId = ID, 
			@DepartmentPrefix = DepartmentPrefix 
	FROM	SCore.OrganisationalUnits ou 
	WHERE	(ou.Guid = @OrganisationalUnitGuid)

    EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
							@SchemeName = N'SFin',				-- nvarchar(255)
							@ObjectName = N'Transactions',				-- nvarchar(255)
							@IsInsert = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
    BEGIN
		INSERT SFin.Transactions
			 (RowStatus, Guid, TransactionTypeID, AccountID, JobID, Number, Date, PurchaseOrderNumber, SageTransactionReference, OrganisationalUnitId, CreatedByUserId, SurveyorUserId, CreditTermsId, Batched)
		VALUES
			 (
				 0,	-- RowStatus - tinyint
				 @Guid,	-- Guid - uniqueidentifier
				 @TransactionTypeId,	-- TransactionTypeID - smallint
				 @AccountID,	-- AccountID - int
				 @JobID,	-- JobID - int
				 0,	-- Number - int
				 @Date,	-- Date - date
				 @PurchaseOrderNumber,
				 @SageTransactionReference,
				 @OrganisationalUnitId,
				 @CreatedByUserId,
				 @SurveyorUserId,
				 @CreditTermsId,
				 1 --Batched
			 )
    END
    ELSE
    BEGIN 
        UPDATE  SFin.Transactions
        SET     Date = @Date,
				JobID = @JobID,
				PurchaseOrderNumber = @PurchaseOrderNumber, 
				SageTransactionReference = @SageTransactionReference,
				SurveyorUserId = @SurveyorUserId,
				CreditTermsId = @CreditTermsId,
				Batched = @Batched
        WHERE   ([Guid] = @Guid)
    END

	IF (@IsInsert = 1)
    BEGIN 
        SELECT @TranNo = NEXT VALUE FOR SFin.TransactionNumber

        UPDATE  SFin.Transactions
        SET     Number = @DepartmentPrefix + CONVERT(NVARCHAR(30), @TranNo),
				RowStatus = 1
        WHERE   ([Guid] = @Guid)
    END
END
GO
SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SSop].[ContractsUpsert]
(
    @AccountGuid UNIQUEIDENTIFIER,
	@SignatoryGuid UNIQUEIDENTIFIER,
	@Details NVARCHAR(2000),
	@StartDate DATE,
	@EndDate DATE, 
	@NextReviewDate DATE,
	@PriceListGuid UNIQUEIDENTIFIER,
    @Guid UNIQUEIDENTIFIER,
	@ContractTypeGuid UNIQUEIDENTIFIER
)
AS 
BEGIN 
    DECLARE @AccountID INT,
			@SignatoryID INT,
			@PriceListId INT,
			@ContractTypeID INT

    SELECT  @AccountID = ID 
    FROM    SCrm.Accounts
    WHERE   ([Guid] = @AccountGuid)

	SELECT  @SignatoryID = ID 
    FROM    SCore.Identities
    WHERE   ([Guid] = @SignatoryGuid)

	SELECT  @PriceListId = ID 
    FROM    SSop.PriceLists
    WHERE   ([Guid] = @PriceListGuid)

	SELECT @ContractTypeID = ID
	FROM SSop.ContractTypes
	WHERE ([Guid] = @ContractTypeGuid);

    DECLARE @IsInsert BIT
    EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
							@SchemeName = N'SSop',				-- nvarchar(255)
							@ObjectName = N'Contracts',				-- nvarchar(255)
							@IsInsert = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
    BEGIN
		INSERT SSop.Contracts
			 (RowStatus, Guid, AccountID, StartDate, EndDate, NextReviewDate, SignatoryId, Details, PriceListId, ContractTypeId)
		VALUES
			 (
				 1,	-- RowStatus - tinyint
				 @Guid,	-- Guid - uniqueidentifier
				 @AccountID,	-- AccountID - int
				 @StartDate,	-- StartDate - date
				 @EndDate,		-- EndDate - date
				 @NextReviewDate,	-- NextReviewDate - date
				 @SignatoryID,	-- SignatoryId - int
				 @Details,	-- Details - nvarchar(2000)
				 @PriceListId,	-- PriceListId - int
				 @ContractTypeID --ContractTypeID -INT
			 )
    END
    ELSE
    BEGIN 
        UPDATE  SSop.Contracts
        SET     AccountID = @AccountID,
				StartDate = @StartDate,
				EndDate = @EndDate,
				NextReviewDate = @NextReviewDate,
				SignatoryID = @SignatoryID,
				Details = @Details,
				PriceListId = @PriceListId,
				ContractTypeId = @ContractTypeID
        WHERE   ([Guid] = @Guid)
    END
END
GO
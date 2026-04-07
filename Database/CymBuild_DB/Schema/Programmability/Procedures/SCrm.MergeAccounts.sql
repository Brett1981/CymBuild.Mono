SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCrm].[MergeAccounts]
(
	@FromAccountGuid UNIQUEIDENTIFIER,
	@ToAccountGuid UNIQUEIDENTIFIER
)
AS
BEGIN 
	DECLARE	@FromAccountID INT,
			@ToAccountID INT

	SELECT	@FromAccountID = ID
	FROM	SCrm.Accounts
	WHERE	(guid = @FromAccountGuid)

	SELECT	@ToAccountID = ID 
	FROM	SCrm.Accounts
	WHERE	(Guid = @ToAccountGuid)

	UPDATE	SJob.Jobs
	SET		ClientAccountID = @ToAccountID
	WHERE	(ClientAccountID = @FromAccountID)

	UPDATE	SJob.Jobs
	SET		AgentAccountID = @ToAccountID
	WHERE	(AgentAccountID = @FromAccountID)

	UPDATE	SJob.Jobs
	SET		FinanceAccountID = @ToAccountID
	WHERE	(FinanceAccountID = @FromAccountID)

	UPDATE	SFin.Transactions 
	SET		AccountID = @ToAccountID
	WHERE	(AccountID = @FromAccountID)

	UPDATE	SSop.Enquiries 
	SET		ClientAccountId = @ToAccountID
	WHERE	(ClientAccountId = @FromAccountID)

	UPDATE	SSop.Enquiries 
	SET		AgentAccountId = @ToAccountID
	WHERE	(AgentAccountId = @FromAccountID)

	UPDATE	SSop.Enquiries 
	SET		FinanceAccountID = @ToAccountID
	WHERE	(FinanceAccountID = @FromAccountID)

	UPDATE	aa
	SET		AccountID = @ToAccountID
	FROM	SCrm.AccountAddresses aa
	WHERE	(aa.AccountID = @FromAccountID)
		AND	(NOT EXISTS
				(
					SELECT	1
					FROM	SCrm.AccountAddresses aa2
					WHERE	(aa2.AccountID = @ToAccountID)
						AND	(aa2.AddressID = aa.AddressID)
						AND	(aa2.ID <> aa.ID)
				)
			)

	UPDATE	ac
	SET		AccountID = @ToAccountID
	FROM	SCrm.AccountContacts ac
	WHERE	(ac.AccountID = @FromAccountID)
		AND	(NOT EXISTS
				(
					SELECT	1
					FROM	SCrm.AccountContacts ac2
					WHERE	(ac2.AccountID = @ToAccountID)
						AND	(ac2.ContactID = ac.ContactID)
						AND	(ac2.ID <> ac.ID)
				)
			)

	UPDATE	SCrm.AccountMemos 
	SET		AccountID = @ToAccountID
	WHERE	(AccountID = @FromAccountID)

	/*UPDATE SCrm.AccountProjectDirectoryRoles 
	SET		AccountID = @ToAccountID
	WHERE	(AccountID = @FromAccountID)*/

	UPDATE SJob.ProjectDirectory
	SET		AccountID = @ToAccountID 
	WHERE	(AccountID = @FromAccountID)

	UPDATE	SFin.FinanceMemo
	SET		AccountID = @ToAccountID
	WHERE	(AccountID = @FromAccountID)

	UPDATE	SCrm.Accounts
	SET		RowStatus = 254
	WHERE	(ID = @FromAccountID)
		
END
GO
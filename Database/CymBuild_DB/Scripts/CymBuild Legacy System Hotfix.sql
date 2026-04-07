BEGIN TRAN 


EXEC sys.sp_set_session_context @key = 'S_disable_triggers',
								@value = 1;

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [SCore].[LegacySystems](
	[ID] [INT] IDENTITY(1,1) NOT NULL,
	[Guid] [UNIQUEIDENTIFIER] NOT NULL,
	[Name] [NVARCHAR](50) NOT NULL,
 CONSTRAINT [PK_LegacySystems] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO


ALTER TABLE [SCore].[LegacySystems] ADD  CONSTRAINT [DF_LegacySystems_Guid]  DEFAULT (NEWID()) FOR [Guid]
GO

ALTER TABLE [SCore].[LegacySystems] ADD  CONSTRAINT [DF_LegacySystems_Name]  DEFAULT ('') FOR [Name]
GO


EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'LegacySystems' , @level0type=N'SCHEMA',@level0name=N'SCore', @level1type=N'TABLE',@level1name=N'LegacySystems'
GO


SET IDENTITY_INSERT SCore.LegacySystems ON; 
GO

INSERT	SCore.LegacySystems
	 (ID, Guid, Name)
VALUES
	 (
			-1,
		 '00000000-0000-0000-0000-000000000000',	-- Guid - uniqueidentifier
		 N''	-- Name - nvarchar(50)
	 )

SET IDENTITY_INSERT SCore.LegacySystems OFF
GO

INSERT SCore.LegacySystems
	 (Guid, Name)
VALUES
	 (
		 '103C776E-78BE-484C-A9F1-E56DF1FE37DD',	-- Guid - uniqueidentifier
		 N'Shore Inspections'	-- Name - nvarchar(50)
	 ),
	 (
		'D79B1B8C-D8FC-413F-931F-B25DA69948F1',
		N'Socotec Deltek Workspace'
	 )
	 	 

/* Transactions */
ALTER TABLE	SFin.Transactions
ADD	LegacySystemID INT NOT NULL DEFAULT (-1)
GO 


/* Transaction Details */
ALTER TABLE	SFin.TransactionDetails
ADD	LegacySystemID INT NOT NULL DEFAULT (-1)
GO

/* Actions */
ALTER TABLE	SJob.Actions
ADD	LegacySystemID INT NOT NULL DEFAULT (-1)
GO

/* Addresses */
ALTER TABLE	SCrm.Addresses
ADD	LegacySystemID INT NOT NULL DEFAULT (-1)
GO

/* Invoice Request Items */
ALTER TABLE	SFin.InvoiceRequestItems
ADD	LegacySystemID INT NOT NULL DEFAULT (-1)
GO

/* Quotes */
ALTER TABLE	SSop.Quotes
ADD	LegacySystemID INT NOT NULL DEFAULT (-1)
GO

/* Invoice Requests */
ALTER TABLE	SFin.InvoiceRequests
ADD	LegacySystemID INT NOT NULL DEFAULT (-1)
GO

/* Accounts */
ALTER TABLE	SCrm.Accounts
ADD	LegacySystemID INT NOT NULL DEFAULT (-1)
GO

/* Properties */
ALTER TABLE	SJob.Properties
ADD	LegacySystemID INT NOT NULL DEFAULT (-1)
GO

/* Quote Items */
ALTER TABLE	SSop.QuoteItems
ADD	LegacySystemID INT NOT NULL DEFAULT (-1)
GO

/* Finance Memo */
ALTER TABLE	SFin.FinanceMemo
ADD	LegacySystemID INT NOT NULL DEFAULT (-1)
GO

/* Contacts */
ALTER TABLE	SCrm.Contacts
ADD	LegacySystemID INT NOT NULL DEFAULT (-1)
GO

/* Quote Memos */
ALTER TABLE	SSop.QuoteMemos
ADD	LegacySystemID INT NOT NULL DEFAULT (-1)
GO

/* Activities */
ALTER TABLE	SJob.Activities
ADD	LegacySystemID INT NOT NULL DEFAULT (-1)
GO

/* Job Memos */
ALTER TABLE	SJob.JobMemos
ADD	LegacySystemID INT NOT NULL DEFAULT (-1)
GO

/* Quote Sections */
ALTER TABLE	SSop.QuoteSections
ADD	LegacySystemID INT NOT NULL DEFAULT (-1)
GO

/* Jobs */
ALTER TABLE	SJob.Jobs
ADD	LegacySystemID INT NOT NULL DEFAULT (-1)
GO 

DECLARE @ShoreCDMID int 

SELECT	@ShoreCDMID = ID
FROM	SCore.LegacySystems AS ls
WHERE	(ls.Guid = '103C776E-78BE-484C-A9F1-E56DF1FE37DD')

UPDATE	SFin.Transactions
SET		LegacySystemID = @ShoreCDMID
WHERE	(LegacyId IS NOT NULL)
	AND	(ID > 0)

UPDATE	SFin.TransactionDetails
SET		LegacySystemID = @ShoreCDMID
WHERE	(LegacyId IS NOT NULL)
	AND	(ID > 0)

UPDATE	SJob.Actions
SET		LegacySystemID = @ShoreCDMID
WHERE	(LegacyId IS NOT NULL)
	AND	(ID > 0)

UPDATE	SCrm.Addresses
SET		LegacySystemID = @ShoreCDMID
WHERE	(LegacyId IS NOT NULL)
	AND	(ID > 0)

UPDATE	SFin.InvoiceRequestItems
SET		LegacySystemID = @ShoreCDMID
WHERE	(LegacyId IS NOT NULL)
	AND	(ID > 0)

UPDATE	SSop.Quotes
SET		LegacySystemID = @ShoreCDMID
WHERE	(LegacyId IS NOT NULL)
	AND	(ID > 0)

UPDATE	SFin.InvoiceRequests
SET		LegacySystemID = @ShoreCDMID
WHERE	(LegacyId IS NOT NULL)
	AND	(ID > 0)

UPDATE	SCrm.Accounts
SET		LegacySystemID = @ShoreCDMID
WHERE	(LegacyId IS NOT NULL)
	AND	(ID > 0)

UPDATE	SJob.Properties
SET		LegacySystemID = @ShoreCDMID
WHERE	(LegacyId IS NOT NULL)
	AND	(ID > 0)

UPDATE	SSop.QuoteItems
SET		LegacySystemID = @ShoreCDMID
WHERE	(LegacyId IS NOT NULL)
	AND	(ID > 0)

UPDATE	SFin.FinanceMemo
SET		LegacySystemID = @ShoreCDMID
WHERE	(LegacyId IS NOT NULL)
	AND	(ID > 0)

UPDATE	SCrm.Contacts
SET		LegacySystemID = @ShoreCDMID
WHERE	(LegacyId IS NOT NULL)
	AND	(ID > 0)

UPDATE	SSop.QuoteMemos
SET		LegacySystemID = @ShoreCDMID
WHERE	(LegacyId IS NOT NULL)
	AND	(ID > 0)

UPDATE	SJob.Activities
SET		LegacySystemID = @ShoreCDMID
WHERE	(LegacyId IS NOT NULL)
	AND	(ID > 0)

UPDATE	SJob.JobMemos
SET		LegacySystemID = @ShoreCDMID
WHERE	(LegacyId IS NOT NULL)
	AND	(ID > 0)

UPDATE	SSop.QuoteSections
SET		LegacySystemID = @ShoreCDMID
WHERE	(LegacyId IS NOT NULL)
	AND	(ID > 0)

UPDATE	SJob.Jobs
SET		LegacySystemID = @ShoreCDMID
WHERE	(LegacyId IS NOT NULL)
	AND	(ID > 0)


-- COMMIT TRAN 
-- ROLLBACK TRAN 
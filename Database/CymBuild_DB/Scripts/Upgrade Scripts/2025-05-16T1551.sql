SET CONCAT_NULL_YIELDS_NULL, ANSI_NULLS, ANSI_PADDING, QUOTED_IDENTIFIER, ANSI_WARNINGS, ARITHABORT, XACT_ABORT ON
SET NUMERIC_ROUNDABORT, IMPLICIT_TRANSACTIONS OFF
GO

--
-- Start Transaction
--
BEGIN TRANSACTION
GO

DECLARE @Guid UNIQUEIDENTIFIER  = '34A1B864-1A47-40FB-B9AB-31912E5310D3';
EXEC SCore.GroupUpsert @Name = N'Job Superusers',			-- nvarchar(250)
					   @Code = N'JOBSU',			-- nvarchar(50)
					   @DirectoryId = N'',	-- nvarchar(100)
					   @Guid = @Guid OUTPUT -- uniqueidentifier

SET @Guid = '28FD4F2E-5201-42A2-B712-45B167CDF4D4';
EXEC SCore.GroupUpsert @Name = N'Quote Superusers',			-- nvarchar(250)
					   @Code = N'QUOTESU',			-- nvarchar(50)
					   @DirectoryId = N'',	-- nvarchar(100)
					   @Guid = @Guid OUTPUT -- uniqueidentifier

SET @Guid = '8936FEF3-4452-4EB2-8C71-D0C7C2B4BEB6';
EXEC SCore.GroupUpsert @Name = N'Enquiry Superusers',			-- nvarchar(250)
					   @Code = N'ENQUIRYSU',			-- nvarchar(50)
					   @DirectoryId = N'',	-- nvarchar(100)
					   @Guid = @Guid OUTPUT -- uniqueidentifier

GO
IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END
GO

--
-- Commit Transaction
--
IF @@TRANCOUNT>0 COMMIT TRANSACTION
GO

--
-- Set NOEXEC to off
--
SET NOEXEC OFF
GO

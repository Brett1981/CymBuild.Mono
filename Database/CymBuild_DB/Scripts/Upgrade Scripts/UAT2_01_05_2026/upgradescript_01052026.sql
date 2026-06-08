BEGIN TRANSACTION;

/*
	Creates the SVC user if not already in the system.
*/

IF(NOT EXISTS(SELECT 1 FROM SCore.Identities WHERE Guid = '1E7A4894-54AA-4CB4-9E54-C697ABB32F74'))
	BEGIN
		DECLARE 
				@FullName NVARCHAR(250) = N'SVC_Concursus',
				@EmailAddress NVARCHAR(150) = N'SVC_Concursus@socotec.co.uk',
				@JobTitle NVARCHAR(50) = N'',
				@OriganisationalUnitGuid UNIQUEIDENTIFIER = N'B60A3EB9-7925-4B71-80B6-205CB2F9B742',
				@IsActive BIT = 1,
				@ContactGuid UNIQUEIDENTIFIER = N'00000000-0000-0000-0000-000000000000',
				@BillableRate DECIMAL(19,2) = 0.00,
				@Guid UNIQUEIDENTIFIER = N'1E7A4894-54AA-4CB4-9E54-C697ABB32F74'

				EXEC [SCore].[IdentityUpsert] 
								@FullName, 
								@EmailAddress, 
								@JobTitle, 
								@OriganisationalUnitGuid, 
								@IsActive, 
								@ContactGuid, 
								@BillableRate, 
								@Guid
	END;




COMMIT;
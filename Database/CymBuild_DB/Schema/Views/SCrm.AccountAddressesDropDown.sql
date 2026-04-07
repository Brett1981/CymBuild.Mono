SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SCrm].[AccountAddressesDropDown]
   --WITH SCHEMABINDING
AS
SELECT	aa.RowStatus,
		aa.Guid,
		ad.FormattedAddressComma AS Name,
		a.Guid					 AS AccountGuid
FROM	SCrm.AccountAddresses AS aa
JOIN	SCrm.Accounts		  AS a ON (a.ID	  = aa.AccountID)
JOIN	SCrm.Addresses		  AS ad ON (ad.ID = aa.AddressID)
WHERE	(ad.RowStatus NOT IN (0, 254))
	--AND	(a.RowStatus NOT IN (0, 254))
	AND (aa.RowStatus NOT IN (0, 254));
GO
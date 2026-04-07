SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SCrm].[AddressesDropDown]
             --WITH SCHEMABINDING
AS
SELECT	a.RowStatus,
		a.Guid, 
		CONVERT(nvarchar(100), a.Number) + N' - ' + FormattedAddressComma as Name
FROM	SCrm.Addresses a
GO
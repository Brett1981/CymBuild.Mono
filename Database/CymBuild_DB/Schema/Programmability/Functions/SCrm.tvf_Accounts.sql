SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCrm].[tvf_Accounts]
  (
    @UserId INT
  )
RETURNS TABLE
   --WITH SCHEMABINDING
AS
  RETURN
  SELECT
          a.ID,
          a.RowStatus,
          a.Guid,
          a.Code,
          a.Name,
          astat.Name               AS AccountStatusName,
          rm.FullName              AS RelationshipManagerName,
          ad.FormattedAddressComma AS MainAddress,
          c.DisplayName            AS MainContact
  FROM
          SCrm.Accounts a
  JOIN
          SCrm.AccountStatus astat ON (a.AccountStatusID = astat.ID)
  JOIN
          SCore.Identities rm ON (rm.ID = a.RelationshipManagerUserId)
  JOIN
          SCrm.AccountAddresses aa ON (aa.ID = a.MainAccountAddressId)
  JOIN
          SCrm.Addresses ad ON (ad.ID = aa.AddressID)
  JOIN
          SCrm.AccountContacts ac ON (ac.ID = a.MainAccountContactId)
  JOIN
          SCrm.Contacts c ON (c.ID = ac.ContactID)
  WHERE
          (a.RowStatus NOT IN (0, 254))
          AND (aa.RowStatus NOT IN (0, 254))
          AND (ac.RowStatus NOT IN (0, 254))
          AND (a.ID > 0)
          AND (EXISTS
          (
              SELECT
                      1
              FROM
                      SCore.ObjectSecurityForUser_CanRead(a.Guid, @UserId) oscr
          )
          )
GO
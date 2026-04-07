## CymBuild CRM Account Migration from Shore Inspections ##

__author__ = "Richard Brindley"
__copyright__ = "Copyright 2024, Socotec UK"
__version__ = "1.0.1"


from common import *

def migrate_accounts():

    records = fetch_accounts()

    for r in records:
        
        account_guid = upsert_account(r['Title'], r['LA'], r['FA'], r['WA'], r['ContractorID'])
        address_guid, account_address_guid = upsert_address("", "", r['Address1'], r['Address2'], r['Address3'], r['Town'], r['County'], r['Postcode'], ['Country'], account_guid, r['ContractorID'])
        upsert_contact("", "", r['ContactName'], account_guid, address_guid, r['ContractorID'], account_address_guid)

def fetch_accounts():
    sql_query = """
    SELECT	c.[Contractor ID] AS ContractorID,
            c.Title,
            c.[Address 1] AS Address1,
            c.[Address 2] AS Address2,
            c.[Address 3] AS Address3, 
            c.Town,
            c.County,
            c.Postcode,
            c.Phone,
            c.Fax,
            c.email, 
            c.Memo,
            c.[Contact Name] AS ContactName, 
            c.SpecialFeeInstructions,
            c.AgentInvoiceInstructions,
            c.[F/A] AS FA,
            c.[W/A] AS WA,
            c.[L/A] AS LA
    FROM	dbo.[tbl Contractors] c
    WHERE	((EXISTS
                (
                    SELECT	1
                    FROM	dbo.ShoreJob sj
                    WHERE	(EXISTS 
                                (
                                    select 1 from SJob.JobTypes jt
                                    where	(jt.Name IN (N'SOCOTEC BCC', N'SOCOTEC HRB'))
                                        AND	(jt.ID = sj.[App type ID])
                                )
                            )
                        AND	(
                                (sj.[Client ID] = c.[Contractor ID])
                                OR (sj.[Agent ID] = c.[Contractor ID])
                            )
                )
            )
		OR	(EXISTS
				(
					SELECT	1
					FROM	dbo.Quote AS q
					JOIN	dbo.QuoteItem AS qi ON (qi.[Job ID] = q.[Job ID])
					WHERE	(EXISTS 
                                (
                                    select 1 from dbo.[tbl QuoteTypes] AS tqt 
                                    where	(tqt.Type IN (N'SOCOTEC BCC', N'SOCOTEC HRB'))
                                        AND	(tqt.ID = qi.[App type ID])
                                )
                            )
                        AND (q.[Client ID] = c.[Contractor ID])
				)
			)
        OR (c.[F/A] = 1)
		OR (c.[W/A] = 1)
		OR (c.[L/A] = 1))
		AND (c.[Contractor ID] > 0)
    """

    cursor = source_conn.cursor()
    cursor.execute(sql_query)

    records = cursor.fetchall()

    row_count = cursor.rowcount

    print (f"Found {row_count} CRM Accounts")


    return records
       
def upsert_account(name, is_local_authority, is_fire_authority, is_water_authority, legacy_id):
    sql_query = """
        SELECT	a.Guid
        FROM	SCrm.Accounts a
        WHERE	(a.LegacyID = %s)
        """

    cursor = dest_conn.cursor()
    cursor.execute(sql_query, 
                (legacy_id))
    
    if cursor.rowcount == 1:
        r = cursor.fetchone()

        return r['Guid']


    sql_stmt = """
            EXEC SCrm.AccountsUpsert @Name=%s, @Code=%s, @AccountStatusGuid=%s, @ParentAccountGuid=%s, 
            @IsPurchaseLedger=%s, @IsSalesLedger=%s, @IsLocalAuthority=%s, @IsFireAuthority=%s, 
            @IsWaterAuthority=%s, @RelationshipManagerUserGuid=%s, @CompanyRegistrationNumber=%s, 
            @MainAccountContactGuid=%s, @MainAccountAddressGuid=%s, @Guid=%s
        """
    
    print (f"Adding CRM Account: {name}")

    record_guid = uuid.uuid4()
    default_account_status = 'B35B37DB-B1E7-43C1-9071-B5437F2555DC'

    cursor = dest_conn.cursor()
    cursor.execute(sql_stmt,
                    ("" if name is None else name, 
                    "",
                    default_account_status,
                    EMPTY_GUID,
                    False,
                    True,
                    is_local_authority,
                    is_fire_authority,
                    is_water_authority,
                    EMPTY_GUID,
                    "",
                    EMPTY_GUID,
                    EMPTY_GUID,
                    record_guid
                    ))
    
    # Set the legacy ID
    print(" setting legacy ID")
    sql_stmt = """
            UPDATE SCrm.Accounts SET LegacyId = %s WHERE Guid = %s
        """
    
    cursor = dest_conn.cursor()
    cursor.execute(sql_stmt, 
                   (
                       legacy_id,
                       record_guid
                   ))
    
    return record_guid

def upsert_address(name, number, address_line_1, address_line_2, address_line_3, town, county, post_code, country, account_guid, legacy_id):
    sql_query = """
        SELECT	a.Guid as AddressGuid,
                aa.Guid as AccountAddressGuid
        FROM	SCrm.AccountAddresses aa
        JOIN    SCrm.Accounts a on (a.Id = aa.AccountID)
		JOIN	SCrm.Addresses AS ad on (ad.ID = aa.AddressID)
		WHERE	(a.LegacyID = %s) AND (ad.LegacyID = %s)
        """

    cursor = dest_conn.cursor()
    cursor.execute(sql_query, 
                (legacy_id,
                 legacy_id))
    
    if cursor.rowcount == 1:
        r = cursor.fetchone()

        return r['AddressGuid'], r['AccountAddressGuid']


    print (f"Adding CRM Address: {name}")
        
    # Get the guid for the county
    print ("    getting the county guid")
    sql_query = """
            SELECT	c.Guid FROM SCrm.Counties c WHERE Name = %s   
        """
       
    cursor = dest_conn.cursor()
    cursor.execute(sql_query,
                   (county))

    county = cursor.fetchone()

    if (county):
        county_guid = county['Guid']
    else:
        county_guid = EMPTY_GUID
    
    # Get the guid for the country
    print ("    getting the country guid")
    sql_query = """
            SELECT	c.Guid FROM SCrm.Countries c WHERE Name = %s   
        """
    
    cursor = dest_conn.cursor()
    cursor.execute(sql_query,
                   (country))

    country = cursor.fetchone()

    if (country):
        country_guid = country['Guid']
    else:
        country_guid = EMPTY_GUID

    ## Create the Address Record 
    print ("    creating the address")
    sql_stmt = """
            EXEC SCrm.AddressUpsert %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
        """
    
    address_record_guid = uuid.uuid4()

    cursor = dest_conn.cursor()
    cursor.execute(sql_stmt,
                   (0,
                    name,
                    number,
                    "" if address_line_1 is None else address_line_1,
                    "" if address_line_2 is None else address_line_2,
                    "" if address_line_3 is None else address_line_3,
                    "" if town is None else town,
                    county_guid,
                    "" if post_code is None else post_code,
                    country_guid,
                    address_record_guid))
    
    # Set the legacy ID
    print ("    setting the legacy id")
    sql_stmt = """
            UPDATE SCrm.Addresses SET LegacyId = %s, LegacySystemID = %s  WHERE Guid = %s
        """
    
    cursor = dest_conn.cursor()
    cursor.execute(sql_stmt, 
                   (
                       legacy_id,
                       LEGACY_SYSTEM_ID,
                       address_record_guid
                   ))
    
    ## Create the Account Address Record 
    print ("    create the account address link")
    sql_stmt = """
            EXEC SCrm.AccountAddressesUpsert %s, %s, %s
        """  

    account_address_record_guid = uuid.uuid4()
    
    cursor = dest_conn.cursor()
    cursor.execute(sql_stmt,
                   (
                       account_guid,
                       address_record_guid,
                       account_address_record_guid
                   )) 

    return address_record_guid, account_address_record_guid

def upsert_contact (first_name, surname, display_name, primary_account_guid, primary_address_guid, legacy_id, account_address_guid, phone="", mobile="", email="", is_person=False):
    sql_query = """
        SELECT	c.Guid as ContactGuid,
                ac.Guid as AccountContactGuid
        FROM	SCrm.AccountContacts ac
        JOIN    SCrm.Accounts a on (a.Id = ac.AccountID)
		JOIN	SCrm.Contacts AS c on (c.ID = ac.ContactID)
		WHERE	(a.LegacyID = %s) AND (c.LegacyID = %s)
        """

    cursor = dest_conn.cursor()
    cursor.execute(sql_query, 
                (legacy_id,
                 legacy_id))
    
    if cursor.rowcount == 1:
        r = cursor.fetchone()

        return r['AccountContactGuid']
    
    
    ## Create the Contact Record
    print (f"Creating contact {display_name}")
    sql_stmt = """
            EXEC SCrm.ContactUpsert %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
        """
    
    contact_record_guid = uuid.uuid4()

    cursor = dest_conn.cursor()
    cursor.execute(sql_stmt,
                   (
                       "" if first_name is None else first_name,
                       "" if surname is None else surname,
                       "" if display_name is None else display_name,
                       is_person, 
                       primary_account_guid,
                       primary_address_guid,
                       EMPTY_GUID,
                       EMPTY_GUID,
                       "",
                       "",
                       contact_record_guid
                   ))
    
    # Set the legacy ID
    if (legacy_id is not None):
        print ("    setting the legacy id")
        sql_stmt = """
                UPDATE SCrm.Contacts SET LegacyId = %s, LegacySystemID = %s WHERE Guid = %s
            """

        cursor = dest_conn.cursor()
        cursor.execute(sql_stmt, 
                    (
                        legacy_id,
                        LEGACY_SYSTEM_ID,
                        contact_record_guid
                    ))
    
    if (phone != ""):
        upsert_contact_detail("Office", phone, contact_record_guid)

    if (mobile != ""):
        upsert_contact_detail("Mobile", mobile, contact_record_guid)

    if (mobile != ""):
        upsert_contact_detail("E-Mail", email, contact_record_guid)
    
    ## Create the Account Contact Record 
    print ("    creating the account contact link")
    sql_stmt = """
            EXEC SCrm.AccountContactsUpsert %s, %s, %s, %s
        """
    
    account_contact_record_guid = uuid.uuid4()
    
    cursor = dest_conn.cursor()
    cursor.execute(sql_stmt,
                   (
                       primary_account_guid,
                       contact_record_guid,
                       account_address_guid,
                       account_contact_record_guid
                   ))
    
    return account_contact_record_guid

def upsert_contact_detail(type, value, contact_guid):
    sql_query = """
        SELECT	1 as Col1 
        FROM	SCrm.ContactDetails a
		JOIN	SCrm.Contacts AS c ON (c.ID = a.ContactID)
        JOIN    SCrm.ContactDetailTypes t on (t.Id = a.ContactDetailTypeID)
        WHERE	(t.Name = %s) AND (a.Value = %s) AND (c.Guid = %s)
        """

    cursor = dest_conn.cursor()
    cursor.execute(sql_query, 
                (type,
                 value,
                 contact_guid))
    
    if cursor.rowcount == 0:
        # Get the guid for the country
        print ("    getting the detail type guid")
        sql_query = """
                SELECT	c.Guid, c.Name FROM SCrm.ContactDetailTypes c WHERE Name = %s   
            """
        
        cursor = dest_conn.cursor()
        cursor.execute(sql_query,
                    (type))

        detail_type = cursor.fetchone()

        if (detail_type):
            detail_type_guid = detail_type['Guid']
            detail_type_name = detail_type['Name']
        else:
            raise Exception(f"Filed to find Contact Detail Type: {type}")

        ## Create the Account Contact Record 
        print ("    creating the contact detail")
        sql_stmt = """
                EXEC SCrm.ContactDetailUpsert %s, %s, %s, %s, %s, %s
            """
        
        record_guid = uuid.uuid4()
        
        cursor = dest_conn.cursor()
        cursor.execute(sql_stmt,
                    (
                        detail_type_name,
                        value,
                        contact_guid,
                        detail_type_guid,
                        False,
                        record_guid
                    ))

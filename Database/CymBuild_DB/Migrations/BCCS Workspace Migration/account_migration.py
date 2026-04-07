## CymBuild CRM Account Migration from Shore Inspections ##

__author__ = "Richard Brindley"
__copyright__ = "Copyright 2024, Socotec UK"
__version__ = "1.0.1"


from common import *

def migrate_accounts():
    print("Starting accounts migration")

    records = fetch_accounts()

    for r in records:
        sql_query = """
        SELECT	1 as Col1 
        FROM	SCrm.Accounts a
        WHERE	((a.LegacyID = %s)
            AND (a.LegacySystemID = %s))
            OR  (a.Code = %s)
        """

        cursor = dest_conn.cursor()
        cursor.execute(sql_query, 
                    (r['Organisation_ID'],
                     LEGACY_SYSTEM_ID,
                     r["Code"]))
        
        if cursor.rowcount == 0:
            account_guid = upsert_account(r['Code'], r['Name'], r['VAT_Registration_Number'], r['Company_Registration_Number'], r['Organisation_ID'])

            migrate_account_addresses(r['Organisation_ID'], account_guid)

            migrate_account_contacts(r['Organisation_ID'], account_guid)

def fetch_accounts():
    sql_query = """
    SELECT	o.Organisation_ID,
            ebc.Code,
            o.Name,
            o.Phone_Number,
            o.Fax_Number,
            o.Email,
            o.VAT_Registration_Number,
            o.Company_Registration_Number
    FROM	dbo.Organisation AS o 
    LEFT JOIN	dbo.EXT_BYL_Client AS ebc ON (ebc.Organisation_ID = o.Organisation_ID)
    WHERE	(EXISTS
                (
                    SELECT	1
                    FROM	dbo.Project AS p
                    JOIN	dbo.Entity AS e2 ON e2.Global_ID = p.Global_ID
                    JOIN	dbo.Entity_Organisations AS eo ON (eo.Entity_Identifier = e2.Entity_Identifier) AND (eo.Entity_Class_ID = e2.Entity_Class_ID)
                    WHERE	(p.name  LIKE N'HRB%')
                        AND	(o.Organisation_ID = eo.Organisation_ID)
                )
            )
		OR (EXISTS
				(
					SELECT	1
					FROM	dbo.EXT_BYL_Invoice AS ebi
					JOIN	dbo.Project AS p ON (p.Project_ID = ebi.Project_ID)
					JOIN	dbo.EXT_BYL_Invoice_Line AS ebil ON (ebil.EXT_BYL_Invoice_ID = ebi.EXT_BYL_Invoice_ID)
					JOIN	dbo.EXT_BYL_Client AS ebc ON (ebc.EXT_BYL_Client_ID = ebi.EXT_BYL_Client_ID)
					JOIN	dbo.Entity AS e2 ON e2.Global_ID = p.Global_ID
					OUTER APPLY 
					(
						SELECT	Email.Address_or_Number AS Email
						FROM 	dbo.Entity_Contacts AS ec 
						JOIN	dbo.Contact AS c ON (c.Contact_ID = ec.Contact_ID)
						JOIN	dbo.Contact_Role AS cr ON (cr.Contact_Role_ID = ec.Contact_Role_ID)
						OUTER APPLY
						(
							SELECT	ccm.Address_or_Number
							FROM	dbo.Contacts_Contact_Methods AS ccm
							JOIN	dbo.Contact_Method AS cm ON (cm.Contact_Method_ID = ccm.Contact_Method_ID)
							WHERE	(ccm.Contact_ID = c.Contact_ID)
								AND	(cm.Name = N'Email')
						) AS Email
						WHERE	(ec.Entity_Identifier = e2.Entity_Identifier) AND (ec.Entity_Class_ID = e2.Entity_Class_ID)
							AND	(cr.Name = N'Project Manager')
					) project_manager
					WHERE	(p.name  LIKE N'HRB%')
					 AND	(project_manager.Email = N'David.Warren@socotec.co.uk')
					 AND	(ebc.Organisation_ID = o.Organisation_ID)
				)
			)
    """

    cursor = source_conn.cursor()
    cursor.execute(sql_query)

    records = cursor.fetchall()

    row_count = cursor.rowcount

    print (f"Found {row_count} CRM Accounts")

    return records

def upsert_account(code, name, vat_registration_number, company_registration_number, legacy_id):
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
                    (name, 
                    "" if code is None else code,
                    default_account_status,
                    EMPTY_GUID,
                    False,
                    True,
                    False,
                    False,
                    False,
                    EMPTY_GUID,
                    "" if company_registration_number is None else company_registration_number,
                    EMPTY_GUID,
                    EMPTY_GUID,
                    record_guid
                    ))
    
    # Set the legacy ID
    print(" setting legacy ID")
    sql_stmt = """
            UPDATE SCrm.Accounts SET LegacyId = %s, LegacySystemID = %s WHERE Guid = %s
        """
    
    cursor = dest_conn.cursor()
    cursor.execute(sql_stmt, 
                   (
                       legacy_id,
                       LEGACY_SYSTEM_ID,
                       record_guid
                   ))
    
    return record_guid

def migrate_account_addresses(organisation_id, account_guid):

    records = fetch_addresses(organisation_id)

    for r in records:
        sql_query = """
        SELECT	1 as Col1 
        FROM	SCrm.Addresses a
        WHERE	(a.LegacyID = %s)
            AND (a.LegacySystemID = %s)
        """

        cursor = dest_conn.cursor()
        cursor.execute(sql_query, 
                    (r['Mailing_Address_ID'], 
                     LEGACY_SYSTEM_ID))
        
        if cursor.rowcount == 0:
            address_guid = upsert_address(r['Address'], r['Postal_Code'], r['Mailing_Address_ID'], account_guid)

def fetch_addresses(organisation_id):
    sql_query = """
    SELECT	o.Organisation_ID,
            ma.Mailing_Address_ID,
            ma.Address,
            ma.Postal_Code
    FROM	dbo.Organisation AS o
    JOIN	dbo.Entity AS e ON (e.Global_ID = o.Global_ID)
    JOIN	dbo.Mailing_Address AS ma ON (ma.Entity_Class_ID = e.Entity_Class_ID) AND (ma.Entity_Identifier = e.Entity_Identifier)
    WHERE	(EXISTS
                (
                    SELECT	1
                    FROM	dbo.Project AS p
                    JOIN	dbo.Entity AS e2 ON e2.Global_ID = p.Global_ID
                    JOIN	dbo.Entity_Organisations AS eo ON (eo.Entity_Identifier = e2.Entity_Identifier) AND (eo.Entity_Class_ID = e2.Entity_Class_ID)
                    WHERE	(p.name  LIKE N'HRB%')
                        AND	(o.Organisation_ID = eo.Organisation_ID)
                )
            )
        AND (o.organisation_id = %s)
    """

    cursor = source_conn.cursor()
    cursor.execute(sql_query,
                   (organisation_id))

    records = cursor.fetchall()

    row_count = cursor.rowcount

    print (f"Found {row_count} CRM Addresses for Account {organisation_id}")

    return records

def upsert_address(address_line_1, post_code, legacy_id, account_guid):
    print (f"Adding CRM Address: {address_line_1}")

    ## Create the Address Record 
    print ("    creating the address")
    sql_stmt = """
            EXEC SCrm.AddressUpsert %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
        """
    
    address_record_guid = uuid.uuid4()

    cursor = dest_conn.cursor()
    cursor.execute(sql_stmt,
                   (0,
                    "",
                    "",
                    "" if address_line_1 is None else address_line_1,
                    "",
                    "",
                    "",
                    EMPTY_GUID, #county_guid,
                    post_code,
                    EMPTY_GUID, #country_guid,
                    address_record_guid))
    
    # Set the legacy ID
    print ("    setting the legacy id")
    sql_stmt = """
            UPDATE SCrm.Addresses SET LegacyId = %s, LegacySystemID = %s WHERE Guid = %s
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


def migrate_account_contacts(organisation_id, account_guid):

    records = fetch_contacts(organisation_id)

    for r in records:
        sql_query = """
        SELECT	1 as Col1 
        FROM	SCrm.Contacts a
        WHERE	(a.LegacyID = %s)
            AND (a.LegacySystemID = %s)
        """

        cursor = dest_conn.cursor()
        cursor.execute(sql_query, 
                    (r['Contact_ID'], 
                     LEGACY_SYSTEM_ID))
        
        if cursor.rowcount == 0:
            contact_guid = upsert_contact(r['Surname'], r['Forename'], r['Job_Title'], account_guid, r['Contact_ID'], 
                                          r['Email'], r['WorkPhone'], r['Extension'], r['Mobile'])

def fetch_contacts(organisation_id):
    sql_query = """
    SELECT	o.Organisation_ID,
            c.Contact_ID,
            c.Surname,
            c.Forename,
            c.Job_Title,
            email.Address_or_Number AS Email,
            WorkPhone.Address_or_Number AS WorkPhone,
            Extension.Address_or_Number AS Extension,
            Mobile.Address_or_Number AS Mobile
    FROM	dbo.Organisation AS o
    JOIN	dbo.Contact AS c ON (c.Organisation_ID = o.Organisation_ID)
    OUTER APPLY
        (
            SELECT	ccm.Address_or_Number
            FROM	dbo.Contacts_Contact_Methods AS ccm
            JOIN	dbo.Contact_Method AS cm ON (cm.Contact_Method_ID = ccm.Contact_Method_ID)
            WHERE	(ccm.Contact_ID = c.Contact_ID)
                AND	(cm.Name = N'Extension')
        ) AS Extension
        OUTER APPLY
        (
            SELECT	ccm.Address_or_Number
            FROM	dbo.Contacts_Contact_Methods AS ccm
            JOIN	dbo.Contact_Method AS cm ON (cm.Contact_Method_ID = ccm.Contact_Method_ID)
            WHERE	(ccm.Contact_ID = c.Contact_ID)
                AND	(cm.Name = N'Mobile Phone')
        ) AS Mobile
        OUTER APPLY
        (
            SELECT	ccm.Address_or_Number
            FROM	dbo.Contacts_Contact_Methods AS ccm
            JOIN	dbo.Contact_Method AS cm ON (cm.Contact_Method_ID = ccm.Contact_Method_ID)
            WHERE	(ccm.Contact_ID = c.Contact_ID)
                AND	(cm.Name = N'Direct Dial')
        ) AS WorkPhone
        OUTER APPLY
        (
            SELECT	ccm.Address_or_Number
            FROM	dbo.Contacts_Contact_Methods AS ccm
            JOIN	dbo.Contact_Method AS cm ON (cm.Contact_Method_ID = ccm.Contact_Method_ID)
            WHERE	(ccm.Contact_ID = c.Contact_ID)
                AND	(cm.Name = N'Email')
        ) AS Email
    WHERE	(EXISTS
                (
                    SELECT	1
                    FROM	dbo.Project AS p
                    JOIN	dbo.Entity AS e2 ON e2.Global_ID = p.Global_ID
                    JOIN	dbo.Entity_Organisations AS eo ON (eo.Entity_Identifier = e2.Entity_Identifier) AND (eo.Entity_Class_ID = e2.Entity_Class_ID)
                    WHERE	(p.name  LIKE N'HRB%')
                        AND	(o.Organisation_ID = eo.Organisation_ID)
                )
            )
        AND (o.organisation_id = %s)
    """

    cursor = source_conn.cursor()
    cursor.execute(sql_query,
                   (organisation_id))

    records = cursor.fetchall()

    row_count = cursor.rowcount

    print (f"Found {row_count} CRM Contacts for Account {organisation_id}")

    return records

def upsert_contact (surname, first_name, job_title, primary_account_guid, legacy_id, phone="", mobile="", extension="", email=""):
    
    display_name = ("" if first_name is None else first_name) + ("" if surname is None else surname)
    
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
                       False, 
                       primary_account_guid,
                       EMPTY_GUID, #primary_address_guid,
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

    if (extension != ""):
        upsert_contact_detail("Extension", extension, contact_record_guid)

    if (email != ""):
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
                       EMPTY_GUID,
                       account_contact_record_guid
                   ))
    
    return account_contact_record_guid

def upsert_contact_detail(type, value, contact_guid):
    if (value is None):
        return

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

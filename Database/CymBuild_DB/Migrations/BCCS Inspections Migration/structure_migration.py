## CymBuild Structure Migration from Shore Inspections ##

__author__ = "Richard Brindley"
__copyright__ = "Copyright 2024, Socotec UK"
__version__ = "1.0.1"


from common import *

def migrate_strucutres():

    records = fetch_structures()

    for r in records:
        sql_query = """
        SELECT	1 Col1
        FROM	SJob.Properties a
        WHERE	(a.LegacyID = %s)
        """

        cursor = dest_conn.cursor()
        cursor.execute(sql_query, 
                    (r['UPRN']))
        
        if cursor.rowcount == 0:
            upsert_structure(r['Name'], r['Number'], r['Address1'], r['Address2'], r['Address3'], r['Town'], r['County'], 
                             r['Postcode'], r['IsHighRiskBuilding'], r['IsComplexBuilding'], r['BuildingHeightMetres'], 
                             r['LA'], r['WA'], r['FA'], r['UPRN'])

def fetch_structures():
    sql_query = """
    SELECT	p.UPRN,
		p.Date,
		p.Name,
		p.Number,
		p.[Address 1] as Address1,
		p.[Address 2] as Address2,
		p.[Address 3] as Address3,
		p.Town,
		p.County,
		p.Postcode,
		p.IsHighRiskBuilding,
		p.IsComplexBuilding,
		p.BuildingHeightMetres,
		p.[L/A] AS LA,
		p.[W/A] AS WA,
		p.[F/A] AS FA
    FROM	dbo.[tbl Properties] p
    WHERE	(EXISTS
                (
                    SELECT	1
                    FROM	dbo.ShoreJob sj
                    WHERE	(EXISTS 
                                (
                                    select 1 from SJob.JobTypes jt
                                    where	(jt.Name IN ('SOCOTEC BCC', N'SOCOTEC HRB'))
                                        AND	(jt.ID = sj.[App type ID])
                                )
                            )
                        AND	(p.UPRN	 = sj.UPRN)
                )
            )
		OR	(EXISTS
				(
					SELECT	1
					FROM	dbo.Quote AS q
					JOIN	dbo.QuoteItem AS qi ON (qi.[Job ID] = q.[Job ID])
					WHERE	(EXISTS 
                                (
                                    select 1 from dbo.[tbl QuoteTypes] jt
                                    where	(jt.Type IN (N'SOCOTEC BCC', N'SOCOTEC HRB'))
                                        AND	(jt.ID = qi.[App type ID])
                                )
                            )
						AND	(p.UPRN	 = q.UPRN)
				)
			)
    """

    cursor = source_conn.cursor()
    cursor.execute(sql_query)

    records = cursor.fetchall()

    row_count = cursor.rowcount

    print (f"Found {row_count} Structures")

    return records
       
def upsert_structure(name, number, address_line_1, address_line_2, address_line_3, town, county, post_code, 
                     is_high_risk, is_complex, building_height, local_authority, fire_authority, 
                     water_authority, legacy_id):
    print (f"Adding structure {name}")
    
    # Get the guid for the county
    print ("    getting county guid")
    sql_query = """
            SELECT	c.Guid FROM SCrm.Counties c WHERE Name = %s
        """   
    
    cursor = dest_conn.cursor()
    cursor.execute(sql_query,
                   (county))

    county = cursor.fetchone()

    if county:
        county_guid = county['Guid']
    else:
        county_guid = EMPTY_GUID

    
    
    record_guid = uuid.uuid4()

    # LA Account
    print ("    getting the LA")
    la_account_guid, la_account_address_guid, la_account_contact_guid = get_legacy_account_details(local_authority)

    # FA Account
    print ("    getting the FA")
    fa_account_guid, fa_account_address_guid, fa_account_contact_guid = get_legacy_account_details(fire_authority)

    # WA Account
    print ("    getting the WA")
    wa_account_guid, wa_account_address_guid, wa_account_contact_guid = get_legacy_account_details(water_authority)


    number = "" if number is None else number
    name = "" if name is None else name
    
    name_number = "" if number == "" else number if name == "" else name

    sql_stmt = """
            EXEC SJob.PropertiesUpsert %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
        """

    cursor = dest_conn.cursor()
    cursor.execute(sql_stmt,
                    (EMPTY_GUID, 
                    "",
                    name_number,
                    "" if address_line_1 is None else address_line_1,
                    "" if address_line_2 is None else address_line_2,
                    "" if address_line_3 is None else address_line_3, 
                    "" if town is None else town,
                    county_guid,
                    "" if post_code is None else post_code,
                    EMPTY_GUID,
                    la_account_guid,
                    fa_account_guid,
                    wa_account_guid,
                    0,
                    0,
                    is_high_risk,
                    is_complex,
                    building_height,
                    EMPTY_GUID,
                    record_guid))
    
    if (legacy_id):
        # Set the legacy ID
        print ("    setting the legacy id")
        sql_stmt = """
                UPDATE SJob.Properties SET LegacyID = %s, LegacySystemID = %s WHERE Guid = %s
            """
        
        cursor = dest_conn.cursor()
        cursor.execute(sql_stmt, 
                    (
                        legacy_id,
                        LEGACY_SYSTEM_ID,
                        record_guid
                    ))
    
    return record_guid


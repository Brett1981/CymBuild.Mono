## CymBuild Structure Migration from Deltek Worksapace ##

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
            AND (a.LegacySystemID = %s)
        """

        cursor = dest_conn.cursor()
        cursor.execute(sql_query, 
                    (r['LegacyID'], 
                     LEGACY_SYSTEM_ID))
        
        if cursor.rowcount == 0:
            upsert_structure(r['Site_Address'], r['Site_Postcode'], True,
                             r['LegacyID'])

def fetch_structures():
    sql_query = """
    SELECT	ma.Mailing_Address_ID AS LegacyID,		
            ebo.Name AS BuildingOver18m,
            ma.Address Site_Address,
            ma.Postal_Code Site_Postcode
    FROM	dbo.Project AS p
    JOIN	dbo.Project_Status AS ps ON (ps.Project_Status_ID = p.Project_Status_ID)
    JOIN	dbo.Project_UDF AS pu ON (pu.Project_ID = p.Project_ID)
    JOIN	dbo.Entity AS e2 ON e2.Global_ID = p.Global_ID
    JOIN	dbo.EXT_Building_Over AS ebo ON (ebo.EXT_Building_Over_ID = pu.EXT_Building_Over_ID)
    JOIN	dbo.Mailing_Address AS ma ON (ma.Entity_Class_ID = e2.Entity_Class_ID) AND (ma.Entity_Identifier = e2.Entity_Identifier)
    WHERE	(p.name  LIKE N'HRB%')
    """

    cursor = source_conn.cursor()
    cursor.execute(sql_query)

    records = cursor.fetchall()

    row_count = cursor.rowcount

    print (f"Found {row_count} Structures")

    return records
       
def upsert_structure(address_line_1, post_code, is_high_risk, legacy_id):
    print (f"Adding structure {address_line_1}")

    sql_stmt = """
            EXEC SJob.PropertiesUpsert %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
        """
    
    record_guid = uuid.uuid4()

    cursor = dest_conn.cursor()
    cursor.execute(sql_stmt,
                    (EMPTY_GUID, 
                    "", #name,
                    "", #number
                    "" if address_line_1 is None else address_line_1,
                    "" , # address_line_2,
                    "" , # address_line_3, 
                    "" , #town,
                    EMPTY_GUID,  #county_guid,
                    "" if post_code is None else post_code,
                    EMPTY_GUID,
                    EMPTY_GUID,
                    EMPTY_GUID,
                    EMPTY_GUID,
                    0,
                    0,
                    is_high_risk,
                    False,
                    0,
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

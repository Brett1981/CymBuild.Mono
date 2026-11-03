"""Build the single CymBuild_Dev 26.4 catch-up script from the release/26.4 source files.

Usage: python build_catchup.py <repo root> <town metadata section file> <out file>
"""
import re
import sys

repo, town_meta, out = sys.argv[1:4]
S = repo + "/Database/CymBuild_DB/Schema/"


def read(p):
    return open(p, "rb").read().decode("utf-8-sig").replace("\r\n", "\n")


def module(rel):
    """Return the object's batch from a schema file as CREATE OR ALTER, keeping its leading comment."""
    text = read(S + rel)
    m = re.search(r"(?m)^[ \t]*CREATE\s+(?:OR\s+ALTER\s+)?(PROCEDURE|FUNCTION|VIEW|TRIGGER)\b", text)
    assert m, rel
    start = m.start()
    c = text.rfind("/*", 0, start)
    if c >= 0 and text.find("*/", c) < start and not re.search(r"(?im)^\s*GO\s*$", text[c:start]):
        if "generated canonical schema source" not in text[c:start]:
            start = c
    end_m = re.search(r"(?im)^[ \t]*GO[ \t]*$", text[m.end():])
    body = text[start:m.end() + (end_m.start() if end_m else len(text) - m.end())].rstrip()
    body = re.sub(r"(?m)^[ \t]*CREATE\s+(?:OR\s+ALTER\s+)?(PROCEDURE|FUNCTION|VIEW|TRIGGER)\b",
                  r"CREATE OR ALTER \1", body, count=1)
    return body + "\nGO\n"


def triggers_from_upgrade_script():
    t = read(repo + "/Database/CymBuild_DB/Scripts/Upgrade Scripts/CYB-515_26.4_WorkflowNotificationOutcomes.sql")
    blocks = re.findall(r"(?ms)^CREATE OR ALTER TRIGGER .*?^GO\s*$", t)
    assert len(blocks) == 2, len(blocks)
    return "\n".join(b.rstrip() + "\n" for b in blocks)


step = 0


def section(title):
    global step
    step += 1
    return f"\nPRINT N'{step:02d}. {title}';\nGO\n"


parts = ['''/* =====================================================================================
   CymBuild_Dev - 26.4 catch-up (single script)              generated 2026-10-14
   Source: release/26.4 (= main) at d03e5df2, branch chore/SB_26.4-dev-sql-sync

   CymBuild_Dev was compared object-by-object with the release/26.4 schema source:
     941 procedures/functions/views/triggers: 921 identical, 6 behind (below),
     14 audit triggers DEV-ahead (more audited columns - left untouched), 0 missing;
     every table and column present; 1 default constraint missing (below);
     2 unique indexes missing - NOT included (duplicate data, see end of script).
   Plus metadata the QA migration needs from DEV: the Enquiry Town save statement.

   What this applies (all CREATE OR ALTER / guarded - safe to re-run):
     01 SSop.EnquiriesUpsert                     Enquiry inline Town save (#889)
     02 SFin.TransactionDetailsUpsert            CYB-445 keep invoice request link
     03 SFin.InvoiceRequestItemsUpsert           no NULL RIBA stage (-1 sentinel)
     04 SFin.InvoiceRequestCreateInvoice         no NULL stage/milestone/activity
     05 SJob.tvf_Jobs_TeamF10ExpiryList          CYB-261 Department / BusinessUnit
     06 SCore.IntegrationOutbox_EnqueueWorkflowStatusNotification   CYB-515 outcomes
     07 2 x SCore.DataObjectTransition notification triggers        CYB-515 diagnostics
     08 DF_FeeAmendmentChase_DateChased          missing default constraint
     09 Enquiry Town metadata                    EntityQuery 64b03f27 statement + 4 params

   Run (SSMS or sqlcmd) against CymBuild_Dev only:
     sqlcmd -S "10.100.34.114\\general" -d CymBuild_Dev -E -C -b -f 65001 -i <this file>
   Rollback for 01-07: ROLLBACK_CymBuild_Dev_before_26.4_catchup.sql (same folder).
   Afterwards: schema workbench Compare / -SyncSource from CymBuild_Dev (picks up the
   CYB-515 triggers and the DEV-ahead audit triggers), then the QA migration.
   ===================================================================================== */
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;
GO

IF DB_NAME() <> N'CymBuild_Dev'
    THROW 60700, N'This catch-up script is for CymBuild_Dev only - nothing changed.', 1;
IF COL_LENGTH(N'SSop.Enquiries', N'PropertyTown') IS NULL OR COL_LENGTH(N'SSop.Enquiries', N'AgentTown') IS NULL
    THROW 60701, N'SSop.Enquiries Town columns missing - nothing changed.', 1;
IF OBJECT_ID(N'SCore.WorkflowNotificationQueueErrorLog', N'U') IS NULL
    THROW 60702, N'SCore.WorkflowNotificationQueueErrorLog missing - nothing changed.', 1;
GO
''']

parts += [section("SSop.EnquiriesUpsert (Enquiry inline Town save)"), module("Programmability/Procedures/SSop.EnquiriesUpsert.sql")]
parts += [section("SFin.TransactionDetailsUpsert (CYB-445)"), module("Programmability/Procedures/SFin.TransactionDetailsUpsert.sql")]
parts += [section("SFin.InvoiceRequestItemsUpsert (no NULL RIBA stage)"), module("Programmability/Procedures/SFin.InvoiceRequestItemsUpsert.sql")]
parts += [section("SFin.InvoiceRequestCreateInvoice (no NULL stage)"), module("Programmability/Procedures/SFin.InvoiceRequestCreateInvoice.sql")]
parts += [section("SJob.tvf_Jobs_TeamF10ExpiryList (CYB-261)"), module("Programmability/Functions/SJob.tvf_Jobs_TeamF10ExpiryList.sql")]
parts += [section("SCore.IntegrationOutbox_EnqueueWorkflowStatusNotification (CYB-515)"),
          module("Programmability/Procedures/SCore.IntegrationOutbox_EnqueueWorkflowStatusNotification.sql")]
parts += [section("SCore.DataObjectTransition notification triggers (CYB-515)"), triggers_from_upgrade_script()]
parts += [section("DF_FeeAmendmentChase_DateChased"), '''IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_FeeAmendmentChase_DateChased')
   AND NOT EXISTS (SELECT 1 FROM sys.default_constraints dc
                   JOIN sys.columns c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id
                   WHERE dc.parent_object_id = OBJECT_ID(N'SJob.FeeAmendmentChase') AND c.name = N'DateChased')
    ALTER TABLE [SJob].[FeeAmendmentChase] ADD CONSTRAINT [DF_FeeAmendmentChase_DateChased] DEFAULT (CONVERT([date],getutcdate())) FOR [DateChased];
GO
''']
parts += [section("Enquiry Town metadata (EntityQuery 64b03f27)"), read(town_meta).strip() + "\n"]
parts += ['''
PRINT N'10. Verification';
GO
SELECT  N'01 EnquiriesUpsert Town'   AS [Check], CASE WHEN OBJECT_DEFINITION(OBJECT_ID(N'SSop.EnquiriesUpsert')) LIKE N'%@PropertyTown%' THEN N'OK' ELSE N'FAIL' END AS Result
UNION ALL SELECT N'02 CYB-445', CASE WHEN OBJECT_DEFINITION(OBJECT_ID(N'SFin.TransactionDetailsUpsert')) LIKE N'%ELSE td.InvoiceRequestItemId%' THEN N'OK' ELSE N'FAIL' END
UNION ALL SELECT N'03 ItemsUpsert sentinel', CASE WHEN OBJECT_DEFINITION(OBJECT_ID(N'SFin.InvoiceRequestItemsUpsert')) LIKE N'%SET @RIBAStageId = -1;%' THEN N'OK' ELSE N'FAIL' END
UNION ALL SELECT N'04 CreateInvoice COALESCE', CASE WHEN OBJECT_DEFINITION(OBJECT_ID(N'SFin.InvoiceRequestCreateInvoice')) LIKE N'%COALESCE(iri.RIBAStageId, -1)%' THEN N'OK' ELSE N'FAIL' END
UNION ALL SELECT N'05 TeamF10 BU/Dept', CASE WHEN OBJECT_DEFINITION(OBJECT_ID(N'SJob.tvf_Jobs_TeamF10ExpiryList')) LIKE N'%AS BusinessUnit%' THEN N'OK' ELSE N'FAIL' END
UNION ALL SELECT N'06 Enqueue outcome codes', CASE WHEN OBJECT_DEFINITION(OBJECT_ID(N'SCore.IntegrationOutbox_EnqueueWorkflowStatusNotification')) LIKE N'%@OutcomeCode%' THEN N'OK' ELSE N'FAIL' END
UNION ALL SELECT N'07 Enqueue trigger logs outcomes', CASE WHEN OBJECT_DEFINITION(OBJECT_ID(N'SCore.tr_DataObjectTransition_EnqueueWorkflowStatusNotification')) LIKE N'%@OutcomeCode = @OutcomeCode OUTPUT%' THEN N'OK' ELSE N'FAIL' END
UNION ALL SELECT N'08 DateChased default', CASE WHEN EXISTS (SELECT 1 FROM sys.default_constraints dc JOIN sys.columns c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id WHERE dc.parent_object_id = OBJECT_ID(N'SJob.FeeAmendmentChase') AND c.name = N'DateChased') THEN N'OK' ELSE N'FAIL' END
UNION ALL SELECT N'09 Town metadata', CASE WHEN EXISTS (SELECT 1 FROM SCore.EntityQueries WHERE Guid = '64b03f27-756c-45aa-ac98-275662ffc669' AND Statement LIKE N'%@PropertyTown%')
                                       AND (SELECT COUNT(*) FROM SCore.EntityQueryParameters p JOIN SCore.EntityQueries q ON q.ID = p.EntityQueryID
                                            WHERE q.Guid = '64b03f27-756c-45aa-ac98-275662ffc669' AND p.RowStatus NOT IN (0,254) AND p.Name LIKE N'%Town') = 4
                                      THEN N'OK' ELSE N'FAIL' END;
GO

/* NOT INCLUDED - needs a data decision first (duplicates exist on CymBuild_Dev and Cymbuild_UAT_Test):
   - IX_UQ_Products_Code (unique SProd.Products.Code): active duplicates BRAC HRB ADVISORY (3140/3141),
     FIRE-DFS (82/3179), FIRE-SIT (76/3262), IRE-FTC (3208/3209); quote items reference both copies.
   - IX_UQ_EntityProperties_Hobt_Name: duplicate active metadata properties
     SCrm.Accounts.DefaultCreditTermsId (2817/2821), SFin.InvoiceRequests.FinanceBillingNotes (2819/2822),
     SFin.InvoiceRequests.JobBillingNotes (2820/2824).
*/
PRINT N'Done.';
GO
''']

open(out, "w", encoding="utf-8-sig", newline="\r\n").write("".join(parts))
print("written", out)

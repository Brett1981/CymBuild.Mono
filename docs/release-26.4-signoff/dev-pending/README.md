# SQL still to apply to DEV (26.4 port gaps)

`CymBuild_Dev264` stopped accepting logins on 14 Oct 2026, and the server no longer lists it. Scripts 01 and 02 had already been applied there; 03 and 04 never were. The old `CymBuild_Dev` is online again, but it has none of these changes.

Apply all four to whichever database is now the DEV source, in this order:

1. `01_CYB-445_TransactionDetailsUpsert.sql`: keep the invoice request link when a transaction detail is edited.
2. `02_NoRibaStage_InvoiceRequestProcs.sql`: invoice request items never store a NULL RIBA stage.
3. `03_CYB-261_TeamF10ExpiryList.sql`: Team F10 expiry list returns Department and Business Unit.
4. `04_CYB-515_WorkflowNotificationOutcomes.sql`: notification enqueue outcome codes and trigger diagnostics.

Then run the schema workbench `-SyncSource`. Script 04 is the important one here: its triggers live in the generated `Schema/Tables/SCore.DataObjectTransition.sql`, which must not be hand-edited.

How to run each script:

```
sqlcmd -S "10.100.34.114\general" -d <DEV database> -E -C -b -f 65001 -i <file>
```

Do not apply these to QA2, UAT or LIVE by hand. They reach those environments through the normal release once the branches are merged.

Every script is `CREATE OR ALTER` and safe to re-run. Pre-change rollback copies for 01 and 02, taken from Dev264, are in `../dev264/`.

> **Superseded on 14 Oct 2026** by `../dev-catchup/CymBuild_Dev_26.4_CatchUp.sql`, which also covers the Enquiry Town procedure and metadata, both CYB-515 triggers and a missing default constraint. Use that file instead.

# Workflow Cleanup Implementation Plan

1. Run `00_Discovery.sql` against the target database and save the output.
2. Review any additional dependencies outside the supplied export, especially modules or metadata rows containing retired status GUIDs/IDs.
3. Run `01_PreValidation.sql`. Do not continue if it raises an error.
4. Run `02_Apply_WorkflowCleanup.sql` in DEV/QA first. The script:
   - creates rollback backup tables;
   - migrates duplicate status references;
   - repairs retained status visibility;
   - removes duplicate/hidden workflow configuration;
   - validates zero remaining references before deleting duplicate rows;
   - removes matching `SCore.DataObjects` registry rows only when there is no remaining transition/security reference.
5. Run `03_PostValidation.sql`.
6. Regression test all workflow entry points through the supported flow: UI → FormHelper → gRPC API → EF → SQL.
7. Promote by CI/CD only. Do not perform manual DB edits.
8. To rollback after commit, run `04_Rollback_From_Backup.sql` using the same `RunGuid`.

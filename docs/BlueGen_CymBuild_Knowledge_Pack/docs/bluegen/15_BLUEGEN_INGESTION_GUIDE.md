# BlueGen Ingestion Guide

> **Release baseline:** CymBuild 26.3  
> **Validated:** 4 August 2026  
> **Schema deployment baseline:** CYB361_R27 (QA deployment completed with `DeploymentApplied`)  
> **Source basis:** `CymBuild.Monorepo(8).zip`, uploaded schema, and the reviewed CYB361 R22–R27 changes.

## Retrieval priority

1. `00_BLUEGEN_SYSTEM_RULES.md`
2. `16_RELEASE_26_3_BASELINE.md`
3. Current source-controlled code and SQL relevant to the question
4. `01_CYMBUILD_ARCHITECTURE.md`
5. `02_NAVIGATION_SCHEMA.yaml`
6. Metadata/deployment runbooks and golden paths
7. Troubleshooting/Jira history/user help

## Authority model

1. Explicit current CymBuild system/release rules.
2. Current source-controlled code and SQL.
3. Reviewed 26.3 architecture/runbooks.
4. Verified deployment/audit evidence.
5. Jira history and examples.
6. Draft guidance.

Database state is deployment evidence, not the authoring source. If documents conflict with current code/schema, report the conflict and inspect source before proposing changes.

## Suggested ingestion metadata

```json
{
  "system": "CymBuild",
  "release": "26.3",
  "validated_on": "2026-08-04",
  "schema_runner": "CYB361_R27",
  "audience": "developer|admin|support|user",
  "domain": "schema-migration|metadata-migration|workflow|finance|integration|ui|deployment",
  "authority": "high|medium|low",
  "review_status": "reviewed|draft"
}
```

## Guardrails

Do not guess missing schema, provide destructive/direct production SQL, encourage manual metadata edits, update status directly, bypass FormHelper, treat manifests as the complete migration engine, grant browser DDL permissions, use direct Sage calls, or ignore idempotency/audit requirements.

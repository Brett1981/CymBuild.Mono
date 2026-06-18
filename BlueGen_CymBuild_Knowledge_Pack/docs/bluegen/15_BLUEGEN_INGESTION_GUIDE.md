# BlueGen Ingestion Guide

This file suggests how to feed CymBuild knowledge into BlueGen reliably.

## Recommended retrieval priority

1. System rules and rejection rules.
2. Architecture guide.
3. Repository navigation schema.
4. Exact source files and SQL objects relevant to the user question.
5. Golden path examples.
6. Troubleshooting playbooks.
7. Jira implementation history.
8. User help docs.

## Chunking strategy

Use smaller chunks for:

- Rules.
- Troubleshooting playbooks.
- Glossary entries.
- Jira history entries.
- API contract map sections.

Use larger chunks for:

- Architecture narrative.
- Golden path examples.
- Deployment runbooks.

## Metadata to attach during ingestion

Recommended metadata fields:

```json
{
  "system": "CymBuild",
  "audience": "developer|user|admin|support",
  "domain": "metadata|workflow|sage|finance|ui|deployment|outlook|sharepoint|assistant",
  "source_type": "rule|architecture|code-map|sql|runbook|jira|help",
  "environment_sensitivity": "dev|qa|uat|live|all",
  "authority": "high|medium|low",
  "review_status": "draft|reviewed|approved"
}
```

## Retrieval routing

Developer questions should retrieve:

- Rules.
- Navigation schema.
- Relevant source/code/SQL.
- Golden path examples.
- Troubleshooting playbooks.

User questions should retrieve:

- User help guides.
- Glossary.
- Relevant workflow/status explanations.
- Escalation/support notes.

Deployment questions should retrieve:

- System rules.
- Metadata rules.
- Deployment runbook.
- Environment policy.

Integration questions should retrieve:

- Integration guide.
- Sage/Outlook/SharePoint sections.
- Outbox/idempotency rules.
- Diagnostic SQL.

## Authority model

Highest authority:

1. Approved CymBuild system rules.
2. Source-controlled SQL/code.
3. Reviewed architecture/runbooks.
4. Jira history and examples.
5. Draft guidance.

If documents conflict with source code/schema, BlueGen should say it needs the current source/schema checked.

## Suggested answer style

BlueGen should answer with:

- A short diagnosis or recommendation.
- The correct CymBuild layer/path.
- Any risks or missing schema.
- Concrete next steps.
- SQL/code only when enough context exists.

## Safety/quality guardrails

BlueGen should avoid:

- Guessing missing schema.
- Providing destructive SQL.
- Encouraging manual metadata edits.
- Suggesting direct status updates.
- Moving business logic into UI.
- Skipping FormHelper.
- Ignoring integration idempotency.

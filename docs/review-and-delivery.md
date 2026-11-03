# Review and delivery rules

## Evidence-first review

Review the requested change against its intent, real diff, current consumers,
metadata, SQL contracts, and tests. Do not report a suspected defect until it is
verified by code inspection, an existing test, or a safe focused probe.

Classify findings:

- **Critical** — likely security/data-loss/production outage or irreversible
  governance breach.
- **High** — likely functional break, invalid deployment, corrupt workflow/data,
  or major compatibility regression.
- **Medium** — real maintainability, resilience, observability, coverage, or
  limited behaviour issue that should be addressed or consciously deferred.
- **Low** — small improvement with limited risk.

No findings is a valid review result. Never manufacture a finding to justify a
review pass.

## Mandatory CymBuild review questions

- Does the implementation preserve UI → FormHelper → gRPC → EF → SQL?
- Is any business rule or direct API call introduced in UI?
- Does every managed insert create exactly one correct DataObject atomically?
- Does workflow change use `SCore.DataObjectTransitionUpsert` and preserve
  history?
- Are integration events using the outbox and retry/idempotency rules?
- Are schema and metadata changes source-controlled, idempotent, dependency-
  ordered, and free of environment numeric IDs?
- Does SQL use explicit columns and correct active-row rules?
- Is existing contract/behaviour preserved unless the request changes it?
- Are all affected test layers covered, including metadata-only impact?
- Are environment and test-data permissions safe?
- Are build/deploy artefacts immutable and promotion-controlled?

## Pull-request behaviour

CymBuild uses Bitbucket. Use the repository's confirmed pull-request template,
branch convention, issue key format, and pipeline checks. Do not copy the
supplied template's GitLab commands or API endpoints.

The pull-request description should state:

- problem and requested behaviour;
- what changed and why;
- schema and metadata impact;
- architecture/data/workflow/integration impact;
- tests added and exact commands/results;
- deployment order and environment considerations;
- rollback/forward-fix considerations;
- known risk, exclusions, or follow-up.

Only create, post, reply to, or resolve remote review threads when explicitly
asked. Resolve a thread only after the fix is present and pushed; real deferred
findings remain open with a reason and follow-up.

## Git safety

- Inspect current branch, status, and diff before editing or preparing a commit.
- Preserve unrelated user changes.
- Base work on the explicitly requested branch. Fetch before branching when
  authorised.
- Do not commit, push, open a pull request, deploy, or force-push unless asked.
- Never use destructive reset/checkout to discard work without explicit
  approval and exact target verification.
- A release-branch rewrite is exceptional and must be explicit; verify the
  remote target and lease before any force-with-lease operation.
- Do not add `Co-Authored-By` lines.

## Handover

State the outcome first, then list changed files, validation performed, exact
test results, tests not run, and next controlled action. Do not describe a
scaffold as production-complete or a pipeline-only test as locally passed.

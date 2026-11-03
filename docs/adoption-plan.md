# Adoption plan for the CymBuild repository

This plan separates safe repository guidance from executable test-generation
changes. Each phase should be a reviewed, reversible pull request or a clearly
bounded group of pull requests.

## Phase 0 — Current-source inventory

Work from a fresh, explicitly named CymBuild 26.3 branch/commit. Read rather than
assume:

- root and nested agent/instruction files;
- solution/project target frameworks and package versions;
- current test projects, test SDKs, fixtures, categories, and run scripts;
- `V2FormRenderer`, `V2FieldEditor`, `FilteredDynamicGridViewV2`, FormHelper, and
  the actual metadata models they consume;
- source-controlled metadata manifest locations, schemas, stable Guid fields,
  dependency representation, and apply tooling;
- protobuf contracts, service implementations, EF/repository patterns, and SQL
  project layout;
- architecture-test conventions and SQL integration harness;
- Bitbucket Pipeline files, images, test reports, artefact handling, and
  deployment gates;
- authentication/test identity and controlled test-data facilities;
- existing browser/E2E framework or an explicit decision that none exists.

Deliverable: an evidence table mapping every proposal in this bundle to a real
file/type/command or marking it as not currently implemented.

## Phase 1 — Repository guidance and manifest contract

Add the tailored `AGENTS.md` and linked documents after correcting any inventory
finding. Add the test-case JSON Schema and a repository-native validation test.

Recommended gate:

- manifests parse and match the schema;
- IDs are unique;
- source references resolve where they are repository paths;
- LIVE cases are non-mutating;
- managed-entity/workflow flags are internally consistent.

This phase changes no runtime code and is the safest first production-repository
integration.

## Phase 2 — Architecture and change-impact gates

Extend `CymBuild.Architecture.Tests` using its existing patterns. Candidate gates:

- disallowed PWA direct dependencies/API use;
- newly introduced direct workflow status writes;
- schema/metadata migrations invoked from application startup;
- newly introduced unsafe SQL patterns with precise exclusions;
- test-case manifest validation and duplicate IDs;
- metadata/source changes with no test-impact declaration.

Add rules one at a time with positive and negative fixture coverage. Run them
against the current baseline before making them blocking. Existing genuine debt
should be baselined visibly, not hidden or mass-fixed inside this work.

## Phase 3 — Metadata contract compiler

Create a small repository tool using the solution's confirmed .NET target and
libraries. Proposed responsibilities:

1. read manifests using their actual existing parser/model where possible;
2. normalise identity by stable Guid;
3. build and validate the dependency graph;
4. map forms/fields/grids/views/columns/actions to supported renderer features;
5. map data/action bindings to known contracts;
6. emit deterministic catalog and coverage reports;
7. optionally emit candidate test-case manifests without overwriting reviewed
   changes.

Do not make this tool query LIVE or introduce a second metadata interpretation
that can drift from production. Reuse production parsing/validation code only if
that code can be isolated without creating forbidden dependencies; otherwise
extract a shared, side-effect-free contract library through normal review.

## Phase 4 — Component fixtures and stable selectors

Add metadata fixture builders to the existing component test project and cover
renderer capability groups. Inspect current accessibility/test attributes first.
If stable selectors are missing, add metadata-derived attributes once at the
generic renderer/action/grid layers, with tests proving their stability and no
behavioural/UI change.

Do not add a selector to every individual screen and do not use database numeric
IDs as selector values.

## Phase 5 — Generated/parameterised tests

Choose the least complex mapping supported by the current suite:

- preferred: parameterised contract tests consume the deterministic metadata
  catalog directly;
- alternative: a generator creates C# test files and CI verifies committed
  output is current;
- use hand-authored tests for complex business rules and regressions that cannot
  be expressed clearly in the catalog.

The generator must be deterministic, versioned, and test-covered. Re-running it
with unchanged input produces no diff. It must never replace hand-written tests
silently.

## Phase 6 — Controlled browser journeys

Use the browser framework confirmed in Phase 0, or make a separate architectural
decision before adding one. Establish stable selector, synchronisation,
authentication, environment, data isolation, evidence, and cleanup policies.

Start with a small smoke suite in QA. Add UAT only after repeatability is proven.
LIVE remains non-mutating and separately approved.

## Phase 7 — Bitbucket CI/CD integration

Wire impact-aware suites into the existing pipeline without changing release
semantics accidentally:

- pull request: validate, fast/architecture, affected integration, build;
- controlled deployment: schema → metadata → application, following the
  established compatible release order and approvals;
- post-deploy: environment-allowed smoke/functional verification;
- reports: test impact, results, immutable release identity, schema/metadata
  audit references.

Make a new gate advisory first when baseline stability is unknown, then blocking
after false positives and runtime are acceptable.

## Definition of production-ready

The integration is production-ready when:

- all guidance matches current source and team process;
- the case schema and generator are deterministic and covered by tests;
- metadata coverage is measurable by capability, definition, binding, and
  journey;
- generated cases cannot authorise LIVE writes;
- architecture/DataObject/transition/outbox rules have executable coverage;
- CI uses confirmed commands and publishes diagnosable results;
- schema and metadata promotion remain source-controlled/idempotent;
- QA repeatability and UAT controls are demonstrated;
- LIVE smoke is explicitly non-mutating;
- no runtime application component depends on an AI agent.

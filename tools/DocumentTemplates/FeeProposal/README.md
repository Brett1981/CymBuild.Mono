# Fire Engineering Fee Proposal template tooling (CYB-323)

Scripted edits of the "Fire Engineering UK - Fee Proposal" Word template (merge document 122,
Guid `c26adae4-cbd1-44a6-876a-1f51d7733ae6`). Each script is a .NET 10 file-based app; run it
from this folder with `dotnet run <script>.cs -- <args>`. Write output outside the repository.

| Script | Arguments | What it does |
|---|---|---|
| `EditTemplate.cs` | `<extractDir> <outDir>` | Zips the unpacked template into `FeeProposal_original.docx`, then writes `FeeProposal_CYB-323.docx` (upload this one) and `FeeProposal_CYB-323_REVIEW.docx` (yellow = automatic content, green = gated rows). It asserts the text of every row it edits, so it fails rather than editing the wrong row if the template has changed. |
| `SimulateMerge.cs` | `<outDir> [3757]` | Runs the API's real conditional-row pass (keep, remove and repeat decisions, row removal and repetition, merge) over `FeeProposal_CYB-323.docx` for one sample quote (or, with `3757`, QA2 quote 3757's lines), and writes `FeeProposal_simulated.docx`. Its gating rules mirror the seed script; keep them in step when rows change. References `services/Concursus.API`. |
| `Analyse.cs` | `<docx>` | Lists leftover `«»` placeholders and `£X,XXX` cells per table. |

`<extractDir>` is the template .docx unzipped into a folder. Download the template from
SharePoint (ConcursusQuotes, /Form Templates/Quote Folders/) and unzip it. Do not commit the
template or the generated documents.

The bookmark, field and gating design is in
`docs/CYB-323-Fire-Engineering-Fee-Proposal-Phase1-Plan.md`. Tables 3-14 (later phases) follow
the same pattern: add the row edits to `EditTemplate.cs` and the scenario to `SimulateMerge.cs`.

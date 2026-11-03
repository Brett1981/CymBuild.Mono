# Writing style for agent-authored text

Agents now write a lot of what our team reads: commit messages, MR descriptions,
review comments, Jira tickets, and docs like this one. Unedited, that prose has a
recognisable texture. It is longer than it needs to be, it announces its own
structure, and it manufactures emphasis it has not earned.

That texture costs us twice. Reviewers skim past padding and miss the finding
that mattered, and a ticket that reads as machine-written gets taken less
seriously than the same content written plainly.

**The test:** would a competent colleague have written this sentence? If not, cut
it or rewrite it.

Adapted from [unslop](https://github.com/theclaymethod/unslop), which has the
full pattern catalogue, scanners, and voice tooling. This file covers only what
applies to the artifacts above. Go upstream when you want the rest.

---

## Three gates, in order

Style edits are subordinate to these. A rewrite that reads beautifully and
changes a number is a failure.

1. **Preserve meaning.** Facts, magnitudes, negations and scope survive
   unchanged. "Latency fell 40%" must not become "latency fell sharply". "Does
   not retry" must not become "retries".
2. **Do no harm.** Technical register is not slop. See the protected list below
   before you "fix" anything.
3. **Cut before you rewrite.** Most AI tells are additions. Deleting the sentence
   usually beats rephrasing it.

## Where it shows up, and what to do

### Commit messages and MR descriptions

- No throat-clearing. "This commit introduces changes that..." is a wasted line.
  State what changed.
- No structure announcements. "Firstly", "In conclusion", "Key takeaways".
- No significance inflation. The change does not "represent a significant step
  forward". It fixes a bug.
- Say what changed and why. Skip what a reader can get from the diff.

### Review comments

This is where the cost is highest, because volume destroys signal.

- No deference padding. "Great question!", "I hope this helps", "Just a thought".
- No hedging clusters. "It might potentially be worth possibly considering" is
  one weak sentence pretending to be polite. State the finding.
- No fake balance. "While this approach is promising, there are some concerns"
  delays the point. Lead with the concern.
- One finding per comment, with the failure it causes.

### Jira tickets

- Describe the problem and the acceptance criteria. Nothing else.
- No empty optimism in the closing line. "This will greatly improve the user
  experience" is unfalsifiable filler.
- No invented numbers. If you have not measured it, do not quantify it.

### Docs

- Do not restate the intro at the end.
- Do not preview a structure you are about to deliver anyway.
- Headings are handles, not narration. "Registry pull secret" beats "Understanding
  the Journey of Registry Authentication".

## The highest-value offenders

| Category | Examples | Do instead |
|---|---|---|
| Em-dash overuse (strongest single tell) | "the fix — and this matters — is simple" | Default to none. Two in one paragraph is a hard flag. |
| Throat-clearing openers | "Here's the thing", "It's worth noting", "Let's dive in" | Delete. Start with the content. |
| Emphasis crutches | "Make no mistake", "Let that sink in", "Full stop" | Demonstrate importance, don't assert it. |
| Business jargon | "leverage", "navigate", "synergy", "low-hanging fruit" | "use", "handle", "cooperation", "easy wins" |
| AI vocabulary | "delve", "tapestry", "intricate", "underscore", "multifaceted", "paramount" | Plain equivalents. |
| Absolutes (descriptive only) | "everyone knows", "this always works", "nothing ever breaks" | Usually inaccurate. Qualify or cut. **Never touch a normative absolute — see protected list.** |
| Vague attribution | "studies show", "experts argue" | Name the source or cut the claim. |
| Binary contrast | "Not X. But Y." | One sentence, stated directly. |
| Dramatic fragments | "[Noun]. That's it." | Write the full sentence. |
| Rule-of-three cadence | Three parallel clauses in a row, repeatedly | Vary the count. Two is fine. Four is fine. |
| Meta-commentary | "As I mentioned", "Plot twist:", "Hint:" | Delete. |
| Generic positive endings | "The future looks bright", "continues to evolve" | End on the last real point. |
| Copula avoidance | "serves as a", "functions as a" | "is a" |
| Superficial -ing tails | ", highlighting the importance of..." | Analyse or cut. Restating is not analysis. |

## Protected usage — do not "fix" these

Applying the rules above without this list does more damage than leaving the
prose alone. All of the following are legitimate:

- **Technical register.** "The parser reads the file", "the gate fails the build",
  "the model learns the distribution", "the test cleans up after itself".
- **Literal mechanics.** "Load-bearing wall", "substrate layer", "wedge for
  assembly". These are not metaphors.
- **Imperative corrections.** "Use pnpm, not npm" is a fact correction, not false
  drama. Same for "Latency fell 40%, not 4%".
- **Human roles acting.** "The judge decides the case", "the reviewer approves the
  MR".
- **Executive summaries and TL;DRs.** Restating the main point is the job.
- **Reference docs and runbooks.** Flat emotional register is correct.
- **Normative and force-bearing absolutes.** "Always branch from `origin/main`",
  "never resolve a thread to tidy the count", "must", "all". In a rule, the
  absolute *is* the content. Upstream treats dropping one as a hard preservation
  failure, and this repo's own strongest rules are written this way.
- **Register hedges.** "May cause drowsiness", "does not establish causation",
  "should not be relied on". These carry legal or technical force. Only hedge
  *clusters* are a tell, never a single load-bearing hedge.
- **The `**Section** — see docs/x.md` pointer construct.** A structural signpost,
  not prose rhythm. Exempt from the em-dash rule.
- **Quoted material, code fences and blockquotes.** Out of scope entirely. Never
  edit a quoted error string or a code sample for style.

Where a rule and this list disagree, this list wins.

## Checking your own output

Before posting an MR description, review comment or ticket:

1. Count em-dashes per prose paragraph, ignoring tables, code and quotes, and
   counting each list item on its own. Two or more in one paragraph means
   rewrite. A list of six bullets with one each is fine.
2. Read the first sentence. If it does not carry content, delete it.
3. Look at the last line. If it is empty optimism, delete it.
4. Check every number against something you actually measured or read.

For anything longer, or for a real audit with scanners and severity scoring, use
[unslop](https://github.com/theclaymethod/unslop) directly.

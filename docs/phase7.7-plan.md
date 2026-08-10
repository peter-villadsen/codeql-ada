# Phase 7.7 work plan — CFG specification & per-construct conformance tests

**Status of the CFG itself: built and shipped.** Tasks 7.0–7.6 landed the shared-pack
instantiation, `ControlFlowGraphImpl.qll` (27 control-flow trees), the consumer layer
(`BasicBlocks.qll`, `PairedCalls.qll`) and three CFG-based queries. **This phase adds no
CFG features.** It adds the missing *specification* and the *conformance tests* that pin
the graph down construct by construct.

Read this document top to bottom before touching anything. Every task is self-contained,
names the exact files to touch, and ends with acceptance criteria. Tasks are committed
individually, so an interruption always leaves the tree in a resumable state: to resume,
run `git log --oneline -5`, find the last completed task number, and start at the next one.

---

## Why this phase exists

Three concrete gaps in what 7.1–7.5 produced:

1. **`docs/cfg-design.md` is prose, not a specification.** Rows read "cond(true)→then-stmts".
   That is not checkable: it does not say which *node* the edge leaves, which it enters, or
   what the edge is labelled. Nothing in the repo states the expected graph precisely
   enough to detect a wrong edge by inspection.
2. **`PrintCfg.expected` is one flat 214-line alphabetically-sorted edge dump** covering
   five `.adb` files at once. It was produced by `codeql test run --learn`, which records
   whatever the implementation does — including its bugs — and hand-reviewed exactly once.
   A regression in `for` loops surfaces as an unattributable diff inside a shared blob.
3. **Test files bundle categories.** `test_branching.adb` alone covers if/elsif/else, case,
   plain loop, named loops, while, for, goto and declare blocks. `test_loops.adb` and
   `test_goto.adb`, called for by the 7.5 plan, were never written.

## Decisions for this phase (do not re-open)

- **D-016 — Exhaustive coverage.** Every one of the 405 node kinds in
  `schema/lal-nodes.json` gets an explicit verdict in the spec document: `shaped`,
  `leaf`, `opaque`, `structural` or `not-control-relevant`. Coverage is enforced by a
  script, so a future grammar addition cannot silently slip past the CFG.
- **D-017 — Inline expectations, not golden files.** Expected edges are written as
  comments in the `.adb` test files and checked by a query built on
  `codeql.util.test.InlineExpectationsTest` (shipped in `codeql/util` 2.0.38, already
  pinned transitively via `codeql/controlflow` 2.0.35 — **no new dependency**). The
  `.expected` files for these tests are empty. Rationale: `--learn` blesses whatever the
  code does; an inline expectation must be *written down by a human first*, so a wrong
  edge fails instead of being recorded.
- **D-018 — The spec absorbs the design doc, keeping its filename.**
  `docs/cfg-design.md` is rewritten in place. It keeps its name so the nine existing
  references to it (in `Cfg.qll`, `Completion.qll`, `ControlFlowGraphImpl.qll`,
  `query-writing.md`, `phase7-plan.md`, `BURNDOWN.md`) stay valid. Its hard-won
  implementation notes are carried forward, not discarded — see Task 7.7.1.
- **D-019 — Known limitations are `MISSING:` expectations, not prose.** Where the
  implementation is deliberately (or accidentally) imprecise, the correct edge is written
  as `$ MISSING: edge=…`. The framework then reports "Fixed missing result" on the day
  someone fixes it. Limitations stop being folklore.

## Global traps

1. **The dbscheme does not change.** Same rule as Phase 7. If you find yourself editing
   `ada.dbscheme`, `generator/gen.py` or the extractor, stop — you have left the plan.
   `ql/lib/ada.dbscheme.stats` must NOT be regenerated.
2. **Do not "fix" the CFG to make an annotation pass.** If actual and expected disagree,
   decide *which one is wrong* and say so in the commit message. A genuine implementation
   bug gets fixed in `ControlFlowGraphImpl.qll` with a note in the spec; a deliberate
   imprecision gets a `MISSING:` annotation and a spec entry. Never silently rewrite the
   annotation to match the tool.
3. **Class and accessor names**: the authority is `ql/lib/codeql/ada/ast/internal/Raw.qll`
   (generated) and `schema/lal-nodes.json`. Verify before use; do not trust this document.
4. **Anchoring rule (the one thing everybody gets wrong).** An inline expectation matches
   an actual result when the comment's **start line** equals the result's **end line**
   (`onSameLine` in `InlineExpectationsTest.qll`). Edge results are anchored at the
   *predecessor* node's location. So the annotation for an edge out of a multi-line node
   goes on the line where that node **ends** — for an `IfStmt` spanning lines 5–11, on
   line 11 (`end if;`), not line 5. For single-line nodes the distinction vanishes, which
   is most of them.
5. **Where things run.** Windows (`C:\Users\peter\source\repos\codeql-ada`) for editing and
   git. WSL **Debian** for anything creating a database or running tests:
   ```sh
   cd /mnt/c/Users/peter/source/repos/codeql-ada
   source /root/lal-venv/bin/activate
   export PYTHONPATH=/root/adacore/python LD_LIBRARY_PATH=/root/adacore/lib
   export PATH=/root/tools/codeql:$PATH      # CodeQL 2.25.6
   codeql test run ql/test --additional-packs=ql --search-path=extractors
   ```
   Invoke from Windows via PowerShell (not the Git-Bash tool, which rewrites `/bin/...`
   paths): `wsl.exe -d Debian -e bash -c '<the above, joined with &&>'`.

---

## The annotation format

One tag does the work.

```
-- $ edge=<predKey>|<label>|<succKey>
```

- `<predKey>`, `<succKey>` — `<QlClass>@<line>:<col>` for AST nodes; `entry@<l>:<c>`,
  `exit[normal]@<l>:<c>` or `exit[abnormal]@<l>:<c>` for the framework's synthetic scope
  nodes. This is exactly the shape the debug query prints (see Task 7.7.0), so
  annotations are transcribed, not invented.
- `<label>` — the `SuccessorType`: `successor`, `true`, `false`, `return`, `exception`,
  `break`, `goto`.
- No spaces inside a value (the parser splits expectations on whitespace) and never the
  sequence `//` (the comment parser treats it as a trailing comment).
- Several expectations may share one comment: `-- $ edge=A|true|B edge=A|false|C`.
- A deliberate imprecision: `-- $ MISSING: edge=A|successor|B`.
- A known-spurious edge: `-- $ SPURIOUS: edge=A|successor|B`.

The check is **exhaustive in both directions**: an unannotated actual edge fails with
"Unexpected result", an annotated edge with no actual counterpart fails with "Missing
result". There is no way to be vague.

The spec document states the same information in the human-readable form the request
asked for, per construct:

```
l1: if (expr)
l2:    stmt
l3:

l1 -> l2 ; expression is true
l1 -> l3 ; expression is false
l2 -> l3
```

The `.adb` file is the machine-checked truth; the doc is the reviewable rule the truth is
supposed to follow. **Write the doc entry first, then the test.**

---

## Task 7.7.0 — Harness

Files to create:

1. **`ql/lib/codeql/ada/test/InlineExpectationsTest.qll`** — the Ada binding for the
   shared framework. Implement `InlineExpectationsTestSig`:
   - `class Location = Raw::Location` (already satisfies `hasLocationInfo`).
   - `class ExpectationComment` over `Raw::Comment` (`ada_comments`; `getText()`,
     `getLocation()` already exist in `Raw.qll` around line 45). `getContents()` must
     return the text **without** the comment indicator — check whether `ada_comments.text`
     already strips `--`; if not, strip a leading `--` with `regexpReplaceAll("^--", "")`.
     Verify this empirically before building on it (a one-line debug query selecting
     `Raw::Comment.getText()` over any test database).
   - `import Make<Impl>`.
   It lives in `ql/lib` (not the test tree) so future non-CFG tests can reuse it, matching
   how other CodeQL languages ship `codeql.<lang>.test.InlineExpectationsTest`.
2. **`ql/test/library/Cfg/CfgConformance.qll`** — the `TestSig` implementation:
   `getARelevantTag()` = `"edge"`; `hasActualResult(location, element, tag, value)` where
   `location` is the predecessor `CfgNode`'s location, `element` its `toString()`, and
   `value` the `<predKey>|<label>|<succKey>` string. Define `nodeKey(CfgNode)` here, and
   **reuse it in the debug query** (Task 7.7.0 step 4) so the two formats cannot drift.
3. **`ql/test/library/Cfg/CfgTest.qll`** (or fold into the above) — `import MakeTest<…>`.
   Each per-family test directory gets a `.ql` that imports it. Decide during
   implementation whether one shared query at `ql/test/library/Cfg/` covering all `.adb`
   files in subdirectories is simpler than one query per directory; **one query per family
   directory** is preferred, because it keeps a failure attributable to a family.
4. **`ql/debug/PrintCfg.ql` + `ql/debug/qlpack.yml`** — the existing
   `ql/test/library/Cfg/PrintCfg.ql`, moved out of the test tree (every `.ql` under
   `ql/test` is treated as a test needing an `.expected`). Its new job is the debugging
   loop: dump the actual graph for a file, compare with the spec, transcribe. Update its
   header comment to say so. The pack depends on `peter-villadsen/ada-all`.

Files to delete in this task: `ql/test/library/Cfg/PrintCfg.ql`,
`ql/test/library/Cfg/PrintCfg.expected` (the golden harness is superseded, per D-017).
The five existing `.adb` files stay until their content is redistributed in 7.7.2+.

**Acceptance:** the harness compiles; a scratch `.adb` with one correct and one deliberately
wrong `edge=` annotation produces exactly one `testFailures` row for the wrong one and none
for the right one. Record that check in the commit message — it is the only proof the
harness actually fails when it should.

## Task 7.7.1 — Rewrite `docs/cfg-design.md` as the specification

Structure:

- **Preamble** — carry forward verbatim (they were expensive to learn): the framework
  contract section, the two structural facts about `AstNode = Raw::AdaNode` being an alias
  (`extends <Helper> instanceof Raw::X`, `Raw::Location` satisfying `LocationSig`), the
  three realized patterns (`GenericPostOrderTree` covers expression-like nodes only;
  `if`/`case`/loops are `PostOrderTree`s whose self-node is the join; exception routing
  lives in `HandledStmtsTree`; `exit`/`goto` are direct jump edges), the scope table and
  the completion table.
- **How to read a construct entry** — the `l1 ->` notation, and its correspondence to the
  `edge=` annotation format.
- **One section per construct family** (the fifteen families listed in Task 7.7.2), each:
  numbered Ada snippet; the edge listing; the rule in one sentence; known limitations;
  and a link to the test file that enforces it.
- **Coverage appendix** — the verdict table for all 405 node kinds (Task 7.7.16).

Sections are written **as their family task is executed**, not all up front: Task 7.7.1
produces the preamble, the notation section and the skeleton with one section per family
marked `TODO`. Each family task then fills its own section. This keeps the doc and the
tests in lockstep and makes an interrupted phase obvious at a glance.

**Acceptance:** preamble carries every implementation note from the current doc (diff the
old version to confirm nothing was dropped); every family has a section heading; all nine
existing references to `docs/cfg-design.md` still resolve.

## Tasks 7.7.2 – 7.7.16 — One family per task

Each task is the same five steps:

1. Write the spec section in `docs/cfg-design.md`: snippet, hand-derived edges, rule.
   **Derive the edges from the design rules, not from running the tool.**
2. Write `ql/test/library/Cfg/<family>/test.adb` — minimal: the construct under test plus
   the least surrounding code that makes it legal. Aim for 12–25 lines. Small files are
   the main lever against annotation noise.
3. Annotate every edge. Run `ql/debug/PrintCfg.ql` to get the actual graph, and compare it
   to step 1 **before** transcribing. Where they differ, apply Global trap 2.
4. Add `test.ql` (importing the harness) and an **empty** `test.expected`.
5. Run the family's test, then the full suite. Commit with the family name and, if step 3
   found a discrepancy, what it was and how it was resolved.

The families, in execution order (earlier ones are prerequisites for reading later ones):

| # | Family | Constructs | Tree classes |
|---|---|---|---|
| 7.7.2 | `linear` | statement sequencing, `null`, assignment, call statement/expression, post-order expression evaluation | `StmtListTree`, `NullStmtTree`, `AssignStmtTree`, `CallStmtTree`, `CallExprTree`, `GenericPostOrderTree` |
| 7.7.3 | `scopes` | the five scope kinds, entry/exit nodes, declarative-part elaboration | `Scopes::CfgScope` |
| 7.7.4 | `if-stmt` | `if` / `elsif` / `else`, no-else fallthrough | `IfStmtTree` |
| 7.7.5 | `case-stmt` | `case` with several alternatives, `others` | `CaseStmtTree` |
| 7.7.6 | `loops-basic` | plain `loop`, `while` loop, back edges, exit-less infinite loop | `LoopStmtTree`, `WhileLoopStmtTree` |
| 7.7.7 | `loops-for` | `for … in`, `for … of`, the opaque iteration node, zero-iteration skip edge | `ForLoopStmtTree` |
| 7.7.8 | `exit` | nameless, named, conditional (`exit when`), exit from nested loop | `ExitStmtTree`, `NamedStmtTree` |
| 7.7.9 | `goto` | backward and forward `goto`, label as leaf, unreachable code after `goto` | `GotoStmtTree`, `LabelTree` |
| 7.7.10 | `blocks` | `begin … end`, `declare … begin … end`, named block | `BeginBlockTree`, `DeclBlockTree`, `NamedStmtTree` |
| 7.7.11 | `exceptions` | `HandledStmts`, handlers with and without `when others`, nested regions, the conservative call-raise edge, handler falling through | `HandledStmtsTree`, `RaiseStmtTree` |
| 7.7.12 | `return` | `return`, `return expr`, extended return with and without `do … end return` | `ReturnStmtTree`, `ExtendedReturnStmtTree` |
| 7.7.13 | `short-circuit` | `and then`, `or else`, nesting, plain `and`/`or` for contrast | `ShortCircuitTree` |
| 7.7.14 | `cond-expr` | `if` expression, `case` expression, `elsif` parts | `IfExprTree`, `CaseExprTree` |
| 7.7.15 | `tasking` | `select` and its alternatives, `accept … do`, `delay`, `abort`, `requeue`, `terminate` | `SelectStmtTree`, `AcceptStmtTree`, `OpaqueStmtTree` |
| 7.7.16 | `coverage` | the verdict table + checker (see below) | — |

### Discrepancies expected to surface

These were spotted while reading `ControlFlowGraphImpl.qll` during planning. They are
**candidate defects, not confirmed ones** — each must be verified against the actual graph
before anything is changed. They are listed so that a family task does not mistake a bug
for intended behavior and annotate it as correct.

- **C-1 (task 7.7.3).** `Scopes::CfgScope.getBody()` returns only `getStmts()`, so the
  declarative part of a `SubpBody` / `PackageBody` / `TaskBody` is never elaborated —
  `procedure P is X : Integer := F; begin …` has no CFG node for the call to `F`. This
  contradicts recorded fact (a) of the current design doc ("elaboration is part of the
  CFG") and the module docstring, which says elaboration "is wired in task 7.4" —
  `DeclBlockTree` wires it for `declare` blocks only. Decide: fix, or downgrade fact (a)
  to a documented limitation with `MISSING:` annotations.
- **C-2 (tasks 7.7.5, 7.7.14).** `CaseStmtTree.propagatesAbnormal` covers only the
  alternative bodies, omitting the selector expression — unlike `IfStmtTree`, which
  includes its guard conditions. A `raise` (or a conservatively-raising call) in
  `case F(X) is …` may therefore not propagate. `CaseExprTree` has the same shape.
- **C-3 (task 7.7.15).** `OpaqueStmtTree` excludes `Raw::AcceptStmt`, but `AcceptStmtTree`
  covers only `Raw::AcceptStmtWithStmts`. A plain `accept E;` with no `do` block appears
  to be covered by **no** tree at all, which would leave a hole in the graph.
- **C-4 (task 7.7.15).** `SelectStmtTree.branch()` reads `getGuards()` and `getElsePart()`
  but never `getThenAbortPart()`, so the statements of a `select … then abort …` look
  unreachable.
- **C-5 (task 7.7.10).** `DeclBlockTree` elaborates only `ObjectDecl.getDefaultExpr()`.
  Other declaration kinds that can contain expressions (e.g. `NumberDecl`) are skipped.

## Task 7.7.16 — Coverage appendix and checker

1. **`scripts/check_cfg_coverage.py`** — reads `schema/lal-nodes.json` and the verdict
   table in `docs/cfg-design.md`, and exits non-zero if any node kind is missing from the
   table or the table names a kind that no longer exists. Pure stdlib, runs on Windows and
   Linux. No new shell script (Global trap 4 of the Phase 7 plan: new `.sh` files need
   `git update-index --chmod=+x`) — Python avoids that.
2. **The verdict table** in `docs/cfg-design.md`, one row per node kind, verdict one of:
   - `shaped` — has its own control-flow tree; links to its spec section.
   - `leaf` — a `LeafTree`; control passes through.
   - `opaque` — deliberately unmodelled internals (tasking, `QuantifiedExpr`, `DeclExpr`).
   - `structural` — consumed directly by its owner's tree, never a graph node
     (`ElsifStmtPart`, `CaseStmtAlternative`, `WhileLoopSpec`, …).
   - `n/a` — not control-relevant (type definitions, constraints, operators, aspects,
     `*Absent`/`*Present` marker nodes, tokens).
   Generate the first draft with a script from the schema plus the `instanceof Raw::X`
   occurrences in `ControlFlowGraphImpl.qll`, then **assign each `n/a` verdict by hand** —
   an auto-assigned `n/a` is worth nothing.
3. Wire the checker into `.github/workflows/ci.yml`.

**Acceptance:** checker green; deliberately adding a fake node to the schema makes it fail;
CI runs it.

## Task 7.7.17 — Close out

- `BURNDOWN.md`: add the 7.7 section with every task checked.
- `docs/query-writing.md`: point the CFG paragraph at the new per-construct sections.
- Delete the now-redundant original test files (`test_linear.adb`, `test_branching.adb`,
  `test_exceptions.adb`, `test_shortcircuit.adb`, `test_tasking.adb`) once every construct
  they covered has a home in a family directory. **Check that off construct by construct**
  — this is the step where coverage silently regresses if rushed.
- Full suite green; `codeql database analyze` with the full `ada-queries` pack still clean
  on the gpr2 corpus database; CI green.

---

## Definition of done for the phase

1. `docs/cfg-design.md` states, for every control-relevant construct, the exact edges it
   produces, in a notation a reader can check by hand.
2. Every one of the 405 node kinds has a verdict, enforced by a script in CI.
3. Every construct family has its own test directory whose `.adb` carries exhaustive,
   machine-checked edge annotations and whose `.expected` is empty.
4. Every known imprecision is a `MISSING:` annotation rather than a sentence in a document.

# CFG migration plan — from `codeql.controlflow.Cfg` to `codeql.controlflow.ControlFlowGraph`

> A working document for a migration that will run over several sessions. Update the
> [tracker](#7-tracker) and the [log](#8-log) as steps land. Environment, prelude and the
> three everyday commands are as in [phase9.2-plan.md §1](phase9.2-plan.md#1-environment).

**Why.** A CodeQL engineer reviewed the library (2026-10) and pointed out that GitHub is
moving away from CFG splitting and intends to **delete `codeql.controlflow.Cfg`**. Ruby has
since migrated (after CLI 2.25.6); Java and C# instantiate the replacement, `codeql.controlflow.ControlFlowGraph`.
Their guidance, in short:

1. Instantiate `ControlFlowGraph` instead of `Cfg` — simpler to instantiate and use.
2. Do not split. Recover the lost precision (e.g. finally-splitting, de01821) only in
   queries that need local path sensitivity, with `codeql.controlflow.ControlFlowReachability`.
   Reference: Java's `java/dereferenced-value-may-be-null` (`NullMaybe.ql`).
3. For high-precision path sensitivity, also consider the shared **Guards** library.
4. For SSA beyond its data-flow integration, instantiate the nested **`MakeSsa`** module: a
   class-based, correctly cached SSA API that Guards and ControlFlowReachability expect.

**The one-sentence summary.** Replace the 1,216-line hand-built CFG (and its
`FinallySplitting`) with an `AstSig` mapping onto the shared CFG, wire SSA through `MakeSsa`,
and move finally precision out of the graph and into the queries that need it, via Guards +
ControlFlowReachability.

**Done means:** no import of `codeql.controlflow.Cfg` anywhere; the public API reads like
Java's (`ControlFlowNode`, `BasicBlock`, `SsaDefinition`, `Guard`); all suites green; every
change in query result counts triaged; `cfg-design.md` rewritten for the new graph.

---

## 1. Verified facts (2026-10-17)

These were checked against installed packs, not recalled.

| Fact | Evidence |
| --- | --- |
| The pinned `codeql/controlflow: 2.0.35` **already ships** `ControlFlowGraph.qll`, `ControlFlowReachability.qll`, `Guards.qll` next to `Cfg.qll` | `~/.codeql/packages/codeql/controlflow/2.0.35/codeql/controlflow/` |
| The pinned `codeql/ssa: 2.0.27` has `MakeSsa<SsaInputSig>` (`Ssa.qll:996`), implementing `SsaSig<Location, ControlFlowNode, BasicBlock, Expr, Parameter, VariableWrite>` | `/root/.codeql/packages/codeql/ssa/2.0.27/codeql/ssa/Ssa.qll` (WSL) |
| **So no pack bump is needed.** The CLI 2.25.6 pin and its pack-resolution trap (see `qlpack.yml`) stay untouched | — |
| `ControlFlowGraph` is three-stage: `Make0<Location, AstSig>` → `Make1<InputSig1>` → `Make2<InputSig2>` | `ControlFlowGraph.qll:384,510,1135` |
| `ControlFlowReachability::Make<Location, Cfg, Input>` has an explicit `FinallyBlock` input and needs SSA classes (`SsaDefinition`, `SsaPhiDefinition`, `SsaUncertainWrite`, `SsaExplicitWrite`) and a `GuardValue` | `ControlFlowReachability.qll:1-140` |
| Java instantiates `Make0/1/2` in `java/ql/lib/semmle/code/java/ControlFlowGraph.qll` | tag `codeql-cli/v2.25.6` |
| Java's `Nullness.qll` uses `ControlFlowReachability::Flow<NullnessConfig>` together with `controlflow.Guards`, `IntegerGuards` and `NullGuards` | same |
| The CLI at `/root/tools/codeql` is bare: no `java-all`/`ruby-all` sources. Read reference instantiations from the `github/codeql` clone at `/root/src/github-codeql` | `ls /root/tools/codeql` |

**Step 0 answers (2026-10-17).** `github/codeql` is cloned in WSL at
`/root/src/github-codeql`, checked out at `codeql-cli/v2.25.6` (1a82a682e9).
- `shared/controlflow` at the tag is **byte-identical** to the pinned 2.0.35 pack, and
  `shared/ssa/.../Ssa.qll` to the pinned 2.0.27. **Read the references at the tag**: they
  match what we compile against.
- At the tag, **Java and C# use `ControlFlowGraph`; Ruby still uses `Cfg`.** Ruby migrated
  after 2.25.6, so its new instantiation exists only on `main`: useful to read, but it may
  rely on API that 2.0.35 lacks.
- Reference files at the tag:

  | What | Java | C# |
  | --- | --- | --- |
  | CFG instantiation | `java/ql/lib/semmle/code/java/ControlFlowGraph.qll` (694) | `csharp/ql/lib/semmle/code/csharp/controlflow/internal/ControlFlowGraph.qll` (284) |
  | Guards | `java/.../controlflow/Guards.qll` (419) | `csharp/.../controlflow/Guards.qll` |
  | Reachability | `java/.../controlflow/ControlFlowReachability.qll` (44) | `csharp/.../controlflow/ControlFlowReachability.qll` |
  | `MakeSsa` | `java/.../dataflow/internal/SsaImpl.qll:232`, `BaseSSA.qll:213`; public `dataflow/SSA.qll` | `csharp/.../dataflow/internal/SsaImpl.qll:77`, `BaseSSA.qll:11` |
  | Consumer | `java/.../dataflow/Nullness.qll`, `java/ql/src/Likely Bugs/Nullness/NullMaybe.ql` | |

- Open, for Step 2: compare `Guards::Make`'s inputs against Java's, when Step 4 starts.

---

## 2. Where we are

| Component | File | Depends on old CFG? |
| --- | --- | --- |
| CFG construction (trees, completions, scopes, `FinallySplitting`) | `controlflow/internal/ControlFlowGraphImpl.qll` (1,216), `internal/Completion.qll` (241) | **is** the old CFG |
| Public CFG API (`CfgNode`, `EntryNode`, `AstCfgNode`, …) | `controlflow/Cfg.qll` | re-exports it |
| Basic blocks | `controlflow/BasicBlocks.qll` | yes |
| Paired calls (open/close) | `controlflow/PairedCalls.qll` | yes |
| SSA (`SsaLib::Make<…, SsaCfg, SsaInput>`) | `dataflow/internal/SsaImpl.qll:602` | yes, via `SsaCfg` |
| Local/global data flow, taint, content | `dataflow/**` | via SSA + `CfgNode` |
| Queries | `UnreachableStatement`, `FunctionMissingReturn`, `OpenWithoutClose` | yes |
| Tests | `ql/test/library/Cfg/*` (24 dirs incl. `finally`, `finally-abnormal`, `tasking`, `goto`, `exit`), `Ssa`, `LocalFlow`, `DataFlow`, … | yes |
| Test/debug helpers | `test/CfgAnnotations.qll`, `test/Ssa*Annotations.qll`, `ql/debug/Print{Cfg,Ssa,…}.ql` | yes |
| Docs | `cfg-design.md` (spec), `ssa-design.md`, `dataflow-design.md`, `user-guide.md`, `query-writing.md` | describe the old graph |

---

## 3. Target architecture

```
codeql/ada/controlflow/internal/ControlFlowGraphImpl.qll
    module Ast implements AstSig<Location>     -- Ada AST → shared vocabulary
    module Input implements InputSig1, InputSig2
    Cfg0 = Make0<Location, Ast>; Cfg1 = Cfg0::Make1<Input>; Cfg2 = Cfg1::Make2<Input>
codeql/ada/controlflow/ControlFlowGraph.qll      -- public: ControlFlowNode, BasicBlock, … (Java names)
codeql/ada/dataflow/internal/SsaImpl.qll         -- SsaLib::Make over the new BasicBlock
codeql/ada/dataflow/Ssa.qll                      -- public: MakeSsa<…> instantiation (SsaDefinition, …)
codeql/ada/controlflow/Guards.qll                -- Guards::Make instantiation (+ Ada-specific guards)
codeql/ada/controlflow/ControlFlowReachability.qll
```

The model for every file is the Java counterpart at the same depth: a query writer should
not have to walk `Raw::` for an ordinary question.

### 3.1 Ada → `AstSig` mapping (as built in Step 2, `ControlFlowGraphImpl2.qll`)

Every AST node in the graph is `Raw::AdaNode`. `getChild` lists the children that are
*evaluated*, in order. It is also the path along which abrupt completions (raise, return,
exit, goto) propagate, so it includes the structural nodes (statement lists, handled
sequences). A node with an explicit step out of its "before" node gets no default
left-to-right steps. That is how the Ada constructs the library doesn't know get theirs.

| Ada construct | Shared class / hook | As built |
| --- | --- | --- |
| Subprogram, expression function, task, entry, package body | `Callable` (= `CfgScope`) | Body parts via `callableGetBodyPart` with `CallableContext = Unit` (**D-031**): formal defaults, an entry's barrier, object-declaration initialisers in order, then the statements. An expression function's body is its expression (`callableGetBody`) |
| Formal parameter | `Parameter` | `none()`. Defaults are body parts, as before |
| Statement list | `BlockStmt` | pragmas and labels among its statements are leaves |
| Handled sequence with handlers or `finally` | `TryStmt` | handlers are `CatchClause`s, ranked so that pragmas are skipped; `when others` is `catchAll`; GNAT `finally` is `getFinally` (**merged, not split**) |
| `if … elsif … else`, `if` expression | none: own `step`s | Guard by guard, as Java's Kotlin `when` (**D-032**). An `if` expression is pre-order and gets its value from its branches (`propagatesValue`); `(if C then E)` is `True` when `C` is false |
| `loop … end loop` | `LoopStmt` + own `step`s | through the library's `[LoopHeader]` node; only a jump leaves it |
| `while C loop` | `WhileStmt` | |
| `for … in/of …` | `ForeachStmt` | the iterable has emptiness successors; the loop variable's defining name is a node of its own (new) |
| `exit [L]` | `BreakStmt` + `Label` | every `exit` is labelled with its *resolved* loop (`TLoopLabel`), so a `case` never catches it |
| `exit [L] when C` | none: own `step`s + `beginAbruptCompletion` | a `BreakStmt` has no "after" node, so it couldn't fall through when `C` is false |
| `goto L` / `<<L>>` | `GotoStmt` + `Label` (`TStmtLabel`) | the library joins the goto to the label within the statement list holding it |
| `return`, extended `return` | `ReturnStmt` | an extended return's object initialiser and statements are its children |
| `raise`, `raise` expression | `Throw` | |
| A call (incl. without parentheses) | `postOrInOrder` + `beginAbruptCompletion` | may raise; a `No_Return` call can only raise |
| `case` statement / expression | `Switch` / `Case` | choices are the patterns, matched in order but not evaluated (static, cannot raise); the last alternative matches what is left (`matchAll`), since Ada `case` is exhaustive |
| `and then` / `or else` | `LogicalAndExpr` / `LogicalOrExpr` | the left operand's value decides, so no infeasible path joins at the operator |
| `not` | ordinary `UnaryExpr` | the library's `LogicalNotExpr` only has steps in a conditional context |
| `:=`, call statement | ordinary statements, `postOrInOrder` | node after their parts: SSA writes there |
| `select` | none: own `step`s + `additionalNode` | any one alternative, chosen through `[select i]` / `[skip i]` nodes with Boolean successors (a node may not have two plain successors) |
| `accept … do`, pragmas, `null`, other simple statements | default | pre-order / leaves |

---

## 4. Steps

Each step ends green (`codeql test run ql/test`) and is committed on its own. Any change in a query's result count is explained in the
step's log entry before pushing.

### Step 0 — Reference reading and spike (no product change)
- Clone `github/codeql` in WSL; check out `codeql-cli/v2.25.6`. Read Java's
  `ControlFlowGraph.qll`, `controlflow/Guards.qll`, `controlflow/ControlFlowReachability.qll`,
  `dataflow/internal/SsaImpl.qll` (for `MakeSsa`), `dataflow/Nullness.qll`, `NullMaybe.ql`.
  Find the Ruby and C# instantiations.
- Write down every API difference between the tag and `main` that matters to us.
- **Exit:** §1's "still to verify" list closed; §3.1 updated with the answers.

### Step 1 — `MakeSsa` on the *current* CFG
Independent of the CFG swap, and it gives Guards/Reachability the API they expect.
- Instantiate `SsaImpl::MakeSsa<SsaInput>` (`Expr`, `Parameter`, `VariableWrite`,
  `explicitWrite`) in a new public `codeql/ada/dataflow/Ssa.qll`, mirroring Java.
- Point `PrintSsa`, `SsaAnnotations` and the data-flow integration at the class API, where
  this is a rename rather than a rewrite. *(Deferred to Step 3: they all get rewritten for
  the new `BasicBlock` then, so they would be touched twice.)*
- **Exit:** `ql/test/library/Ssa` unchanged; new API documented in `ssa-design.md`.

### Step 2 — `AstSig` for Ada, new graph built *alongside* the old one
- New `controlflow/internal/ControlFlowGraphImpl2.qll` with `Ast`, `Input`, `Make0/1/2`.
  Start with linear code, `if`, loops, `exit`, `return`. Then `case`, short-circuit,
  handlers, `finally`, `goto`, then tasking.
- Debug query `ql/debug/PrintCfg2.ql`, plus a **diff query** that reports edges present in
  one graph and not the other, using the same AST-node keys.
- ~~Run the CFG inline-expectation suite against both graphs.~~ The annotations name the
  old graph's nodes (`IfStmt` as a join at the end, no before/after nodes), so they can't
  be shared. They are rewritten for the new graph in Step 3. The diff query is the check
  instead: `ql/debug/CfgDiff.ql` compares, per AST node that both graphs represent at
  the same point, which such node follows it, skipping everything in between.
- **Exit:** every diff in `ql/test/library/Cfg/*` and the corpus is gone or recorded in §6;
  the library's consistency checks (`ql/debug/Cfg2Consistency.ql`) are empty.

### Step 3 — Switch over
- Rename to `ControlFlowGraphImpl.qll`; delete the old trees, `Completion.qll` and
  `FinallySplitting`.
- New public `controlflow/ControlFlowGraph.qll` with Java names. Keep `Cfg.qll` as a
  deprecated alias module for one release (`deprecated class CfgNode = ControlFlowNode;` …).
- Port `BasicBlocks.qll` (or replace it with the shared `BasicBlock` from the CFG),
  `PairedCalls.qll`, `SsaImpl.qll`'s `SsaCfg`, data flow, test helpers and debug queries.
- **Exit:** whole suite green; `git grep "codeql.controlflow.Cfg"` empty except the
  deprecated alias; corpus run (as in `phase9.6-corpus-triage.md`) with result-count deltas
  triaged.

### Step 4 — Guards
- Instantiate `Guards::Make` (`codeql/ada/controlflow/Guards.qll`). Ada inputs: boolean
  conditions, `= null`/`/= null`, membership `in`/`not in`, `'Valid`, integer range bounds
  (`isIntRange`), `case` choices.
- Inline-expectation tests for `Guard.controls` / `ssaControls`.
- **Exit:** a guards test suite modelled on Java's `library-tests/guards`.

### Step 5 — ControlFlowReachability, and getting finally precision back
- Instantiate it with `FinallyBlock` = GNAT finally part, on the `MakeSsa` classes and
  `GuardValue` from Step 4.
- Re-check the three CFG queries against the `finally*` tests and the corpus:
  - `FunctionMissingReturn`: **at risk.** A merged finally joins "entered by return" with
    "entered normally", so it can produce a false "falls off the end". Rewrite it on
    `ControlFlowReachability` if Step 3 showed new results.
  - `OpenWithoutClose` / `PairedCalls`: path-sensitive, so the same risk. Port it like `NullMaybe`.
  - `UnreachableStatement`: merging only adds edges, so at worst you lose results (false negatives), never gain false positives. Probably fine as is.
- **Exit:** these queries give the same results as before the migration on the
  `finally*` tests and the corpus, or the differences are triaged.

### Step 6 — New precision queries (optional, uses Steps 4–5)
Candidates, Java-parity first: *access value may be null* (`NullMaybe` analogue), redundant
null/range check, condition always true/false. Each one is its own small plan entry.

### Step 7 — Docs and release
- Rewrite `cfg-design.md` Part 1 ("How the graph is built") for the new library. Keep the
  per-construct specs (Part 3); they describe Ada semantics, not the implementation.
- Update `ssa-design.md`, `dataflow-design.md`, `user-guide.md`, `query-writing.md`,
  `known-limitations.md`; changelog entry listing the deprecated names.
- Release as **0.4.0**, since the public CFG API is renamed.

---

## 5. Decisions (D-029 onwards, recorded in `DECISIONS.md`)

| # | Question | Leaning |
| --- | --- | --- |
| D-029 | Adopt shared `ControlFlowGraph`, drop CFG splitting | **Yes**, per reviewer |
| D-030 | Build the new graph alongside the old one and diff, or rewrite in place | **Alongside**, with `CfgDiff.ql` |
| D-031 | Body elaboration: own `Callable`, or `CallableContext` | **`callableGetBodyPart` with `Unit`**: each body (package bodies too) is a `Callable` whose parts are defaults, barrier, initialisers, statements |
| D-032 | `elsif` representation | **Own `step`s**, like Java's Kotlin `when`; no synthetic AST |
| D-033 | Public naming: Java's (`ControlFlowNode`), with old names deprecated for one release | Yes |
| D-034 | Jump labels | **Resolved targets** (`TLoopLabel(loop)`, `TStmtLabel(label)`), never names |

## 6. Accepted differences between the old and new graph

From `ql/debug/CfgDiff.ql` over the 23 CFG test databases and the five corpus projects
(2026-10-17). The consistency checks are empty everywhere. Comparable edges agree to
within 0.5%: gpr2 383,308 old / 381,360 new, libadalang-tools 174,016 / 172,484,
alire 136,555 / 135,954, libkeccak 43,963 / 43,961, adasat 3,222 / 3,217.

| Difference | Where | Why it is acceptable | Query impact |
| --- | --- | --- | --- |
| **Short-circuit operands no longer reach the other branch.** The old graph joined `A and then B` at one node, so `A` false could lead to the `then` branch | `short-circuit`; nearly all old-only edges in the corpus | the old edges were infeasible: the new graph is more precise | fewer false paths; none expected to lose true results |
| **`finally` is merged, not split.** After the `finally` part, control may leave every way it was entered | `finally*` | the reviewer's recommendation; recovered per query in Step 5 | `FunctionMissingReturn`, `OpenWithoutClose` to re-check in Steps 3/5 |
| **`goto` out of a sequence runs its `finally` part** | `finally-abnormal` line 71 | Ada semantics; the old graph skipped it (a documented v1 gap) | the `finally` part is now reachable there |
| **`case` choice lists are nodes** (matched, not evaluated) | `case-stmt`, `cond-expr` | the library matches alternatives in order, each at its list of choices (changed from per choice on 2026-10-18 so that a multi-choice alternative has one dominating match edge) | none |
| **A `for` loop's variable is a node** | `loops-for`, `for-subtype` | where each iteration's value is defined; SSA can anchor the loop variable's write there (Step 3) | none yet |
| **An empty `then abort` part of a `select` can complete** | libadalang-tools `pp/then_abort_part/a.adb` | the old graph had no path through an empty branch | none |
| **An empty block is reached** (`declare begin end;`) | libadalang-tools pretty-printer inputs (found in Step 3's corpus run) | the old graph gave a block with no statements no node | `unreachable-statement` −3, all false positives |

The AST-level diff can't see what splitting bought: the old graph's split copies of a
`finally` part are the same AST nodes, so their edges coincide. That difference is
path-level, and it is what Step 5 checks.

## 7. Tracker

| Step | Status | Commit |
| --- | --- | --- |
| 0 Reference reading | **done** 2026-10-17 | 5ef030c (plan) |
| 1 `MakeSsa` | **done** 2026-10-17 | 78ed57f |
| 2 New graph alongside | **done** 2026-10-17 | 1951f11 |
| 3 Switch over | **done** 2026-10-17 | be9d387 |
| 4 Guards | **done** 2026-10-18 | 79d3816, 3c46f38 |
| 5 Feasible paths (`PathReachability`; `ControlFlowReachability` for value queries) | **done** 2026-10-18 | (this commit) |
| 6 Precision queries | optional | |
| 7 Docs + 0.4.0 | docs done in Step 3; release not started | |

## 8. Log

- **2026-10-17** — Plan written after the reviewer's feedback. Pack contents verified (§1);
  no version bump needed.
- **2026-10-17** — Step 0: reference clone at the 2.25.6 tag; shared libraries identical to
  the pinned packs; Ruby still on `Cfg` at that tag (§1).
- **2026-10-17** — Step 1: `Ssa = SsaImpl::MakeSsa<SsaMakeInput>` in `SsaImpl.qll`, public
  as `codeql.ada.dataflow.Ssa` (`SsaDefinition`, `SsaExplicitWrite`, `SsaParameterInit`,
  `SsaUncertainWrite`, `SsaPhiDefinition`, `VariableWrite`, `SsaSourceVariable`).
  `VariableWrite.asExpr()` is the name written (Ada's `:=` is a statement, so there is no
  assignment expression); `isParameterInit` maps the body's formal to the public
  `Parameter` via `Parameter.getADeclaration()`. Value-less writes (uninitialised
  declaration, `out` formal) count as explicit. New test `ql/test/library/Ssa/class-api`;
  existing SSA tests unchanged. Consumers (data flow, test helpers, `PrintSsa`) still use
  `SsaImpl::Definition`: they move in Step 3 along with the CFG.
- **2026-10-17** — Step 2: `ControlFlowGraphImpl2.qll` (mapping in §3.1), debug queries
  `PrintCfg2`, `Cfg2Consistency`, `CfgDiff`. First run: consistency failed only on
  `select` (several plain successors), now fixed with `[select i]`/`[skip i]` nodes. Diff
  findings, all in §6. Fixed on the way: a loop variable's inner `Identifier` was
  evaluated, and choices that are calls (`Character_Type'Val (16#9#)` in gpr2's lexer)
  got exception edges; choices are now static leaves. Nothing consumes the new graph yet.
- **2026-10-17** — Step 3: switched over. `ControlFlowGraphImpl.qll` is the new graph (the
  old trees, `Completion.qll` and `FinallySplitting` deleted); public
  `controlflow/ControlFlowGraph.qll` with Java's names (D-033); `Cfg.qll` deprecated
  aliases; `BasicBlocks.qll`, `PairedCalls.qll`, SSA, data flow, the three CFG queries,
  test helpers and debug queries ported (`CfgDiff`/`PrintCfg2` removed with the old
  graph). A write or read is at the node that `injects` its AST node.
  `getEnclosingCfgScope` is syntactic again, for declarations. Tests: 60/86 passed before
  any fixture change, every query and data-flow test among them; the 23 CFG fixtures were
  re-annotated with `scripts/annotate_cfg_test.py` after checking the graph against
  `cfg-design.md`'s rules through Step 2's diff (§6) and by reading the `finally`, `case`,
  loop, exit, short-circuit, exception and `select` annotations; SSA: only the loop phi
  moved, to the loop variable (inputs and reads unchanged). **Corpus** (before = 1951f11 in
  a worktree, after = this commit; before equals `corpus_query_baseline.json`): one count
  changed, `ada/unreachable-statement` on libadalang-tools 10 → 7. The three were blocks
  with empty statement lists (`declare begin end;` in pretty-printer test inputs), which
  the old graph gave no node and so reported unreachable: false positives.
  `function-missing-return` and `open-without-close` are unchanged on the corpus despite
  the merged `finally` parts. Docs: `cfg-design.md` Parts 1–3 and 5 rewritten,
  `check_cfg_coverage.py` ported and the appendix regenerated, `ssa-design.md`,
  `query-writing.md`, `known-limitations.md`, `user-guide.md`, CHANGELOG (Unreleased
  0.4.0), DECISIONS D-029–D-034 (renumbered from the plan's D-028–D-033: D-028 was
  taken).
- **2026-10-18** — Pushed Steps 0–3 (CI run 39089858442). Step 4: `codeql/ada/controlflow/
  Guards.qll` instantiates `codeql.controlflow.Guards` (`Make` + `Logic` over
  `codeql.ada.dataflow.Ssa`), modelled on Java's: `SsaExpr` (now with `getBasicBlock`)
  is the expression type; constants are `null`, `Standard.True`/`False`, decimal integer,
  character, string and enumeration literals; `=`/`/=` equality; `and then`/`and`,
  `or else`/`or`, `not`, parentheses; `if` expressions without `elsif`; `case`
  alternatives (match from any choice, non-match from the last); allocators and
  `'Access` non-null; range guards from comparisons with a decimal literal; wrapper
  functions are non-overridden functions. Test `ql/test/library/Guards` (`controls` and
  `valueControls`): if/elsif, short-circuit operands, `not`, null test, a condition
  through an SSA variable, case alternatives, while, exit when, ranges. Found: a
  multi-choice alternative does not control its body on match (no single dominating
  edge; Java restricts to a single constant too), recorded in `known-limitations.md`.
  The SSA data-flow integration now uses the library's `Guard` (`directlyValueControls`
  / `valueControls`), replacing the hand-written guard and `BarrierGuard`'s own lifting
  through the logical operators; `LocalFlow` gains a check carried by a variable
  (guarded). Pushed (79d3816, CI run 39091559925).
- **2026-10-18** — Follow-up: the multi-choice `case` limitation is fixed. A `case`
  alternative's pattern is now its whole `AlternativesList`, matched at once (Ada choices
  are static, never evaluated one by one), so each alternative has one `match` edge that
  dominates its statements and Guards finds `when 2 | 3` to control them. The `case-stmt`
  and `cond-expr` fixtures re-annotated; Guards test gains the row. Pushed (3c46f38).
- **2026-10-18** — Step 5. Probes first: `finally` cases appended to the
  `open-without-close` and `function-missing-return` tests — both reported false positives
  on the merged graph (a file closed on every real path around a `finally` part; a
  function whose `if`/`else` both return through one). `ControlFlowReachability` does not
  fit them: it follows an SSA variable, and tracks only whether a `finally` part was
  entered abruptly, so a part entered normally may still leave by the `return`
  continuation — the `open-without-close` shape. New `codeql.ada.controlflow.
  PathReachability` (D-035): reachability that keeps, per enclosing `finally` part, the
  way it was entered (normal, return, exception, exit, goto) and lets the part's end
  continue only that way. `PairedCalls`, `function-missing-return` and
  `unreachable-statement` use it; the latter also drops its stale "`finally` not
  modelled" exclusion and gains a probe (code after a block that returns either way
  through its `finally` part: now reported). Test `finally-abnormal/PathReachability.ql`
  (nodes reached in the graph but not along feasible paths). 88/88 tests; corpus counts
  unchanged. `ControlFlowReachability` itself is for Step 6's value queries.

## 9. Open questions for the reviewer

- Roughly when will `codeql.controlflow.Cfg` be removed? That decides whether this blocks
  the next CLI bump.
- Is `ControlFlowGraph` as shipped in controlflow 2.0.35 (CLI 2.25.6) a reasonable target,
  or has its API changed enough since that we should bump first?
- Where do the Ruby and C# instantiations live now?

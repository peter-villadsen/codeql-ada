# CFG migration plan — from `codeql.controlflow.Cfg` to `codeql.controlflow.ControlFlowGraph`

> A working document for a migration that will run over several sessions. Update the
> [tracker](#7-tracker) and the [log](#8-log) as steps land. Environment, prelude and the
> three everyday commands are as in [phase9.2-plan.md §1](phase9.2-plan.md#1-environment).

**Why.** A CodeQL engineer reviewed the library (2026-10) and pointed out that GitHub is
moving away from CFG splitting and intends to **delete `codeql.controlflow.Cfg`**. Ruby has
already migrated; Java and C# instantiate the replacement, `codeql.controlflow.ControlFlowGraph`.
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
| Java instantiates `Make0/1/2` in `java/ql/lib/semmle/code/java/ControlFlowGraph.qll` (697 lines on `main`) | `gh api repos/github/codeql/contents/...` |
| Java's `Nullness.qll` uses `ControlFlowReachability::Flow<NullnessConfig>` together with `controlflow.Guards`, `IntegerGuards` and `NullGuards` | same |
| The CLI at `/root/tools/codeql` is bare: no `java-all`/`ruby-all` sources. Read reference instantiations from `github/codeql` instead (clone under `/root/src/github-codeql`, pinned to `codeql-cli/v2.25.6` **and** compared to `main`) | `ls /root/tools/codeql` |

**Still to verify (Step 0):**
- That the `ControlFlowGraph.qll` in 2.0.35 matches what Java uses on the `codeql-cli/v2.25.6`
  tag. If the API moved after 2.25.6, follow the tag, not `main`.
- The Ruby and C# instantiation paths. They aren't at the obvious `…/ControlFlowGraphImpl.qll` paths on `main`.
- Whether `Guards::Make` in 2.0.35 takes the same inputs Java passes on the tag.

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

### 3.1 Ada → `AstSig` mapping (first draft — Step 2 makes it concrete)

| Ada construct | Shared class / hook | Notes and risks |
| --- | --- | --- |
| Subprogram, task, entry, protected-op body | `Callable`, `callableGetBody` | Package-body elaboration: separate `Callable`, or `CallableContext` + `callableGetBodyPart`. **Decide in Step 2.** |
| Formal parameter | `Parameter`, `callableGetParameter` | Defaults are evaluated by the caller, so `getDefaultValue` is `none()` in the callee graph |
| Declarative part + statements | `callableGetBodyPart` order, or a `BlockStmt` whose first children are declarations | Elaboration order is significant (initialisers run) |
| `declare … begin … end` | `BlockStmt` (+ `TryStmt` if it has handlers) | |
| Statement list | `BlockStmt` | `IfStmt.getThen/getElse` take one `Stmt`, so Ada branch lists must be `BlockStmt`s |
| `if … elsif … else` | `IfStmt` | **Risk:** `elsif` chains have no AST node per link. Options: synthetic nested-if view, or language-specific `step`s. Same for `if` expressions → `ConditionalExpr` |
| `loop … end loop` | `LoopStmt` | infinite loop |
| `while C loop` | `WhileStmt` | |
| `for I in R loop`, `for E of C loop` | `ForeachStmt` (`getVariable`, `getCollection`) | `reverse` doesn't affect the CFG |
| `exit [L] [when C]` | `BreakStmt` + `hasLabel` | `when C` is a conditional exit; model as an implicit if, or with an extra `step` |
| `goto L` / `<<L>>` | `GotoStmt` + `Label` | The new lib allows several labelled abrupt successors out of a finally (`ControlFlowGraph.qll:2227`), which may fix the v1 gap in "goto out of finally" |
| `return`, extended `return … do … end return` | `ReturnStmt` | Extended return has a body: language-specific |
| `raise E`, `raise` expression | `Throw` | Re-raise (`raise;`) has no `getExpr` |
| Exception handlers | `TryStmt` + `CatchClause`; `when others` → `catchAll` | Choice parameter `when X : E =>` → `getVariable`. Several exception names per handler → `getCondition`? check Java multi-catch |
| GNAT `finally` | `TryStmt.getFinally` | Replaces `FinallySplitting` entirely |
| `case` statement / expression | `Switch` / `Case`; `when others` → `DefaultCase` / `matchAll` | No fall-through: `fallsThrough` is `none()` |
| `and then` / `or else` / `not` | `LogicalAndExpr` / `LogicalOrExpr` / `LogicalNotExpr` | Plain `and`/`or`/`xor` are not short-circuit: ordinary `BinaryExpr` |
| `:=` | statement, not an expression | Probably `ExprStmt`-free: give it default post-order, write = after RHS. Check how Java's `AssignExpr` ordering interacts with SSA `explicitWrite` |
| Membership, quantified, declare, `delta`/aggregates | default left-to-right, or `step`s | Quantified expressions loop: language-specific |
| `select`, `accept`, `delay`, `abort`, `requeue` | `InputSig2::step` / `beginAbruptCompletion` | Copy today's `tasking` test semantics |
| Pragmas, null statements | default leaf | |

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
  this is a rename rather than a rewrite.
- **Exit:** `ql/test/library/Ssa` unchanged; new API documented in `ssa-design.md`.

### Step 2 — `AstSig` for Ada, new graph built *alongside* the old one
- New `controlflow/internal/ControlFlowGraphImpl2.qll` with `Ast`, `Input`, `Make0/1/2`.
  Start with linear code, `if`, loops, `exit`, `return`. Then `case`, short-circuit,
  handlers, `finally`, `goto`, then tasking.
- Debug query `ql/debug/PrintCfg2.ql`, plus a **diff query** that reports edges present in
  one graph and not the other, using the same AST-node keys.
- Run the CFG inline-expectation suite against both graphs (parameterise `CfgAnnotations`).
- **Exit:** every diff in `ql/test/library/Cfg/*` is either gone or recorded in §6 as an
  accepted, explained difference (expected: only `finally*` merges).

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

## 5. Decisions (to be recorded as D-028 onwards when taken)

| # | Question | Leaning |
| --- | --- | --- |
| D-028 | Adopt shared `ControlFlowGraph`, drop CFG splitting | **Yes**, per reviewer |
| D-029 | Build the new graph alongside the old one and diff, or rewrite in place | Alongside: the diff query is the safety net |
| D-030 | Package-body elaboration: own `Callable`, or `CallableContext` | Open (Step 2) |
| D-031 | `elsif` representation | Open (Step 2) |
| D-032 | Public naming: Java's (`ControlFlowNode`), with old names deprecated for one release | Yes |

## 6. Accepted differences between the old and new graph

*(Filled in during Step 2. One row per difference: test, edge, why it's acceptable, which
query (if any) now needs ControlFlowReachability.)*

## 7. Tracker

| Step | Status | Commit |
| --- | --- | --- |
| 0 Reference reading | not started | |
| 1 `MakeSsa` | not started | |
| 2 New graph alongside | not started | |
| 3 Switch over | not started | |
| 4 Guards | not started | |
| 5 ControlFlowReachability | not started | |
| 6 Precision queries | optional | |
| 7 Docs + 0.4.0 | not started | |

## 8. Log

- **2026-10-17** — Plan written after the reviewer's feedback. Pack contents verified (§1);
  no version bump needed.

## 9. Open questions for the reviewer

- Roughly when will `codeql.controlflow.Cfg` be removed? That decides whether this blocks
  the next CLI bump.
- Is `ControlFlowGraph` as shipped in controlflow 2.0.35 (CLI 2.25.6) a reasonable target,
  or has its API changed enough since that we should bump first?
- Where do the Ruby and C# instantiations live now?

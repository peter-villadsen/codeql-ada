# Phase 7–9 work plan — Control flow graph & query expansion

Decisions for this work are made — see [DECISIONS.md](../DECISIONS.md) D-013 (CFG in QL via
the shared `codeql/controlflow` pack, expression-level, conservative exception edges) and
D-014 (port rule *ideas* not query code; waves keyed to infrastructure). **Do not re-open
the decisions.** If a task is impossible as specified, stop and report why instead of
choosing a different design.

This document is the execution plan: each task is self-contained, lists the exact files to
touch, and ends with acceptance criteria that must pass before the task is "done".

**Task order:** 7.0 → 7.1 → 7.2 → 7.3 → 7.4 → 7.5 → 7.6.
**Phase 8 (Wave A queries) is independent of Phase 7** — its tasks need no CFG and can be
done before, after, or interleaved with Phase 7, one query at a time, in any order.
Phase 9 is outline-only here; it gets its own plan doc before anyone starts it.

---

## Environment: where things run

- **Windows side** (`C:\Users\peter\source\repos\codeql-ada`): editing, git, CodeQL CLI at
  `C:\Users\peter\tools\codeql` — fine for `codeql pack` / compile-only work.
- **WSL Debian 13** (not Ubuntu): anything touching Libadalang or running the extractor
  (i.e. anything that creates a database or runs `codeql test run`).
  The repo is reachable at `/mnt/c/Users/peter/source/repos/codeql-ada`.
  Setup inside WSL:
  ```sh
  source /root/lal-venv/bin/activate
  export PYTHONPATH=/root/adacore/python LD_LIBRARY_PATH=/root/adacore/lib
  export PATH=/root/tools/codeql:$PATH   # Linux CodeQL CLI v2.25.6
  ```
- Full test suite (run from repo root, in WSL):
  `codeql test run ql/test --additional-packs=ql --search-path=extractors`
  (if that exact invocation fails, the authoritative form is in `.github/workflows/ci.yml`).

## Global traps

1. **The dbscheme does not change in this phase.** The CFG is pure QL (D-013). If you find
   yourself editing `ada.dbscheme`, `generator/gen.py`, or the extractor, stop — you have
   left the plan. Consequently `ql/lib/ada.dbscheme.stats` must NOT be regenerated.
2. **Class names**: never trust this document's `Raw::X` names blindly — the authoritative
   list is `ql/lib/codeql/ada/ast/internal/Raw.qll` (generated) and `schema/lal-nodes.json`.
   All names used below were checked against Raw.qll on 2026-07-03, but field *accessor*
   names (e.g. `getTypeDef()`) were not — look them up in Raw.qll before use.
3. **Query metadata**: every new `.ql` needs `@id ada/<kebab-name>`, `@kind problem`,
   `@problem.severity`, `@name`, `@description`, `@tags` — `codeql database analyze`
   rejects queries without kind/severity (learned the hard way in 6.3).
4. **Executable bits**: any *new* `.sh` file needs `git update-index --chmod=+x` before
   commit or CI fails with `EACCES`. (No new shell scripts are expected in this phase.)
5. **New pack dependencies change lock files**: after editing `ql/lib/qlpack.yml`
   dependencies, run `codeql pack install` in `ql/lib`, `ql/src`, and `ql/test` and commit
   the resulting `codeql-pack.lock.yml` files together with the manifest change. CI has
   network access to GHCR, so this works there too.
6. **CLI compatibility**: we support exactly CodeQL CLI 2.25.6 (D-012). Shared-pack
   versions must be chosen to match (Task 7.0 step 1), not "latest".
7. **Xref reality check**: before writing any query that depends on *what* a name resolves
   to (spec vs. body, parameter in spec vs. parameter in body), write the test `.adb` first,
   run `codeql test run --learn` with a debug query dumping `ada_xref`, and look at what
   Libadalang actually resolved to. Several Wave A specs below have an explicit
   "test-first" step for this reason. Do not guess.

---

# Phase 7 — Control flow graph

**Goal.** A CFG over Ada bodies good enough to answer, precisely: *"find calls to `Foo`
after which control can reach the end of the scope without passing a call to `Bar`"* —
the paired-call / protocol query (e.g. `Open` without `Close`, `Seize` without `Release`).
That query is Task 7.6's flagship deliverable and the phase's definition of success.

## Task 7.0 — Wire up the shared `codeql/controlflow` pack

1. **Find the right version.** The shared pack must match CLI 2.25.6. In the `github/codeql`
   repository (clone it shallow, or browse on GitHub), check out tag `codeql-cli/v2.25.6`
   and read `shared/controlflow/qlpack.yml` — note its `version:` field, and the versions of
   its dependencies (`codeql/util`, possibly others). Those exact versions are what we pin.
2. In `ql/lib/qlpack.yml`, add:
   ```yaml
   dependencies:
     codeql/controlflow: <exact version from step 1>
   ```
   (This is the first `dependencies:` block in this pack — currently it has none.)
3. Run `codeql pack install` in `ql/lib`, then `ql/src`, then `ql/test`. Commit all
   `codeql-pack.lock.yml` files.
4. **Read the API before coding.** The downloaded pack lands under
   `~/.codeql/packages/codeql/controlflow/<version>/`. Read `codeql/controlflow/Cfg.qll`
   top to bottom. Identify: the parameterized module you instantiate (`Make<...>` or
   similar), its input signature (what classes/predicates *we* must provide: AST node type,
   `CfgScope`, completions, `ControlFlowTree` methods like `first`/`last`/`succ`, location
   binding), and what it gives back (CFG node class, successor predicate, basic blocks,
   dominance). Write a short summary of the actual API names as a comment block at the top
   of `Cfg.qll` created in Task 7.2 — later tasks refer to "the API summary" and must not
   have to re-derive it. How Ruby, Swift and Rust instantiate the same signature is working
   documentation: in `github/codeql`, see each language's
   `ql/lib/codeql/<lang>/controlflow/internal/ControlFlowGraphImpl.qll` (paths vary
   slightly; search for `Cfg::Make` or `CfgImpl`).

**Acceptance:** `codeql pack install` succeeds in all three packs; a trivial query that
`import codeql.controlflow.Cfg` (or whatever the real module path is) compiles against
`ada-all`; full existing test suite still green in WSL.

## Task 7.1 — CFG design doc

Write `docs/cfg-design.md`. This is a *mapping table*, not an essay: for every
control-relevant Ada construct, which Raw classes are involved and what the successor
structure is. The table below is the required content — transcribe, verify each class name
against Raw.qll, and refine where the shared API forces a different shape.

**Scopes** (`CfgScope` — each gets its own disconnected CFG with one entry, one exit):
`Raw::BaseSubpBody` (covers `SubpBody` and `ExprFunction`), `Raw::TaskBody`,
`Raw::EntryBody`, `Raw::PackageBody` (its elaboration statements, if any). Nested bodies
are their *own* scopes — a nested `SubpBody`'s statements are NOT part of the enclosing
body's CFG.

**Completions** (ways a computation can finish): normal; return (from `ReturnStmt` /
`ExtendedReturnStmt`); exit-loop, optionally naming a loop (`ExitStmt`, whose optional
condition makes it conditional); goto-label (`GotoStmt`); raise (from `RaiseStmt`,
`RaiseExpr`, and — conservatively — every `CallExpr`/`CallStmt`, per D-013); boolean
completions (true/false) for conditions feeding branches and short-circuit operators.

**Construct table** (evaluation-order successor structure):

| Construct | Raw classes | Structure |
|---|---|---|
| Statement sequence | `StmtList` | children in order; a non-normal completion of child *i* skips children *i+1…* |
| Assignment | `AssignStmt` | RHS expr → LHS name → the stmt itself |
| Call | `CallStmt`, `CallExpr` | args left-to-right → call node; call may complete normally *or* with raise |
| If | `IfStmt`, `ElsifStmtPart` | cond(true)→then-stmts; cond(false)→next elsif cond / else-stmts / exit |
| Case | `CaseStmt`, `CaseStmtAlternative` | selector expr → exactly one alternative's stmts (branch on alternative) |
| Plain loop | `LoopStmt` | body → back edge to body start; only `ExitStmt`/return/goto/raise leaves |
| While loop | `WhileLoopStmt`, `WhileLoopSpec` | cond(true)→body→cond; cond(false)→exit |
| For loop | `ForLoopStmt`, `ForLoopSpec` | spec (range/iterator) → [body → spec]* → exit; model the spec as one opaque condition-like node deciding continue/exit |
| Exit | `ExitStmt` | if it has a condition: cond(true)→exit-completion targeting named/innermost enclosing loop, cond(false)→normal; else unconditional exit-completion |
| Block | `BlockStmt` (`DeclBlock`/`BeginBlock` — check Raw.qll for exact split) | declarative part elaborates in order (object decl initializers are evaluated!) → statements |
| Handled sequence | `HandledStmts`, `ExceptionHandler` | stmts as usual; every raise-completing node inside the protected region has an edge to *each* handler (we don't match exception identities in v1) and, if no `when others` handler exists, also a raise edge out of the scope; handler bodies then continue normally after the `HandledStmts` |
| Return | `ReturnStmt`, `ExtendedReturnStmt` | (value expr →) return completion to scope exit; extended return elaborates its object decl, runs its optional `HandledStmts`, then returns |
| Goto / label | `GotoStmt`, `Label`, `LabelDecl` | goto-completion; resolves to the `Label` with matching name in the same body (match by name text — labels are body-local in Ada) |
| Short-circuit | `BinOp` with op `OpAndThen` / `OpOrElse` | LHS(false)→skip RHS (and-then) / LHS(true)→skip RHS (or-else); plain `OpAnd`/`OpOr` evaluate both sides unconditionally |
| Conditional expr | `IfExpr`, `ElsifExprPart`, `CaseExpr`, `CaseExprAlternative` | same shape as their statement forms, but produce a value |
| Raise | `RaiseStmt`, `RaiseExpr` | raise completion |
| Tasking | `SelectStmt`, `AcceptStmt`, `AcceptStmtWithStmts`, `DelayStmt`, `AbortStmt`, `RequeueStmt` | opaque sequencing per D-013: each alternative's statements are wired sequentially inside; a `select` branches like a case over its `SelectWhenPart`s; no inter-task edges; `terminate` alternative completes the scope |
| Non-control nodes | `PragmaNode`, `UseClause`, type decls, etc. | elaborated in order where they can contain expressions (object decl defaults); pragmas skipped |
| Other expressions | everything else under `Expr` | children left-to-right, then the node itself (post-order) |

Also record in the doc: (a) declare-block and package-body *elaboration* is part of the
CFG (initializers can call functions and raise); (b) `QuantifiedExpr` and `DeclExpr` exist
(Ada 2022) — v1 may treat them as opaque post-order expressions, noted as a limitation;
(c) the conservative raise model's known effect on precision (paired-call queries will
report a call pair split by *any* intervening call as "not invariably paired" unless the
pairing query opts to ignore exceptional paths — Task 7.6 exposes both behaviors).

**Acceptance:** `docs/cfg-design.md` exists, every Raw class name in it verified to exist
in Raw.qll (grep each one), and every row of the table states its successor structure.

## Task 7.2 — Skeleton: scopes + straight-line code

Create `ql/lib/codeql/ada/controlflow/` with:

- `internal/ControlFlowGraphImpl.qll` — instantiates the shared `Make` module (per the
  API summary from 7.0). Implement: location binding, `CfgScope` (the four body classes
  from 7.1), completions (start with just normal + raise + return), and `ControlFlowTree`
  for the straight-line subset: `StmtList`, `NullStmt`, `AssignStmt`, `CallStmt`,
  `CallExpr`, `ReturnStmt`, `RaiseStmt`, identifiers/literals/dotted names and generic
  post-order expression handling.
- `Cfg.qll` — public re-export: `CfgNode`, `CfgScope`, successor predicate, entry/exit
  nodes. Every later consumer imports only this file.
- Do **not** touch `ada.qll` yet — keep the CFG import explicit in consumers until the
  API is stable (end of 7.6).

Follow the Rust implementation file as the closest structural template (it is the newest
and cleanest of the reference instantiations found in 7.0).

**Acceptance:** compiles (`codeql query compile` on a scratch query importing `Cfg.qll`
via `--additional-packs=ql`); scratch query dumping `entry → node → … → exit` over
`tests/hello/hello.adb`'s database produces a plausible chain (manual eyeball).

## Task 7.3 — Branching, loops, exit, goto

Extend `ControlFlowGraphImpl.qll` with the `IfStmt`/`CaseStmt`/loops/`ExitStmt`/`GotoStmt`/
`Label`/`BlockStmt` rows of the 7.1 table, including boolean completions for conditions
and the exit-targets-named-loop rule (an `ExitStmt` with a name targets the enclosing
`BaseLoopStmt` whose loop identifier matches; nameless targets the innermost).

**Acceptance:** the PrintCfg test from 7.5 (write its harness now if doing tasks in
order — 7.5's harness does not depend on 7.4) shows correct edges for a hand-written
`test_branching.adb` exercising: if/elsif/else, case with 3 alternatives, plain loop with
conditional exit, named outer loop exited from an inner loop, while loop, for loop, goto
backward and forward, declare block with an initialized local.

## Task 7.4 — Exceptions, short-circuit, conditional expressions

Extend with: `HandledStmts`/`ExceptionHandler` (edges per 7.1 table), raise completions
from every call node, `OpAndThen`/`OpOrElse` short-circuit shapes, `IfExpr`/`CaseExpr`,
`ExtendedReturnStmt`, and the opaque tasking constructs.

**Acceptance:** PrintCfg golden output for `test_exceptions.adb` (raise inside nested
handled sequences with and without `when others`; a call inside a protected region showing
the raise edge to the handler; handler body flowing to the statement after the block) and
`test_shortcircuit.adb` (nested `and then`/`or else` in an if condition; an `if` expression
in an assignment) match the design table — reviewed by hand, row by row, before committing
the `.expected`.

## Task 7.5 — CFG test harness

Mirror the PrintAst pattern (`ql/test/extractor/PrintAst/`):

- `ql/test/library/Cfg/PrintCfg.ql` — test-local query (no `.qlref`), selecting every CFG
  edge as `(scope, predecessorNode, successorNode, completionLabel)` with locations, ordered.
- One `.adb` per construct family: `test_linear.adb`, `test_branching.adb`,
  `test_loops.adb`, `test_exceptions.adb`, `test_shortcircuit.adb`, `test_goto.adb`,
  `test_tasking.adb`.
- Generate `.expected` via `codeql test run --learn`, then **review the learned output
  against the 7.1 table line by line** — the learn step records whatever the code does,
  including bugs. The review is the actual test; record "reviewed against design table"
  in the commit message.

**Acceptance:** `codeql test run ql/test/library/Cfg --additional-packs=ql
--search-path=extractors` green; full suite green.

## Task 7.6 — Consumer layer + flagship queries

1. **`ql/lib/codeql/ada/controlflow/BasicBlocks.qll`** — re-export the shared pack's basic
   blocks + dominance/post-dominance over our instantiation (the shared pack provides
   these; check the API summary — do not implement dominance by hand).
2. **`ql/lib/codeql/ada/controlflow/PairedCalls.qll`** — the query the CFG exists for.
   A parameterized module:
   ```
   signature predicate isFirstCall(Raw::AdaNode call);    // e.g. resolves to Open
   signature predicate isSecondCall(Raw::AdaNode call);   // e.g. resolves to Close
   module MissingPairedCall<isFirstCall/1 first, isSecondCall/1 second> {
     /* a `first` call node F such that some CFG path from F's successor reaches
        the scope's exit node without passing through any `second` call node.
        Implement as: reachableWithoutSecond(node) = successor closure that never
        steps onto a `second` call node; flag F when exit is in that closure.
        Provide two entry points: strict (all paths, including exceptional edges)
        and normalPathsOnly (ignore raise-completion edges) — see D-013 note on
        conservative raises. */
   }
   ```
   Exact signature/module syntax: follow how the shared dataflow pack declares
   parameterized modules if unsure (`signature`/`module ... < ... >` is standard QL 2;
   the QL language docs shipped with the CLI cover it).
3. **Rewrite `ql/src/queries/UnreachableStatement.ql`** on the CFG: a statement CFG node
   (in a scope) not reachable from the scope entry. Keep `@id ada/unreachable-statement`.
   Keep the label-exclusion behavior only if the CFG doesn't already handle goto (it does —
   so the old heuristic exclusions should be deletable; the old test file must still pass,
   extended with a case the old query could not catch, e.g. code after `if C then return;
   else return; end if;`).
4. **New query `ql/src/queries/FunctionMissingReturn.ql`** (`@id
   ada/function-missing-return`, severity error): a function body (`SubpBody` whose spec
   has a return type — check Raw.qll for how `SubpSpec` exposes the returns clause) whose
   CFG exit is reachable with a *normal* (fall-off-the-end) completion. Running off the end
   of an Ada function raises `Program_Error` at run time — legal to compile, always a bug.
5. **New query `ql/src/queries/OpenWithoutClose.ql`** (`@id ada/open-without-close`,
   severity warning): instantiate `MissingPairedCall` with first = calls resolving to
   `Ada.Text_IO.Open`/`Create` (match the resolved decl's fully qualified name via
   `getReferencedDecl()` + enclosing-package names; fall back to dotted-name text match
   `ada.text_io.open` when xref fails — GNAT runtime sources are usually not in the
   analyzed set, so **test which of the two actually fires first**, per Global trap 7),
   second = `Close`/`Delete` on the same package. Use the `normalPathsOnly` variant for
   v1 signal quality; mention the strict variant in the query doc comment.
   This query is also the worked example for the query-writing guide: add a section to
   `docs/query-writing.md` showing how a user instantiates `MissingPairedCall` for their
   own `Foo`/`Bar` pair (that is the user-facing answer to "find places where a call to
   foo() is not invariably followed by a call to bar()").
6. Tests for 3–5 under `ql/test/queries/<Name>/` in the established pattern.

**Acceptance:** 3 CFG-based queries with green tests; `codeql database analyze` with the
full `ada-queries` pack runs clean on the gpr2 corpus database (no compile errors; findings
themselves are informational); full suite green; CI green.

---

# Phase 8 — Wave A queries (no CFG required)

Eleven independent tasks; any order; each is: write the `.ql` in `ql/src/queries/`, write
the test in `ql/test/queries/<Name>/` (`.qlref` + `test.adb` + learned-and-reviewed
`.expected`), run the full suite. Every query: `@kind problem` + `@problem.severity` +
`@id` as listed (Global trap 3). Class names verified 2026-07-03 unless flagged; accessor
names must be looked up in Raw.qll (Global trap 2).

Source attribution per D-014: where a spec says "GNATcheck: X", that is the rule idea being
ported; say so in the query's `@description` or doc comment.

### 8.1 `ada/boolean-literal-comparison` — comparison with True/False
`Raw::RelationOp` whose operator is `Raw::OpEq`/`Raw::OpNeq` and one operand is a `Name`
whose lower-cased `getText()` is `"true"`/`"false"` (covers `Standard.True` via the dotted
form — `getText()` already handles `DottedName`). Message: use the expression (or its
negation) directly. Severity recommendation; tags maintainability, readability.

### 8.2 `ada/identical-operands` — `X and X`, `X or else X`, `X xor X`
Same technique as the existing SelfComparison (read it first): `Raw::BinOp` with op in
{`OpAnd`, `OpOr`, `OpAndThen`, `OpOrElse`, `OpXor`}, both operands `Name`s with the same
`getReferencedDecl()`. Do not flag when either operand contains a `CallExpr` beneath it
(function results can differ). Severity warning; tags correctness.

### 8.3 `ada/useless-if` — `if C then null; end if;` with no else/elsif
`Raw::IfStmt` whose then-`StmtList` has exactly one child, a `Raw::NullStmt`, and which has
no elsif parts and an empty/absent else part (check in Raw.qll how absent fields present —
likely no row). Do NOT flag when an else or elsif exists (`then null` is then idiomatic
"do nothing in this case"). Severity warning; tags maintainability.

### 8.4 `ada/empty-loop-body` — loop whose body is only `null;`
`Raw::BaseLoopStmt` whose `StmtList` is a single `NullStmt`. Catches busy-waits and
forgotten stubs. Severity warning; tags correctness, concurrency.

### 8.5 `ada/float-equality` — `=` / `/=` on floating-point operands
`Raw::RelationOp` with op `OpEq`/`OpNeq` where either operand's `Expr.getType()` (the
stored `ada_expr_type`, via the existing `Expr` class in `ada.qll`) is a type whose
type definition is a `Raw::FloatingPointDef`. Navigation from `BaseTypeDecl` to its type
def: find the accessor in Raw.qll (a `TypeDecl` field holding the `TypeDef`). v1 matches
direct float type decls only — derived-type chains are a documented limitation (comment in
the query). This is the showcase for the stored-types layer. Severity warning; tags
correctness, numerics.

### 8.6 `ada/goto-statement` — any goto
`Raw::GotoStmt`, unconditionally. GNATcheck: `goto_statements`. Severity recommendation;
tags maintainability. Trivial — a good first task to learn the pipeline.

### 8.7 `ada/raise-predefined-exception` — explicit raise of a language-defined exception
`Raw::RaiseStmt` whose exception `Name.getText()` lower-cased, with any `standard.` prefix
stripped, is one of `constraint_error`, `program_error`, `storage_error`, `tasking_error`,
`numeric_error`. GNATcheck: `raising_predefined_exceptions`. Severity recommendation; tags
maintainability, error-handling.

### 8.8 `ada/unused-parameter` — parameter never referenced in the body
**Test-first (Global trap 7):** write `test.adb` containing (a) a spec-less procedure with
an unused parameter, (b) a spec+body pair with an unused parameter, (c) a used parameter,
(d) an unused parameter with `pragma Unreferenced`; dump `ada_xref` rows for it and record
which `ParamSpec` (spec's or body's) references resolve to. Then: flag a
`Raw::ParamSpec` under a `Raw::SubpBody` none of whose defining names is the target of any
xref (use `BasicDecl.isReferenced()`; extend the check to the matching spec-side
`ParamSpec` if the dump showed resolution targets the spec). Exclusions: subprogram has an
`overriding` marker (find the Raw class for the overriding node in Raw.qll —
grep `Overriding`); a `pragma Unreferenced` in the body names the parameter
(`Raw::PragmaNode` with name `unreferenced`, argument text match); `Raw::NullSubpDecl` and
`Raw::ExprFunction` bodies; generic formal subprograms. Known accepted FPs (document in
query comment): dispatching primitives and subprograms taken with `'Access` must keep
their profile. Severity recommendation; tags maintainability.

### 8.9 `ada/dead-local-subprogram` — nested subprogram never called
`Raw::SubpBody` nested inside another body (it has a `getEnclosingSubprogram()`), where
neither the body itself nor any same-named `Raw::BasicSubpDecl` declared in the same
enclosing body `isReferenced()`. The same-name-text pairing is an approximation — the DB
has no decl↔body semantic link (document as limitation; overload sets with mixed liveness
may be missed, which errs toward silence, the right direction). Exclude bodies whose name
is referenced in any `'Access`/`'Unrestricted_Access` attribute (grep Raw.qll for the
attribute-ref node class). Severity warning; tags maintainability, dead-code.

### 8.10 `ada/direct-recursion` — subprogram calls itself
**Test-first** like 8.8: check what a recursive call resolves to when the subprogram has a
separate spec (the spec's decl) vs. not (the body). Flag a call name inside `SubpBody` b
resolving to b, or resolving to a `BasicSubpDecl` whose name text equals b's name and which
shares b's enclosing declarative region (same approximation and rationale as 8.9).
GNATcheck: `recursive_subprograms` — unbounded stack use matters to this audience
(embedded/safety). Severity recommendation; tags resources, safety-critical.

### 8.11 `ada/warnings-off` — blanket `pragma Warnings (Off)`
`Raw::PragmaNode` with name text `warnings` (case-insensitive) whose first argument is the
identifier `Off` **and** which has no further argument restricting it to a specific warning
string or entity (a bare global disable). Companion to the existing PragmaSuppress query —
read it first and copy its argument-extraction technique. Severity recommendation; tags
maintainability, auditing.

**Phase 8 acceptance (overall):** 11 new queries, 11 green tests, full suite green,
`codeql database analyze` clean over the gpr2 corpus DB, CI green. Rule count 11 → 22.

---

# Phase 9 — SSA + dataflow (outline only — needs its own plan before starting)

Not to be started from this document. The shape, for orientation:

1. Instantiate `codeql/ssa` (shared pack) over the Phase 7 CFG + basic blocks.
2. Instantiate `codeql/dataflow` (the shared framework the C/C++/C#/Ruby/Swift taint
   queries all sit on): local flow from SSA, global flow steps through calls using
   `ada_xref` to resolve targets, field/array content steps deferred.
3. First taint queries with Ada-specific sources/sinks:
   `Ada.Command_Line`/`Ada.Environment_Variables`/`Ada.Text_IO.Get_Line` as sources;
   `GNAT.OS_Lib.Spawn`/`System` command execution, `GNATCOLL.SQL` string queries, and
   file-path sinks (`Ada.Text_IO.Open` name parameter, `Ada.Directories`) as sinks.
   This is where the C# security suite's *ideas* (command injection, path injection,
   SQL injection, cleartext storage) become genuinely portable (D-014, Wave C).
4. New dead-store / uninitialized-variable queries land here too (they need SSA, not just
   the CFG).

Prerequisites before writing the Phase 9 plan: Phase 7 complete and exercised by the
Task 7.6 queries on the corpus for at least one release cycle, so CFG bugs surface before
dataflow is built on top.

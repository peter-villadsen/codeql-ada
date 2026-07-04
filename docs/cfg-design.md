# CFG design — construct → successor mapping

This is the mapping table that `ql/lib/codeql/ada/controlflow/internal/ControlFlowGraphImpl.qll`
implements against the shared `codeql/controlflow` framework (D-013). It is a reference
table, not an essay. Every `Raw::` class and accessor named here was verified against
`ql/lib/codeql/ada/ast/internal/Raw.qll` on 2026-07-03 (the generated Raw layer, pinned
dbscheme — the CFG is pure QL and does **not** change the dbscheme).

The framework is instantiated via `Cfg::Make<Location, Input>` — the **no-splitting**
variant (`shared/controlflow/codeql/controlflow/Cfg.qll` line ~1575). Conditional
completions are therefore *unsplit*: an `if x and then y` produces both true/false edges
out of every boolean-context sub-expression without pruning impossible combinations. This
is sound (over-approximate) and sufficient for v1; splitting (`MakeWithSplitting`) is a
future precision upgrade, tracked for post-Phase-9.

## The framework contract (what we implement)

`Cfg::InputSig` requires: `AstNode`, `Completion`, `CfgScope`, the three completion
predicates (`completionIsNormal`, `completionIsSimple`, `completionIsValidFor`),
`getCfgScope`, `scopeFirst`, `scopeLast`, `getAMatchingSuccessorType`, and the two
`idOf*` predicates. We set `AstNode = Raw::AdaNode` and `Location = Raw::Location`.

The CFG itself is built by extending the framework's `ControlFlowTree` class (and its
helpers `PreOrderTree`, `PostOrderTree`, `StandardPreOrderTree`, `StandardPostOrderTree`,
`LeafTree`) once per control-relevant construct, implementing `first`/`last`/`succ`/
`propagatesAbnormal`. The framework then yields `Node`, `getASuccessor`, the
`BasicBlocks` submodule (dominance/post-dominance — reused verbatim in Task 7.6), and a
`PrintGraph` interface (used by the Task 7.5 PrintCfg harness).

## Scopes

Each `CfgScope` gets its own disconnected graph with one entry and one exit. Nested
bodies are their **own** scopes — a nested `SubpBody`'s statements are NOT part of the
enclosing body's CFG.

| Scope | Raw class | Body accessor |
|---|---|---|
| Subprogram / expression function | `Raw::BaseSubpBody` | `SubpBody.getStmts()` → `HandledStmts`; `ExprFunction.getExpr()` → `Expr` |
| Task body | `Raw::TaskBody` | `getStmts()` → `HandledStmts` |
| Entry body | `Raw::EntryBody` | `getStmts()` → `HandledStmts` (barrier `getBarrier()` is elaborated before entry) |
| Package body | `Raw::PackageBody` | `getStmts()` → `HandledStmts` (elaboration statements, if any) |

`BaseSubpBody` covers both `SubpBody` (has `getStmts()`) and `ExprFunction` (has
`getExpr()`, no statement list). `scopeFirst` enters the body's first elaborated decl or,
if none, the first statement (or, for an expression function, the return expression).

## Completions

A completion models how a statement/expression finishes. v1 completion set (a QL
`newtype`), with the shared `SuccessorType` each maps to via `getAMatchingSuccessorType`:

| Completion | `simple` | `normal` | Successor type | Emitted by |
|---|---|---|---|---|
| `NormalCompletion` | yes | yes | `DirectSuccessor` | every node (default) |
| `BooleanCompletion(b)` | no | yes | `BooleanSuccessor(b)` | boolean-context expressions feeding a branch / short-circuit |
| `ReturnCompletion` | no | no | `ReturnSuccessor` | `ReturnStmt`, `ExtendedReturnStmt` |
| `RaiseCompletion` | no | no | `ExceptionSuccessor` | `RaiseStmt`, `RaiseExpr`, and conservatively every `CallStmt`/`CallExpr` |
| `ExitCompletion(loop)` | no | no | `BreakSuccessor` | `ExitStmt` (targets a `BaseLoopStmt`) |
| `GotoCompletion(label)` | no | no | `GotoSuccessor` | `GotoStmt` (targets a `Raw::Label`) |

`completionIsSimple` selects the single canonical normal completion used for the
pre-order self→first-child edge (never a boolean-labelled one). `completionIsNormal` is
the broader "non-abnormal" set (normal + boolean) that flows to the next sibling in a
`StmtList` and is caught by loops. Abnormal completions (`return`/`raise`/`exit`/`goto`)
propagate outward via `propagatesAbnormal` until a surrounding construct catches them:
a loop turns a matching `ExitCompletion` into normal, a `HandledStmts` turns a
`RaiseCompletion` into normal (handler entry), and the scope exit absorbs the rest.

## Construct table (evaluation-order successor structure)

Accessors are the verified `Raw::` predicate names. "post-order" = children left-to-right
then the node (`StandardPostOrderTree`); "pre-order" = the node then children
(`StandardPreOrderTree`).

| Construct | Raw class(es) | Accessors | Structure |
|---|---|---|---|
| Statement sequence | `StmtList` (`extends AdaNodeList`) | `getChild(i)` | children in evaluation order; a non-normal completion of child *i* skips *i+1…* (StandardTree default) |
| Null statement | `NullStmt` | — | leaf; completes normally |
| Assignment | `AssignStmt` | `getExpr()` (RHS), `getDest()` (LHS `Name`) | post-order: RHS → LHS → stmt |
| Call (stmt) | `CallStmt` | `getCall()` → `Name` (a `CallExpr` when it has args) | evaluate call name/args → call node; completes normally *or* `RaiseCompletion` |
| Call (expr) | `CallExpr` (`extends Name`) | `getName()`, `getSuffix()` (arg/index list) | post-order over name+suffix; the node completes normally *or* `RaiseCompletion` |
| If statement | `IfStmt`, `ElsifStmtPart`, `ElsePart` | `getCondExpr()`, `getThenStmts()`, `getAlternatives()` → `ElsifStmtPartList`, `getElsePart()`; elsif: `getCondExpr()`/`getStmts()`; else: `getStmts()` | cond(true)→then-stmts; cond(false)→next elsif cond / else-stmts / past-if |
| Case statement | `CaseStmt`, `CaseStmtAlternative` | `getExpr()`, `getAlternatives()` → `CaseStmtAlternativeList`; alt: `getChoices()`, `getStmts()` | selector expr → exactly one alternative's stmts (branch on alternative; `MatchingSuccessor` per choice) |
| Plain loop | `LoopStmt` (`extends BaseLoopStmt`) | `getStmts()` → `StmtList` (no `getSpec()`) | body → back-edge to body start; only `ExitStmt`/return/goto/raise leaves |
| While loop | `WhileLoopStmt`, `WhileLoopSpec` | `getSpec()` → `WhileLoopSpec`; spec `getExpr()` | cond(true)→body→cond; cond(false)→past-loop |
| For loop | `ForLoopStmt`, `ForLoopSpec` | `getSpec()` → `ForLoopSpec`; spec `getVarDecl()`, `getIterExpr()` | spec (range/iterator) modeled as one opaque continue/exit node → [body → spec]* → past-loop |
| Exit | `ExitStmt` | `getCondExpr()` (optional), `getLoopName()` → `Name` (optional) | with condition: cond(true)→`ExitCompletion` to named/innermost loop, cond(false)→normal; else unconditional `ExitCompletion` |
| Block | `BlockStmt` → `DeclBlock` / `BeginBlock` | `DeclBlock.getDecls()`+`getStmts()`; `BeginBlock.getStmts()` | declarative part elaborates in order (object-decl initializers are evaluated) → `getStmts()` (a `HandledStmts`) |
| Handled sequence | `HandledStmts`, `ExceptionHandler` | `getStmts()` → `StmtList`, `getExceptions()` → `AdaNodeList` of handlers; handler: `getHandledExceptions()`, `getStmts()` | run stmts; every raise-completing node in the protected region has an edge to *each* handler (v1 does not match exception identities); if no `when others`, also a raise edge out of the scope; handler bodies continue normally after the `HandledStmts` |
| Return | `ReturnStmt` | `getReturnExpr()` (optional) | (value expr →) `ReturnCompletion` to scope exit |
| Extended return | `ExtendedReturnStmt` | `getDecl()` → `ExtendedReturnStmtObjectDecl`, `getStmts()` → `HandledStmts` | elaborate object decl → run optional `HandledStmts` → `ReturnCompletion` |
| Goto / label | `GotoStmt`, `Label`, `LabelDecl` | goto `getLabelName()` → `Name`; label `getDecl()` → `LabelDecl` | `GotoCompletion` resolving to the `Label` with matching name in the same body (labels are body-local; match by name text) |
| Short-circuit | `BinOp` with `getOp()` ∈ `{OpAndThen, OpOrElse}` | `getLeft()`, `getOp()` → `Op`, `getRight()` | and-then: LHS(false)→skip RHS; or-else: LHS(true)→skip RHS. Plain `OpAnd`/`OpOr` evaluate both sides unconditionally (post-order) |
| Conditional expr | `IfExpr`, `ElsifExprPart`, `CaseExpr`, `CaseExprAlternative` | `IfExpr.getCondExpr()`/`getThenExpr()`/`getAlternatives()`/`getElseExpr()`; `CaseExpr.getExpr()`/`getCases()` | same branch shape as their statement forms, but produce a value |
| Raise | `RaiseStmt`, `RaiseExpr` | `getExceptionName()` → `Name` (optional; bare `raise;` re-raise has none) | `RaiseCompletion` |
| Tasking | `SelectStmt`, `SelectWhenPart`, `AcceptStmtWithStmts`, `DelayStmt`, `AbortStmt`, `RequeueStmt` | `SelectStmt.getGuards()` → `SelectWhenPartList`, `getElsePart()`, `getThenAbortPart()`; `SelectWhenPart.getCondExpr()`/`getStmts()`; `AcceptStmtWithStmts.getStmts()` | opaque sequencing per D-013: each alternative's statements wired sequentially; `select` branches like a case over its `SelectWhenPart`s; no inter-task edges; `terminate` alternative completes the scope |
| Non-control nodes | `PragmaNode`, `UseClause`, type decls | — | elaborated in order where they can contain expressions (object-decl defaults); pragmas are skipped |
| Other expressions | everything else under `Expr` (`Name`, `Identifier`, `DottedName`, literals, `UnOp`, non-short-circuit `BinOp`, aggregates, …) | `getChild(i)` | children left-to-right, then the node itself (post-order) |

## Additional recorded facts

- **(a) Elaboration is part of the CFG.** Declare-block (`DeclBlock.getDecls()`) and
  package-body elaboration statements are in the graph, because object-declaration
  initializers can call functions and raise. `DeclarativePart.getDecls()` →
  `AdaNodeList` gives the declarations in order.
- **(b) Ada 2022 `QuantifiedExpr` and `DeclExpr` exist** in Raw.qll. v1 treats them as
  opaque post-order expressions (their quantifier/declaration sub-structure is not
  modeled) — documented limitation, revisit if a query needs their internal flow.
- **(c) Conservative-raise precision.** Because every `CallStmt`/`CallExpr` may complete
  with `RaiseCompletion` (D-013), a paired-call query will report a call pair split by
  *any* intervening call as "not invariably paired" on the exceptional path — unless the
  pairing query ignores raise-completion edges. Task 7.6's `MissingPairedCall` therefore
  exposes both a strict variant (all paths) and a `normalPathsOnly` variant (ignore
  raise edges); the `open-without-close` query uses `normalPathsOnly` for v1 signal
  quality.

## Wrapper/consumer notes (from `ada.qll`)

- `Name.getText()` (recursive over identifiers/dotted names) and
  `Name.getReferencedDecl()` (via `ada_xref`) are the tools for resolving `ExitStmt`
  loop names and `GotoStmt` labels textually, and for the paired-call target match.
- Named loops/blocks are wrapped: `Outer: loop … end loop Outer;` is a
  `Raw::NamedStmt` (`getDecl()` → `NamedStmtDecl`, `getStmt()` → the `LoopStmt`). An
  `ExitStmt` naming a loop matches the enclosing `BaseLoopStmt` whose `NamedStmtDecl`
  name text equals `getLoopName().getText()`; a nameless `ExitStmt` targets the
  innermost enclosing `BaseLoopStmt`.

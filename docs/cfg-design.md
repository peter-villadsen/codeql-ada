# CFG specification — construct → successor structure

This is the specification of the Ada control-flow graph built by
`ql/lib/codeql/ada/controlflow/internal/ControlFlowGraphImpl.qll` on the shared
`codeql/controlflow` framework (D-013). For every control-relevant construct it gives an
Ada snippet and the exact edges that snippet produces, so the graph can be checked by
hand. Every construct section is backed by a conformance test under
`ql/test/library/Cfg/<family>/` whose `test.adb` carries the same edges as machine-checked
inline annotations (D-017); the tests are the enforcement, this document is the rule they
enforce.

Every `Raw::` class and accessor named here was verified against
`ql/lib/codeql/ada/ast/internal/Raw.qll` (the generated Raw layer, pinned dbscheme — the
CFG is pure QL and does **not** change the dbscheme).

---

## Part 1 — How the graph is built

### The framework instantiation

The framework is instantiated via `Cfg::Make<Location, Input>` — the **no-splitting**
variant (`shared/controlflow/codeql/controlflow/Cfg.qll` line ~1575). Conditional
completions are therefore *unsplit*: an `if x and then y` produces both true/false edges
out of every boolean-context sub-expression without pruning impossible combinations. This
is sound (over-approximate) and sufficient for v1; splitting (`MakeWithSplitting`) is a
future precision upgrade, tracked for post-Phase-9.

`Cfg::InputSig` requires: `AstNode`, `Completion`, `CfgScope`, the three completion
predicates (`completionIsNormal`, `completionIsSimple`, `completionIsValidFor`),
`getCfgScope`, `scopeFirst`, `scopeLast`, `getAMatchingSuccessorType`, and the two
`idOf*` predicates. We set `AstNode = Raw::AdaNode` and `Location = Raw::Location`, both
as **plain aliases** (no wrapper classes).

Two structural facts that follow from the alias choice (learned while implementing 7.2):

- **`Raw::Location` must satisfy `LocationSig`.** The shared framework's `LocationSig`
  requires `getStartLine`/`getStartColumn`/`getEndLine`/`getEndColumn` on the location
  type. The generator (`generator/gen.py`) emits these four accessors on `Raw::Location`
  (pure QL over the existing `locations_default` relation — **no dbscheme change**). A
  wrapper `AstNode` with a covariant `getLocation()` override is *not* viable: it makes
  every tree class (which multiply-inherits a `Raw::` node class) fail with
  "`StandardPostOrderTree` is incompatible with `Raw::…`".
- **Tree classes use `extends <Helper> instanceof Raw::X`, not `extends <Helper>, Raw::X`.**
  Because `AstNode = Raw::AdaNode` is an alias, the framework's `ControlFlowTree` already
  reaches `Raw::AdaNode` via a `final` alias; a second `extends Raw::X` path is rejected as
  "extends the type … but also extends a final alias of it". So subclasses constrain with
  `instanceof` and reach node accessors through `super.` (e.g. `super.getStmts()`), and
  every override that returns/takes an AST node is typed `Raw::AdaNode` (the alias target),
  since `AstNode` itself is private inside `Make`.

The CFG is built by extending the framework's `ControlFlowTree` class (and its helpers
`PreOrderTree`, `PostOrderTree`, `StandardPreOrderTree`, `StandardPostOrderTree`,
`LeafTree`) once per control-relevant construct, implementing `first`/`last`/`succ`/
`propagatesAbnormal`. The framework then yields `Node`, `getASuccessor`, the `BasicBlocks`
submodule (dominance/post-dominance) and a `PrintGraph` interface.

### Three patterns that shape everything below

- **`GenericPostOrderTree` covers only *expression-like* nodes** — `Raw::Expr`,
  `Raw::AssocList`, `Raw::BasicAssoc` — and never `Raw::Op` (operators are not "executed")
  nor `Raw::CallExpr` (handled specially). It must **not** be a catch-all over `AdaNode`:
  a generic post-order tree wires its *reached* children back to itself, so if it covered
  structural statement/declaration parts (`ElsifStmtPart`, `CaseStmtAlternative`,
  `WhileLoopSpec`, `ForLoopSpec`, `ObjectDecl`, …) those would leak into the graph as
  spurious reachable nodes. Structural parts are consumed **directly** by their owning
  construct's tree (e.g. `CaseStmtTree` reads each alternative's `getStmts()`, never the
  `CaseStmtAlternative` node), which keeps them out of the graph. This is why so many node
  kinds carry the verdict `structural` in the coverage appendix.
- **`if`/`case`/loops are `PostOrderTree`s whose self-node is the join/exit.** A condition
  emits `BooleanCompletion(true/false)`; branch/loop bodies converge on the construct node,
  which then completes normally to the next statement. A plain `loop`'s node is reachable
  only via an `exit`, so an exit-less loop is correctly infinite.
- **`exit` and `goto` are direct jump edges, not propagated completions.** `ExitStmtTree`
  adds a `succ` edge from the exit node straight to the **target loop node** (resolved by
  `exitTargetLoop`: named → matching enclosing `NamedStmt` loop, nameless → innermost),
  labelled `ExitCompletion`→`BreakSuccessor`; `GotoStmtTree` edges straight to the target
  `Label` node (`gotoTargetLabel`: same `CfgScope`, matching name text). No jump completion
  bubbles up through `propagatesAbnormal`, so there is no catch-and-relabel machinery.

Exception routing lives in `HandledStmtsTree`, keyed off the region's `last` — see
[Exceptions](#exceptions).

### Scopes

Each `CfgScope` gets its own disconnected graph with one entry and one exit. Nested
bodies are their **own** scopes — a nested `SubpBody`'s statements are NOT part of the
enclosing body's CFG.

| Scope | Raw class | Body accessor |
|---|---|---|
| Subprogram | `Raw::SubpBody` | `getStmts()` → `HandledStmts` |
| Expression function | `Raw::ExprFunction` | `getExpr()` → `Expr` |
| Task body | `Raw::TaskBody` | `getStmts()` → `HandledStmts` |
| Entry body | `Raw::EntryBody` | `getStmts()` → `HandledStmts` (barrier `getBarrier()` is elaborated before entry) |
| Package body | `Raw::PackageBody` | `getStmts()` → `HandledStmts` (elaboration statements, if any) |

### Completions

A completion models how a statement/expression finishes. The v1 completion set (a QL
`newtype` in `internal/Completion.qll`), with the shared `SuccessorType` each maps to via
`getAMatchingSuccessorType`, and the edge label that appears in an annotation:

| Completion | `simple` | `normal` | Successor type | Label | Emitted by |
|---|---|---|---|---|---|
| `SimpleCompletion` | yes | yes | `DirectSuccessor` | `successor` | every node (default) |
| `BooleanCompletion(b)` | no | yes | `BooleanSuccessor(b)` | `true` / `false` | boolean-context expressions feeding a branch / short-circuit |
| `ReturnCompletion` | no | no | `ReturnSuccessor` | `return` | `ReturnStmt`, `ExtendedReturnStmt` |
| `RaiseCompletion` | no | no | `ExceptionSuccessor` | `exception` | `RaiseStmt`, `RaiseExpr`, and conservatively every `CallStmt`/`CallExpr` |
| `ExitCompletion` | no | no | `BreakSuccessor` | `break` | `ExitStmt` (targets a `BaseLoopStmt`) |
| `GotoCompletion` | no | no | `GotoSuccessor` | `goto` | `GotoStmt` (targets a `Raw::Label`) |

`completionIsSimple` selects the single canonical normal completion used for the
pre-order self→first-child edge (never a boolean-labelled one). `completionIsNormal` is
the broader "non-abnormal" set (simple + boolean) that flows to the next sibling in a
`StmtList` and is caught by loops. Abnormal completions (`return`/`raise`/`exit`/`goto`)
propagate outward via `propagatesAbnormal` until a surrounding construct catches them:
a loop turns a matching `ExitCompletion` into normal, a `HandledStmts` turns a
`RaiseCompletion` into normal (handler entry), and the scope exit absorbs the rest.

`RaiseCompletion` is **additive**: a call node completes both `successor` (normal return)
and `exception`. Everything else is exclusive.

---

## Part 2 — How to read a construct section

Each section states the rule in one sentence, shows a numbered snippet, and lists the
edges it produces:

```
l1: if (expr)
l2:    stmt
l3:

l1 -> l2 ; expression is true
l1 -> l3 ; expression is false
l2 -> l3
```

Positions in the edge listings are `<QlClass>@<line>:<column>`, matching what
`ql/debug/PrintCfg.ql` prints and what the conformance annotations use. The
`AnnotatedExitNode`s of a scope render as `exitSubpBody(normal)` / `exitSubpBody(abnormal)`
and both feed the single `exitSubpBody` node.

### The conformance tests

Each section links its test directory. A test is `test.adb` (annotated), `test.ql` (a
one-line `import library.Cfg.CfgConformance`) and an **empty** `test.expected`. The
annotation syntax is

```
-- $ edge=<predecessor>|<label>|<successor>
```

and the check is exhaustive in both directions: an unannotated edge fails with "Unexpected
result", an annotation with no edge fails with "Missing result".

**The annotation goes on the line where the predecessor node *ends*** — the framework
matches a comment's start line against the result location's end line. For an `IfStmt`
spanning lines 5–11 that is line 11 (`end if;`); for the single-line nodes that make up
most of a graph the distinction does not arise. A scope's entry and exit nodes span the
whole body, so their edges are annotated on the body's last line.

Deliberate imprecisions are written as `$ MISSING: edge=…` rather than described in prose
(D-019), so the framework reports "Fixed missing result" the day one is fixed.

### Workflow when adding or changing a construct

1. Write the rule and the edge listing in this document **first**, derived from the
   construct's tree class.
2. Write the minimal `test.adb`.
3. Run `ql/debug/CfgAnnotations.ql` (or just run the test and read the "Unexpected result"
   lines, which carry the same values) to see the actual graph.
4. Compare with step 1. If they differ, decide which is wrong and say so in the commit
   message. **Never** paste the tool's output over a rule it contradicts — that turns the
   conformance test into a tautology.
5. Transcribe, run, commit.

---

## Part 3 — Construct specifications

> **Interim index (Phase 7.7 in progress).** The table below is the prose mapping this
> document carried before the per-construct sections existed. A row is authoritative only
> until the corresponding section below is written; **delete the row when its section
> lands**, and the table with the last one. It is kept so that an interrupted phase never
> leaves a construct undocumented.
>
> | Construct | Raw class(es) | Structure |
> |---|---|---|
> | Statement sequence | `StmtList` | children in evaluation order; a non-normal completion of child *i* skips *i+1…* |
> | If statement | `IfStmt`, `ElsifStmtPart`, `ElsePart` | cond(true)→then-stmts; cond(false)→next elsif cond / else-stmts / past-if |
> | Case statement | `CaseStmt`, `CaseStmtAlternative` | selector expr → exactly one alternative's stmts; alternatives converge on the join |
> | Plain loop | `LoopStmt` | body → back-edge to body start; only `ExitStmt`/return/goto/raise leaves |
> | While loop | `WhileLoopStmt`, `WhileLoopSpec` | cond(true)→body→cond; cond(false)→past-loop |
> | For loop | `ForLoopStmt`, `ForLoopSpec` | spec modelled as one opaque continue/exit node → [body → spec]* → past-loop |
> | Exit | `ExitStmt` | with condition: cond(true)→`break` to named/innermost loop, cond(false)→normal; else unconditional `break` |
> | Block | `BlockStmt` → `DeclBlock` / `BeginBlock` | declarative part elaborates in order (object-decl initialisers are evaluated) → `getStmts()` |
> | Handled sequence | `HandledStmts`, `ExceptionHandler` | every raise-completing node in the protected region has an edge to *each* handler; if no `when others`, also a raise edge out of the scope; handler bodies continue normally after the sequence |
> | Return | `ReturnStmt` | (value expr →) `return` to scope exit |
> | Extended return | `ExtendedReturnStmt` | elaborate object decl → run optional `HandledStmts` → `return` |
> | Goto / label | `GotoStmt`, `Label`, `LabelDecl` | `goto` edge to the `Label` with matching name in the same body |
> | Short-circuit | `BinOp` with `OpAndThen`/`OpOrElse` | and-then: LHS(false)→skip RHS; or-else: LHS(true)→skip RHS. Plain `OpAnd`/`OpOr` evaluate both sides |
> | Conditional expr | `IfExpr`, `ElsifExprPart`, `CaseExpr`, `CaseExprAlternative` | same branch shape as their statement forms, but produce a value |
> | Raise | `RaiseStmt`, `RaiseExpr` | `exception` |
> | Tasking | `SelectStmt`, `AcceptStmtWithStmts`, `DelayStmt`, … | opaque sequencing per D-013; `select` branches like a case over its `SelectWhenPart`s |
> | Elaboration | `DeclBlock.getDecls()`, package-body decls | object-declaration initialisers are in the graph, because they can call functions and raise |

### Linear code

Test: [`ql/test/library/Cfg/linear/`](../ql/test/library/Cfg/linear/)

**Rule.** Statements in a `StmtList` run in order, each flowing to the *first* node of the
next. Expressions evaluate post-order (children left to right, then the node itself). An
assignment evaluates its **right-hand side before its left-hand side**, then the statement
node. A call evaluates the callee name, then the argument list, then the call node — and
additionally completes `exception`, per the conservative raise model.

```
l1: procedure Linear (N : Integer) is
l2:    procedure Log (X : Integer) is null;
l3:    Total : Integer;
l4: begin
l5:    null;
l6:    Total := N + 1;
l7:    Log (Total);
l8: end Linear;

enter          -> l5 NullStmt        ; scope entry enters the first statement
l5 NullStmt    -> l6 N               ; next statement, entered at its first node
l6 N           -> l6 1               ; post-order: left operand, then right
l6 1           -> l6 BinOp           ; then the operator node
l6 BinOp       -> l6 Total           ; RHS done, now the assignment target
l6 Total       -> l6 AssignStmt      ; post-order: the statement node last
l6 AssignStmt  -> l7 Log             ; next statement, entered at the callee name
l7 Log         -> l7 Total           ; then the argument list
l7 Total       -> l7 ParamAssoc      ; post-order through the association wrappers
l7 ParamAssoc  -> l7 AssocList
l7 AssocList   -> l7 CallExpr
l7 CallExpr    -> l7 CallStmt        ; normal return from the call
l7 CallExpr    -> exit (abnormal)    ; exception: any call may raise (D-013)
l7 CallStmt    -> exit (normal)      ; last statement completes the scope
l7 CallStmt    -> exit (abnormal)    ; exception
```

Note what produces **no** nodes: `Log` on l2 is a `NullSubpDecl`, a declaration rather
than a body, so it is not a scope and contributes nothing; `Total` on l3 has no
initialiser, so nothing is elaborated. See [Scopes](#scopes-1) for what happens when a
declaration *does* have an initialiser.

### Scopes

TODO — task 7.7.3.

### If statement

TODO — task 7.7.4.

### Case statement

TODO — task 7.7.5.

### Plain and while loops

TODO — task 7.7.6.

### For loops

TODO — task 7.7.7.

### Exit

TODO — task 7.7.8.

### Goto and labels

TODO — task 7.7.9.

### Blocks

TODO — task 7.7.10.

### Exceptions

TODO — task 7.7.11.

### Return

TODO — task 7.7.12.

### Short-circuit operators

TODO — task 7.7.13.

### Conditional expressions

TODO — task 7.7.14.

### Tasking

TODO — task 7.7.15.

---

## Part 4 — Coverage appendix

TODO — task 7.7.16. Every one of the 405 node kinds in `schema/lal-nodes.json` gets a
verdict here (`shaped`, `leaf`, `opaque`, `structural`, `n/a`), enforced by
`scripts/check_cfg_coverage.py` so that a future grammar addition cannot silently slip
past the CFG.

---

## Part 5 — Recorded limitations

- **Conservative-raise precision.** Because every `CallStmt`/`CallExpr` may complete with
  `RaiseCompletion` (D-013), a paired-call query will report a call pair split by *any*
  intervening call as "not invariably paired" on the exceptional path — unless the pairing
  query ignores raise-completion edges. `MissingPairedCall` therefore exposes both a strict
  variant (all paths) and a `normalPathsOnly` variant (ignore raise edges); the
  `open-without-close` query uses `normalPathsOnly` for v1 signal quality.
- **Exception identities are not matched.** A raise in a protected region has an edge to
  *every* handler of that region, regardless of which exception each handler names.
- **Ada 2022 `QuantifiedExpr` and `DeclExpr`** are treated as opaque post-order
  expressions; their quantifier/declaration sub-structure is not modelled.
- **Tasking is opaque** (D-013): no inter-task edges, no rendezvous modelling.

Limitations that manifest as *specific missing edges* are recorded as `MISSING:`
annotations in the relevant conformance test, not here.

## Wrapper/consumer notes (from `ada.qll`)

- `Name.getText()` (recursive over identifiers/dotted names) and `Name.getReferencedDecl()`
  (via `ada_xref`) are the tools for resolving `ExitStmt` loop names and `GotoStmt` labels
  textually, and for the paired-call target match.
- Named loops/blocks are wrapped: `Outer: loop … end loop Outer;` is a `Raw::NamedStmt`
  (`getDecl()` → `NamedStmtDecl`, `getStmt()` → the `LoopStmt`). An `ExitStmt` naming a
  loop matches the enclosing `BaseLoopStmt` whose `NamedStmtDecl` name text equals
  `getLoopName().getText()`; a nameless `ExitStmt` targets the innermost enclosing
  `BaseLoopStmt`.

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
> | Handled sequence | `HandledStmts`, `ExceptionHandler` | every raise-completing node in the protected region has an edge to *each* handler; if no `when others`, also a raise edge out of the scope; handler bodies continue normally after the sequence |
> | Return | `ReturnStmt` | (value expr →) `return` to scope exit |
> | Extended return | `ExtendedReturnStmt` | elaborate object decl → run optional `HandledStmts` → `return` |
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

Test: [`ql/test/library/Cfg/scopes/`](../ql/test/library/Cfg/scopes/)

**Rule.** Each of the five scope kinds gets its own disconnected graph. Entry flows to the
first node of the scope's body; the last node flows to an `AnnotatedExitNode`
(`(normal)` or `(abnormal)`), and both annotated exits flow to the single exit node.
Nested bodies are separate graphs: the package body below contains four other scopes and
shares no edge with any of them.

```
l1: package body Scopes is
l3:    function Double (X : Integer) return Integer is (X * 2);
l5:    procedure With_Decl is
l6:       Local : Integer := Double (1);
l7:    begin
l8:       null;
l9:    end With_Decl;
l11:   task body Worker is  … l13: null;  l14: end Worker;
l17:      entry Wait when True is  … l19: null;  l20: end Wait;
l23: begin
l24:    null;
l25: end Scopes;

enter PackageBody   -> l24 NullStmt        ; the package's elaboration statements
l24 NullStmt        -> exit PackageBody (normal)
enter ExprFunction  -> l3 X                ; an expression function's body is its expression
l3 (X * 2)          -> exit ExprFunction (normal)
enter SubpBody      -> l8 NullStmt         ; NOTE: l6 is skipped entirely -- see below
enter TaskBody      -> l13 NullStmt
enter EntryBody     -> l19 NullStmt        ; the barrier on l17 is not in the graph
```

An expression function's "body" is `getExpr()`, so `is (X * 2)` yields the `ParenExpr`
chain and no statement nodes at all.

**Limitation — declarative parts are not elaborated (candidate defect C-1).** The
initialiser on l6 calls `Double`, which can raise, yet it produces **no CFG node**: entry
goes straight to l8. `Scopes::CfgScope.getBody()` returns only `getStmts()`, so a
subprogram's, package's or task's declarative part is invisible to the CFG — only
`declare` blocks elaborate their declarations (see [Blocks](#blocks)). This contradicts
the elaboration row of the interim index above and matters to the paired-call query: an
`Open` called in a declaration is not seen. The correct edges are recorded as `MISSING:`
expectations in the test, and the edge that would become wrong as `SPURIOUS:`, so the day
elaboration is implemented the test says so.

The entry barrier of an `EntryBody` (`when True` on l17) is unmodelled for the same
reason.

### If statement

Test: [`ql/test/library/Cfg/if-stmt/`](../ql/test/library/Cfg/if-stmt/)

**Rule.** `IfStmt` is a `PostOrderTree` whose own node is the **join** reached after any
branch. Guard *i*'s condition completes `true` to the first node of guard *i*'s statements
and `false` to the next guard's condition; the last guard's `false` goes to the `else`
statements, or, if there is no `else`, directly to the join. Every branch body completing
normally goes to the join, and the join completes normally to the next statement.

```
l1: if A then
l2:    N := 1;
l3: elsif B then
l4:    N := 2;
l5: else
l6:    N := 3;
l7: end if;
l8: <next statement>

l1 A          -> l2 (1)          ; true  -- first node of the then-statements
l1 A          -> l3 B            ; false -- the next guard's condition
l3 B          -> l4 (2)          ; true
l3 B          -> l6 (3)          ; false -- no further guard, so the else statements
l2 AssignStmt -> l7 IfStmt       ; every branch converges on the join
l4 AssignStmt -> l7 IfStmt
l6 AssignStmt -> l7 IfStmt
l7 IfStmt     -> l8              ; the join completes normally
```

With no `else`, the last `false` edge goes straight to the join:

```
l1: if A then
l2:    N := 4;
l3: end if;

l1 A -> l2 (4)     ; true
l1 A -> l3 IfStmt  ; false -- straight to the join
```

`IfStmtTree.propagatesAbnormal` lists the guard conditions as well as the bodies, so a
condition that can raise gets an `exception` edge:

```
l1: if Check (N) then …

l1 CallExpr -> l2 (5)                  ; true
l1 CallExpr -> l3 IfStmt               ; false
l1 CallExpr -> exit SubpBody (abnormal); exception -- every call may raise (D-013)
```

Contrast this with the case statement below, whose selector does *not* get that edge.

### Case statement

Test: [`ql/test/library/Cfg/case-stmt/`](../ql/test/library/Cfg/case-stmt/)

**Rule.** `CaseStmt` is a `PostOrderTree` whose own node is the join. The selector
expression flows to the first node of **every** alternative's statements, and every
alternative converges on the join.

```
l1: case N is
l2:    when 0 =>
l3:       R := 10;
l4:    when 1 =>
l5:       R := 11;
l6:    when others =>
l7:       R := 12;
l8: end case;
l9: <next statement>

l1 N           -> l3 (10)     ; successor -- to every alternative, not one
l1 N           -> l5 (11)     ; successor
l1 N           -> l7 (12)     ; successor
l3 AssignStmt  -> l8 CaseStmt
l5 AssignStmt  -> l8 CaseStmt
l7 AssignStmt  -> l8 CaseStmt
l8 CaseStmt    -> l9
```

Two things to note. The branch edges are labelled plain `successor`, **not** a
matching-successor per choice: v1 over-approximates by assuming any alternative may be
taken, and the `when` choices themselves (`CaseStmtAlternative`, and the choice
expressions) are structural — consumed by `CaseStmtTree` and never in the graph. (An
earlier draft of this document claimed a `MatchingSuccessor` per choice; that was never
implemented.)

**Limitation — the selector's abnormal completions are dropped (candidate defect C-2).**
`CaseStmtTree.propagatesAbnormal` covers only the alternative bodies, omitting the
selector, so a selector that can raise produces no `exception` edge:

```
l1: case Id (N) is
l2:    when others =>
l3:       R := 20;
l4: end case;

l1 CallExpr -> l3 (20)   ; successor
                         ; MISSING: l1 CallExpr -> exit (abnormal) ; exception
```

The identical call in an `if` condition *does* get the edge — see above. `CaseExprTree`
has the same shape and the same gap. Recorded as a `MISSING:` expectation in the test.

### Plain and while loops

Test: [`ql/test/library/Cfg/loops-basic/`](../ql/test/library/Cfg/loops-basic/)

**Rule.** Both are `PostOrderTree`s whose own node is the point *after* the loop. A
`while` loop enters at its condition: `true` goes to the body, `false` to the loop node,
and the body's normal completion goes back to the condition. A plain `loop` enters at its
body and the body loops back to itself; its node is reachable **only** through an `exit`
(or the enclosing construct), so an exit-less loop is genuinely infinite.

```
l1: while A loop
l2:    N := N + 1;
l3: end loop;
l4: <next statement>

l1 A          -> l2 N              ; true  -- into the body
l1 A          -> l3 WhileLoopStmt  ; false -- to the loop node, i.e. past the loop
l2 AssignStmt -> l1 A              ; back edge, to the condition
l3 WhileLoopStmt -> l4
```

```
l1: loop
l2:    N := N + 1;
l3: end loop;

enter         -> l2 N              ; a plain loop is entered at its body
l2 AssignStmt -> l2 N              ; back edge, to the body's first node
```

Note what is **absent** from the second listing: there is no `LoopStmt` node, because
nothing reaches it, and consequently no `exit SubpBody (normal)` node either — a
subprogram ending in an exit-less loop never completes normally. This is the property the
`FunctionMissingReturn` query relies on, and the conformance test pins it by having no
annotation to write.

### For loops

Test: [`ql/test/library/Cfg/loops-for/`](../ql/test/library/Cfg/loops-for/)

**Rule.** The iteration mechanism is **opaque** (D-013): only the iterable expression is
in the graph. It is evaluated once, and then control may either enter the body or skip the
loop entirely (zero iterations); after each iteration control may either iterate again or
leave. Both the range form and the `of` iterator form have this shape; the loop variable
declaration (`ForLoopSpec.getVarDecl()`) is structural and never a node.

```
l1: for I in 1 .. 3 loop
l2:    N := N + I;
l3: end loop;
l4: <next statement>

l1 1           -> l1 3            ; the iterable is an ordinary expression: 1 .. 3 is a BinOp
l1 3           -> l1 (1 .. 3)
l1 (1 .. 3)    -> l2 N            ; enter the body …
l1 (1 .. 3)    -> l3 ForLoopStmt  ; … or skip the loop entirely (empty range)
l2 AssignStmt  -> l2 N            ; iterate again …
l2 AssignStmt  -> l3 ForLoopStmt  ; … or leave
l3 ForLoopStmt -> l4
```

`for E of V` is identical with `V` as the iterable:

```
l1: for E of V loop

l1 V -> l2 N            ; enter the body
l1 V -> l3 ForLoopStmt  ; or skip
```

Because the loop node is reachable from the iterable directly, a `for` loop — unlike a
plain `loop` — always has a path around it.

### Exit

Test: [`ql/test/library/Cfg/exit/`](../ql/test/library/Cfg/exit/)

**Rule.** An `exit` is a **direct jump edge** labelled `break` from the exit node to the
target loop's own node (the node a `PostOrderTree` loop uses as its join), not a completion
that propagates outward. A bare `exit` targets the innermost enclosing loop; `exit Name`
targets the enclosing loop whose `NamedStmt` declares that name. With a condition, `true`
reaches the exit node and `false` falls through to the next statement. A `NamedStmt`
wrapper is transparent — the loop node is the `LoopStmt` inside it.

```
l1: loop
l2:    exit when A;
l3:    N := N + 1;
l4: end loop;

l2 A        -> l2 ExitStmt  ; true  -- take the exit
l2 A        -> l3 N         ; false -- fall through to the next statement
l2 ExitStmt -> l4 LoopStmt  ; break -- jump to the loop node
l3 AssignStmt -> l2 A       ; back edge
```

Named and nameless exits from nested loops:

```
l1: Outer : loop
l2:    Inner : loop
l3:       exit Outer when B;
l4:       exit Inner;
l5:    end loop Inner;
l6: end loop Outer;

l3 B          -> l3 ExitStmt      ; true
l3 B          -> l4 ExitStmt      ; false -- on to the next statement
l3 ExitStmt   -> l1 LoopStmt      ; break -- the *outer* loop, matched by name
l4 ExitStmt   -> l2 LoopStmt      ; break -- the innermost loop
l5 LoopStmt   -> l3 B             ; leaving Inner continues Outer's body
```

### Goto and labels

Test: [`ql/test/library/Cfg/goto/`](../ql/test/library/Cfg/goto/)

**Rule.** A `goto` is a direct jump edge labelled `goto` from the goto node to its target
`Label`, resolved by name text within the same CFG scope. A `goto` has **no** normal
successor, so statements after an unconditional one are unreachable and appear in no edge
at all. A `Label` is a leaf: control passes through it to the next statement.

```
l1: <<Again>>
l2: N := N + 1;
l3: if A then
l4:    goto Again;
l5: end if;
l6: goto Done;
l7: N := 999;
l8: <<Done>>
l9: null;

enter          -> l1 Label
l1 Label       -> l2 N            ; a label is passed through
l3 A           -> l4 GotoStmt     ; true
l3 A           -> l5 IfStmt       ; false
l4 GotoStmt    -> l1 Label        ; goto -- backward
l5 IfStmt      -> l6 GotoStmt
l6 GotoStmt    -> l8 Label        ; goto -- forward; note there is no successor edge
l8 Label       -> l9 NullStmt
```

`N := 999;` on l7 produces **no nodes whatsoever** — it is unreachable, which is exactly
what `UnreachableStatement` reports. Because the CFG resolves `goto` properly, that query
needs none of the label-based heuristics its pre-CFG version had.

### Blocks

Test: [`ql/test/library/Cfg/blocks/`](../ql/test/library/Cfg/blocks/)

**Rule.** All three block forms are **transparent**: `BeginBlock`, `DeclBlock` and the
`NamedStmt` wrapper have no node of their own, so control flows from the statement before
the block straight into the block's first node, and out of its last node to the statement
after. A `declare` block **elaborates its declarative part first**: each `ObjectDecl`'s
initialiser is evaluated, in declaration order, before the block's statements.

```
l1: begin
l2:    N := 1;
l3: end;
l4:
l5: declare
l6:    Local : Integer := Id (N);
l7: begin
l8:    N := Local;
l9: end;

enter          -> l2 (1)          ; straight into the block, no node for "begin"
l2 AssignStmt  -> l6 Id           ; on to the declare block's *initialiser*
l6 CallExpr    -> l8 Local        ; elaboration done, now the statements
l6 CallExpr    -> exit (abnormal) ; exception -- the initialiser can raise
l8 AssignStmt  -> <after the block>
```

A named block behaves identically; `Named : declare …` adds no node.

Two things this pins down. First, the contrast with [Scopes](#scopes-1): a `declare`
block elaborates its declarations, but a *subprogram's* declarative part does not (C-1) —
the same declaration is in the graph here and absent there. Second, a **named number**
(`K : constant := 3;`) is correctly skipped: it is a `NumberDecl`, not an `ObjectDecl`,
and its value is static, so there is nothing to evaluate. Only `ObjectDecl` initialisers
are elaborated, which leaves the declarative part of a *nested package* inside a block
unmodelled — a genuine but exotic gap.

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

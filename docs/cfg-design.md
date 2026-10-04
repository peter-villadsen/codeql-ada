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

| Scope | Raw class | Body content, in order |
|---|---|---|
| Subprogram | `Raw::SubpBody` | its formals' default values (Task 9.6), then `getDecls()` elaborated, then `getStmts()` |
| Expression function | `Raw::ExprFunction` | `getExpr()` — no declarative part, no statements |
| Task body | `Raw::TaskBody` | `getDecls()` elaborated, then `getStmts()` |
| Entry body | `Raw::EntryBody` | `getBarrier()`, then `getDecls()` elaborated, then `getStmts()` |
| Package body | `Raw::PackageBody` | `getDecls()` elaborated, then `getStmts()` (its elaboration statements, if any) |

Everything except an expression function is sequenced by `BodyTree`, which shares its
elaboration rule with `DeclBlockTree` — see [Scopes](#scopes-1) and [Blocks](#blocks).

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
l7:    Log (Total, N);
l8: end Linear;

enter          -> l5 NullStmt        ; scope entry enters the first statement
l5 NullStmt    -> l6 N               ; next statement, entered at its first node
l6 N           -> l6 1               ; post-order: left operand, then right
l6 1           -> l6 BinOp           ; then the operator node
l6 BinOp       -> l6 Total           ; RHS done, now the assignment target
l6 Total       -> l6 AssignStmt      ; post-order: the statement node last
l6 AssignStmt  -> l7 Log             ; next statement, entered at the callee name
l7 Log         -> l7 Total           ; then the arguments, left to right
l7 Total       -> l7 ParamAssoc(1)   ; post-order through the association wrappers
l7 ParamAssoc(1) -> l7 N             ; on to the second argument
l7 N           -> l7 ParamAssoc(2)
l7 ParamAssoc(2) -> l7 AssocList
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

**Concatenation chains.** Test: [`ql/test/library/Cfg/concat/`](../ql/test/library/Cfg/concat/).
Libadalang parses `A & B & C` as one `ConcatOp`: the first operand, then a
`ConcatOperandList` of `ConcatOperand`s, each wrapping one further operand. The list is
walked like an argument list, so the order is `A`, `B`, `ConcatOperand`, `C`,
`ConcatOperand`, `ConcatOperandList`, `ConcatOp`. (Before Task 9.5 the list was not
descended into, so every operand after the first had no node, was invisible to data flow,
and calls in it were missing from the call graph.)

**Membership tests.** Test: [`ql/test/library/Cfg/membership/`](../ql/test/library/Cfg/membership/).
`X in A | B` is a `MembershipExpr`: the tested expression, then an `ExprAlternativesList`.
The order is `X`, `A`, `B`, `ExprAlternativesList`, `MembershipExpr`. Every alternative is
modelled as evaluated, although Ada stops at the first that matches (RM 4.5.2(27/3)); this
over-approximates which nodes are reached, never under-approximates. (Before this fix the
list was not descended into, the same gap as the `&` chain above.)

**Pragmas among statements.** Test: [`ql/test/library/Cfg/pragmas/`](../ql/test/library/Cfg/pragmas/).
A pragma in a statement list (`pragma Assert (X = 1);`, `pragma Loop_Invariant (...)`) is
a leaf that completes normally, so control passes through it to the next statement. Its
arguments are not evaluated in the graph, so `pragma Assert`'s possible raise is not
modelled. (Before Task 9.6 a pragma had no tree: the chain broke there, and the pragma and
everything after it were unreachable. It caused 1,215 corpus results.)

### Scopes

Test: [`ql/test/library/Cfg/scopes/`](../ql/test/library/Cfg/scopes/)

**Rule.** Each of the five scope kinds gets its own disconnected graph. A body with a
declarative part **elaborates it first** — each object declaration's initialiser is
evaluated, in declaration order — and then runs its statements, exactly as a `declare`
block does. Entry flows to the first node of that sequence; the last node flows to an
`AnnotatedExitNode` (`(normal)` or `(abnormal)`), and both annotated exits flow to the
single exit node. An entry body's barrier is evaluated before anything else, since it is
evaluated before the body is entered. Nested bodies are separate graphs: the package body
below contains four other scopes and shares no edge with any of them.

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
enter SubpBody      -> l6 Double           ; the declarative part is elaborated first
l6 Double(1)        -> l8 NullStmt         ; then the statements
l6 Double(1)        -> exit SubpBody (abnormal) ; exception -- an initialiser can raise
enter TaskBody      -> l13 NullStmt
enter EntryBody     -> l17 True            ; the barrier, evaluated before the body
l17 True            -> l19 NullStmt
```

An expression function's "body" is `getExpr()`, so `is (X * 2)` yields the `ParenExpr`
chain and no statement nodes at all.

Elaboration follows the same rule as a [`declare` block](#blocks) and shares its
implementation: only `ObjectDecl` initialisers are evaluated, so a named number is
correctly skipped, and the declarative part of a *nested package* remains unmodelled.

This was **wrong** until this phase (defect C-1): `Scopes::CfgScope.getBody()` returned
only `getStmts()`, so the initialiser on l6 — a call that can raise — produced no CFG node
at all and entry went straight to l8. Only `declare` blocks elaborated. The consequence
was a graph that silently omitted every expression evaluated during elaboration; in
particular an SSA layer built on it (Phase 9) would have missed the defining assignment of
every initialised local. The conformance test had recorded the correct edges as `MISSING:`
expectations and the edge that had to disappear as `SPURIOUS:`, and implementing
elaboration reported all nine.

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

A selector that can raise propagates that completion, exactly as an `if`'s guard condition
does:

```
l1: case Id (N) is
l2:    when others =>
l3:       R := 20;
l4: end case;

l1 CallExpr -> l3 (20)          ; successor
l1 CallExpr -> exit (abnormal)  ; exception
```

This was **wrong** until this phase: `CaseStmtTree.propagatesAbnormal` covered only the
alternative bodies, omitting the selector, so the `exception` edge was silently absent
while the identical call in an `if` condition produced it. The conformance tests carry
both, so the asymmetry cannot come back unnoticed. `CaseExprTree` had — and has had fixed —
the same gap.

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

**Over a subtype indication.** Test: [`ql/test/library/Cfg/for-subtype/`](../ql/test/library/Cfg/for-subtype/).
In `for I in Natural range 0 .. N`, the iteration part is a `DiscreteSubtypeIndication`,
not an expression. The range expression of its constraint is evaluated, then the
indication node, and the loop continues as above, with the indication in the iterable's
place. (Before Task 9.6 it had no tree, so such a loop had no first node: the loop, its
body and everything after it were unreachable.)

```
l1: for I in Natural range 0 .. N loop

l1 0           -> l1 N
l1 N           -> l1 (0 .. N)
l1 (0 .. N)    -> l1 Natural range 0 .. N
l1 Natural range 0 .. N -> l2 ...         ; enter the body
l1 Natural range 0 .. N -> l3 ForLoopStmt ; or skip
```

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

A **named number** (`K : constant := 3;`) is correctly skipped: it is a `NumberDecl`, not
an `ObjectDecl`, and its value is static, so there is nothing to evaluate. Only
`ObjectDecl` initialisers are elaborated, which leaves the declarative part of a *nested
package* inside a block unmodelled — a genuine but exotic gap.

A block and a body now elaborate by the same rule, sharing one implementation
(`elaboratedInitializer`), so the two cannot drift apart. They did drift once: until this
phase only blocks elaborated, which is defect C-1 in [Scopes](#scopes-1).

### Exceptions

Test: [`ql/test/library/Cfg/exceptions/`](../ql/test/library/Cfg/exceptions/)

**Rule.** Every node in the protected region that can complete with a raise has an
`exception` edge to the **first node of every handler** — v1 does not match exception
identities, so a handler naming `Constraint_Error` is reached from a raise of anything. A
handler body completing normally continues at the statement *after* the handled sequence.
Whether a raise also **escapes** the sequence depends on `when others`: with an `others`
handler nothing escapes; without one, the raise additionally has an edge out of the region
(here, to the scope's abnormal exit).

```
l1: begin
l2:    P;
l3:    raise Constraint_Error;
l4: exception
l5:    when Constraint_Error =>
l6:       N := 1;
l7:    when others =>
l8:       N := 2;
l9: end;
l10: <next statement>

l2 CallStmt  -> l3 Constraint_Error ; successor -- the normal path
l2 CallStmt  -> l6 (1)              ; exception -- to *every* handler …
l2 CallStmt  -> l8 (2)              ; exception -- … including the one it does not name
l3 RaiseStmt -> l6 (1)              ; exception
l3 RaiseStmt -> l8 (2)              ; exception
l6 AssignStmt -> l10                ; a handler body continues after the sequence
l8 AssignStmt -> l10
```

Note the absence of any edge to the scope's abnormal exit: the `when others` handler
catches everything. Remove it and the raise escapes as well as entering the handler:

```
l1: begin
l2:    P;
l3: exception
l4:    when Constraint_Error =>
l5:       N := 3;
l6: end;
l7: <next statement>

l2 CallStmt -> l7                   ; successor
l2 CallStmt -> l5 (3)               ; exception -- into the handler …
l2 CallStmt -> exit (abnormal)      ; exception -- … and out of the scope, no others handler
```

When the regions nest, "escapes" means *to the enclosing handler*, not to the scope exit:
an inner block with no `when others` sends its raise both to its own handler and to the
handlers of the block around it, and only reaches the scope's abnormal exit if no
enclosing region catches it.

```
l1: begin
l2:    begin
l3:       P;
l4:    exception
l5:       when Program_Error =>
l6:          N := 5;
l7:    end;
l8: exception
l9:    when others =>
l10:      N := 6;
l11: end;

l3 CallStmt -> l6 (5)   ; exception -- the inner handler …
l3 CallStmt -> l10 (6)  ; exception -- … and the enclosing one, since the inner
                        ;              region has no `when others`
```

Again there is no edge to the scope's abnormal exit: the outer `when others` stops it.

The exception *name* of a `raise` is evaluated first (post-order), so `raise
Constraint_Error;` is `Constraint_Error` → `RaiseStmt`.

**Calls without parentheses.** Test: [`ql/test/library/Cfg/bare-call/`](../ql/test/library/Cfg/bare-call/).
A name that resolves to a subprogram and is the whole callee (`return Get;`,
`return Id.P_Referenced_Decl;`) is a call and may raise, like a `CallExpr`. A `CallStmt`'s
bare call is already covered by the statement. A name whose callee does not resolve
cannot be told apart from an object and gets no raise edge (Part 5). Before Task 9.6 no
such name raised, so a handler protecting only such calls looked unreachable.

**Calls to `No_Return` subprograms.** Test: [`ql/test/library/Cfg/no-return/`](../ql/test/library/Cfg/no-return/).
A `CallStmt` or `CallExpr` whose callee is marked `No_Return` completes only with a raise,
never normally. The mark can be the aspect (`procedure Fail (Msg : String) with
No_Return;`) or `pragma No_Return (Stop);`, on the callee or on the declaration it
completes. The second case matters because a call inside a package body may resolve to the
body, while the aspect is on the spec. So a function whose last statement is
`Fail ("...")` cannot fall off its end, and a statement after `Stop;` is unreachable. A
call whose callee does not resolve is still assumed to return. (Before Task 9.6
`No_Return` was ignored. It caused 38 of 53 `function-missing-return` corpus results.)

### Return

Test: [`ql/test/library/Cfg/return/`](../ql/test/library/Cfg/return/)

**Rule.** A `return` evaluates its optional value, then the statement node, which completes
with `return` to the scope's **normal** annotated exit — an explicit return and falling off
the end both count as normal, and are told apart by the edge label. An extended return
elaborates its object declaration, runs its optional `do … end return` statements, and then
completes with `return`.

```
l1: if A then
l2:    return 1;
l3: end if;
l4: return N;

l2 (1)         -> l2 ReturnStmt        ; the value is evaluated first
l2 ReturnStmt  -> exit (normal)        ; return
l4 N           -> l4 ReturnStmt
l4 ReturnStmt  -> exit (normal)        ; return
```

A bare `return;` from a procedure has no value to evaluate, so the statement node is itself
the first node of the statement:

```
l1: if A then
l2:    return;

l1 A          -> l2 ReturnStmt ; true -- straight to the return node
l2 ReturnStmt -> exit (normal) ; return
```

Extended return:

```
l1: return R : Integer := N do
l2:    R := R + 1;
l3: end return;

l1 N                    -> l2 R                   ; elaborate the declaration first
l2 AssignStmt           -> l1 ExtendedReturnStmt  ; then the do-block statements
l1 ExtendedReturnStmt   -> exit (normal)          ; return
```

### Short-circuit operators

Test: [`ql/test/library/Cfg/short-circuit/`](../ql/test/library/Cfg/short-circuit/)

**Rule.** The **left** operand of `and then` / `or else` is in a Boolean context and
completes `true`/`false`; one of those two values skips the right operand and goes straight
to the operator node. The right operand is *not* in a Boolean context — it completes
`successor` into the operator node. The operator node then completes according to its own
context (here, `true`/`false` because it is an `if` condition). Plain `and` / `or` evaluate
both operands unconditionally.

```
l1: if A and then B then
l2:    N := 1;
l3: end if;

l1 A     -> l1 B         ; true  -- the value is not yet decided, evaluate the right operand
l1 A     -> l1 BinOp     ; false -- short-circuit
l1 B     -> l1 BinOp     ; successor
l1 BinOp -> l2 (1)       ; true
l1 BinOp -> l3 IfStmt    ; false
```

`or else` is the mirror image — `true` short-circuits and `false` evaluates the right
operand. Plain `and` has no Boolean edges out of its left operand at all:

```
l1: if A and B then

l1 A -> l1 B  ; successor -- both operands are always evaluated
```

Nesting works as expected; a parenthesised inner short-circuit completes `successor` into
its `ParenExpr` because a right operand is not a Boolean context:

```
l1: if A and then (B or else C) then

l1 A         -> l1 B             ; true
l1 A         -> l1 BinOp(outer)  ; false
l1 B         -> l1 BinOp(inner)  ; true  -- short-circuit the or else
l1 B         -> l1 C             ; false
l1 C         -> l1 BinOp(inner)  ; successor
l1 BinOp(inner) -> l1 ParenExpr  ; successor
l1 ParenExpr -> l1 BinOp(outer)  ; successor
```

Because the framework is instantiated **without splitting**, the operator node emits both
`true` and `false` regardless of which path reached it. This is sound but imprecise: the
graph admits `A` false followed by the `true` branch. See the note on `Make` in Part 1.

### Conditional expressions

Test: [`ql/test/library/Cfg/cond-expr/`](../ql/test/library/Cfg/cond-expr/)

**Rule.** `IfExpr` and `CaseExpr` have exactly the branch shape of their statement forms —
guard conditions completing `true`/`false`, alternatives reached by plain `successor` —
except that each arm produces a value converging on the expression node, which then
continues as an ordinary sub-expression.

```
l1: N := (if A then 1 elsif B then 2 else 3);

l1 A         -> l1 (1)        ; true
l1 A         -> l1 B          ; false
l1 B         -> l1 (2)        ; true
l1 B         -> l1 (3)        ; false
l1 (1)       -> l1 IfExpr     ; every arm converges on the expression node
l1 (2)       -> l1 IfExpr
l1 (3)       -> l1 IfExpr
l1 IfExpr    -> l1 ParenExpr  ; and then evaluation continues normally
l1 ParenExpr -> l1 N          ; the assignment's LHS, RHS having been evaluated
l1 N         -> l1 AssignStmt
```

```
l1: N := (case N is when 0 => 10, when others => 20);

l1 N       -> l1 (10)      ; successor -- to every arm, as in a case statement
l1 N       -> l1 (20)      ; successor
l1 (10)    -> l1 CaseExpr
l1 (20)    -> l1 CaseExpr
```

### Tasking

Test: [`ql/test/library/Cfg/tasking/`](../ql/test/library/Cfg/tasking/)

**Rule.** Tasking constructs are **opaque** (D-013): there are no inter-task edges and no
rendezvous modelling, but every statement must still appear in the graph. A `select` is a
`PostOrderTree` shaped like a `case`: control may enter *any* branch — each guarded
alternative's statements, the `else` part, and the abortable part of `select … then
abort` — and every branch converges on the select node. `accept … do … end` is transparent
to its statements; a plain `accept E;`, a `delay`, an `abort` and a `requeue` are opaque
leaves that complete normally.

```
l1: select
l2:    accept E do
l3:       null;
l4:    end E;
l5: or
l6:    accept F;
l7: else
l8:    null;
l9: end select;
l10: <next statement>

enter          -> l3 NullStmt   ; any branch may be entered …
enter          -> l6 AcceptStmt
enter          -> l8 NullStmt
l3 NullStmt    -> l1 SelectStmt ; … and all converge on the select node
l6 AcceptStmt  -> l1 SelectStmt
l8 NullStmt    -> l1 SelectStmt
l1 SelectStmt  -> l10
```

`accept E do … end` contributes no node of its own — only its inner statements — whereas
the plain `accept F;` is itself a leaf node.

```
l1: select
l2:    delay 1.0;
l3: then abort
l4:    null;
l5: end select;

<before> -> l2 DelayStmt  ; the triggering alternative …
<before> -> l4 NullStmt   ; … and the abortable part are both reachable
l2 DelayStmt -> l1 SelectStmt
l4 NullStmt  -> l1 SelectStmt
```

Both branch shapes above were **wrong** until this phase. A plain `accept E;` was matched
by no control-flow tree at all (`OpaqueStmtTree` excluded all of `Raw::AcceptStmt` while
`AcceptStmtTree` covered only `AcceptStmtWithStmts`), and `SelectStmtTree` never read
`getThenAbortPart()`. Both constructs therefore had no CFG nodes, and
`ada/unreachable-statement` reported them as unreachable — two confirmed false positives,
now fixed and pinned by this test.

---

## Part 4 — Coverage appendix

Every node kind in `schema/lal-nodes.json` carries an explicit verdict saying how the CFG
treats it, so that a future grammar addition cannot silently slip past the graph (D-016).

<!-- BEGIN GENERATED COVERAGE -->

All **405** node kinds in `schema/lal-nodes.json` are accounted for below. This section is generated by
`scripts/check_cfg_coverage.py`, which derives each verdict from `ControlFlowGraphImpl.qll`;
edit the implementation, then re-run it with `--write`. CI runs it without `--write` and fails
if a node kind is unaccounted for or the text below has drifted.

### scope (5)

A CFG scope: gets its own disconnected graph with an entry and an exit. See Part 1, Scopes.

`EntryBody`, `ExprFunction`, `PackageBody`, `SubpBody`, `TaskBody`

### shaped (27)

Has a dedicated control-flow tree: its successor structure is specified in Part 3 and pinned by a conformance test.

`AcceptStmtWithStmts`, `AssignStmt`, `BeginBlock`, `BinOp`, `CallExpr`, `CallStmt`, `CaseExpr`, `CaseStmt`, `DeclBlock`, `ExitStmt`, `ExtendedReturnStmt`, `ForLoopStmt`, `GotoStmt`, `HandledStmts`, `IfExpr`, `IfStmt`, `Label`, `LoopStmt`, `NamedStmt`, `NullStmt`, `PragmaNode`, `RaiseStmt`, `ReturnStmt`, `SelectStmt`, `StmtList`, `SubtypeIndication`, `WhileLoopStmt`

### expression (43)

Reached by `GenericPostOrderTree`: children are evaluated left to right, then the node itself. No construct-specific shape.

`AbstractStateDeclExpr`, `Aggregate`, `AggregateAssoc`, `Allocator`, `ArraySubcomponentChoiceName`, `AssocList`, `AttributeRef`, `BoxExpr`, `BracketAggregate`, `BracketDeltaAggregate`, `CharLiteral`, `CompositeConstraintAssoc`, `ConcatOp`, `ConcatOperand`, `DeclExpr`, `DefiningName`, `DeltaAggregate`, `DiscreteSubtypeName`, `DottedName`, `EndName`, `ExplicitDeref`, `FormatStringLiteral`, `Identifier`, `IntLiteral`, `IteratedAssoc`, `MembershipExpr`, `MultiDimArrayAssoc`, `NullLiteral`, `NullRecordAggregate`, `ParamAssoc`, `ParenExpr`, `QualExpr`, `QuantifiedExpr`, `RaiseExpr`, `RealLiteral`, `ReduceAttributeRef`, `RelationOp`, `StringLiteral`, `SyntheticDefiningName`, `SyntheticIdentifier`, `TargetName`, `UnOp`, `UpdateAttributeRef`

### opaque (7)

A statement with no dedicated tree, so `OpaqueStmtTree` makes it a leaf that completes normally. It is in the graph; its internals are not modelled (D-013).

`AbortStmt`, `AcceptStmt`, `DelayStmt`, `ErrorStmt`, `RequeueStmt`, `SimpleDeclStmt`, `TerminateAlternative`

### structural (20)

Read by the CFG but never becoming a node: its owning construct's tree consumes it directly. Making these nodes would leak spurious reachable elements into the graph -- see Part 1.

`CaseExprAlternative`, `CaseStmtAlternative`, `ConcatOperandList`, `DeclarativePart`, `ElsePart`, `ElsifExprPart`, `ElsifStmtPart`, `ExceptionHandler`, `ExprAlternativesList`, `ExtendedReturnStmtObjectDecl`, `ForLoopSpec`, `LabelDecl`, `NamedStmtDecl`, `ObjectDecl`, `OthersDesignator`, `ParamSpec`, `RangeConstraint`, `SelectWhenPart`, `ThenAbortPart`, `WhileLoopSpec`

### n/a (303)

Not control-relevant: nothing here is executed, so nothing is in the graph.

**operators** (24) — Operator tokens. An operator is not itself executed -- its operands are, and the enclosing `BinOp`/`UnOp` node represents applying it. `exprLike` excludes `Raw::Op` for exactly this reason.

`OpAbs`, `OpAnd`, `OpAndThen`, `OpConcat`, `OpDiv`, `OpDoubleDot`, `OpEq`, `OpGt`, `OpGte`, `OpIn`, `OpLt`, `OpLte`, `OpMinus`, `OpMod`, `OpMult`, `OpNeq`, `OpNot`, `OpNotIn`, `OpOr`, `OpOrElse`, `OpPlus`, `OpPow`, `OpRem`, `OpXor`

**presence markers** (28) — Generated `...Absent`/`...Present` pairs recording whether an optional keyword (`abstract`, `limited`, `overriding`, …) was written. Pure syntax.

`AbortAbsent`, `AbortPresent`, `AbstractAbsent`, `AbstractPresent`, `AliasedAbsent`, `AliasedPresent`, `AllAbsent`, `AllPresent`, `ConstantAbsent`, `ConstantPresent`, `LimitedAbsent`, `LimitedPresent`, `NotNullAbsent`, `NotNullPresent`, `PrivateAbsent`, `PrivatePresent`, `ProtectedAbsent`, `ProtectedPresent`, `ReverseAbsent`, `ReversePresent`, `SynchronizedAbsent`, `SynchronizedPresent`, `TaggedAbsent`, `TaggedPresent`, `UntilAbsent`, `UntilPresent`, `WithPrivateAbsent`, `WithPrivatePresent`

**type definitions and constraints** (36) — The static type system: type definitions, subtype indications, constraints, ranges used as type bounds. Elaborating a type declaration can in principle run code (a dynamic bound, say), which the CFG does not model -- a documented limitation.

`AccessToSubpDef`, `AnonymousTypeAccessDef`, `AnonymousTypeDecl`, `ArrayTypeDef`, `ClasswideTypeDecl`, `ComponentDef`, `CompositeConstraint`, `ConcreteTypeDecl`, `DecimalFixedPointDef`, `DeltaConstraint`, `DerivedTypeDef`, `DigitsConstraint`, `DiscreteBaseSubtypeDecl`, `EnumTypeDef`, `FloatingPointDef`, `FormalDiscreteTypeDef`, `FormalTypeDecl`, `IncompleteFormalTypeDecl`, `IncompleteTaggedTypeDecl`, `IncompleteTypeDecl`, `InterfaceTypeDef`, `ModIntTypeDef`, `NullRecordDef`, `OrdinaryFixedPointDef`, `PrivateTypeDef`, `ProtectedDef`, `ProtectedTypeDecl`, `RecordDef`, `RecordTypeDef`, `SignedIntTypeDef`, `SingleTaskTypeDecl`, `SubtypeDecl`, `SynthAnonymousTypeDecl`, `TaskDef`, `TaskTypeDecl`, `TypeAccessDef`

**declarations** (45) — Declarations other than the object declarations whose initialisers are elaborated in a `declare` block or a body. The declarative part of a nested *package* is still not elaborated -- see Blocks.

`AbstractFormalSubpDecl`, `AbstractStateDecl`, `AbstractSubpDecl`, `AcceptStmtBody`, `AnonymousExprDecl`, `AssertionLevelDecl`, `ComponentDecl`, `ConcreteFormalSubpDecl`, `DiscriminantSpec`, `EntryDecl`, `EntryIndexSpec`, `EnumLiteralDecl`, `ErrorDecl`, `ExceptionDecl`, `ForLoopVarDecl`, `GenericFormalObjDecl`, `GenericFormalPackage`, `GenericFormalSubpDecl`, `GenericFormalTypeDecl`, `GenericPackageDecl`, `GenericPackageInstantiation`, `GenericPackageInternal`, `GenericPackageRenamingDecl`, `GenericSubpDecl`, `GenericSubpInstantiation`, `GenericSubpInternal`, `GenericSubpRenamingDecl`, `NoTypeObjectRenamingDecl`, `NullSubpDecl`, `NumberDecl`, `PackageBodyStub`, `PackageDecl`, `PackageRenamingDecl`, `ProtectedBody`, `ProtectedBodyStub`, `SingleProtectedDecl`, `SingleTaskDecl`, `SubpBodyStub`, `SubpDecl`, `SubpRenamingDecl`, `SyntheticCharEnumLit`, `SyntheticFormalParamDecl`, `SyntheticObjectDecl`, `SyntheticSubpDecl`, `TaskBodyStub`

**lists** (24) — List wrappers whose elements the owning construct reads directly. `StmtList` and `AssocList` are the exceptions and appear above.

`AbstractStateDeclList`, `AdaNodeList`, `AlternativesList`, `AspectAssocList`, `BaseAssocList`, `CaseExprAlternativeList`, `CaseStmtAlternativeList`, `CompilationUnitList`, `ConstraintList`, `DeclList`, `DefiningNameList`, `DiscriminantChoiceList`, `DiscriminantSpecList`, `ElsifExprPartList`, `ElsifStmtPartList`, `EnumLiteralDeclList`, `FormatStringChunkList`, `NameList`, `ParamSpecList`, `ParentList`, `PragmaNodeList`, `SelectWhenPartList`, `UnconstrainedArrayIndexList`, `VariantList`

**abstract base classes** (72) — Not instantiable: no node in a database has this kind.

`AbortNode`, `AbstractNode`, `AccessDef`, `AdaList`, `AdaNode`, `AliasedNode`, `AllNode`, `ArrayIndices`, `AspectClause`, `BaseAggregate`, `BaseAssoc`, `BaseFormalParamDecl`, `BaseFormalParamHolder`, `BaseId`, `BaseLoopStmt`, `BasePackageDecl`, `BaseRecordDef`, `BaseSubpBody`, `BaseSubpSpec`, `BaseSubtypeDecl`, `BaseTypeAccessDef`, `BaseTypeDecl`, `BasicAssoc`, `BasicAssocList`, `BasicDecl`, `BasicSubpDecl`, `BlockStmt`, `BodyNode`, `BodyStub`, `ClassicSubpDecl`, `CompositeStmt`, `CondExpr`, `ConstantNode`, `Constraint`, `DiscriminantPart`, `Expr`, `ExprList`, `FormalSubpDecl`, `FormatStringTokNode`, `GenericDecl`, `GenericFormal`, `GenericInstantiation`, `GenericRenamingDecl`, `IdentifierList`, `InterfaceKind`, `IterType`, `LimitedNode`, `LoopSpec`, `Mode`, `Name`, `NotNull`, `NumLiteral`, `Op`, `OverridingNode`, `PpDirective`, `PrivateNode`, `ProtectedNode`, `Quantifier`, `RealTypeDef`, `ReverseNode`, `SimpleStmt`, `SingleTokNode`, `Stmt`, `SubpKind`, `SynchronizedNode`, `TaggedNode`, `TypeDecl`, `TypeDef`, `TypeExpr`, `UntilNode`, `UseClause`, `WithPrivate`

**other syntax** (74) — Compilation units, with/use clauses, aspects, pragmas, defining names, designators and similar structure that carries no control flow.

`AnonymousType`, `AspectAssoc`, `AspectSpec`, `AtClause`, `AttributeDefClause`, `CompilationUnit`, `ComponentClause`, `ComponentList`, `ConstrainedArrayIndices`, `ConstrainedSubtypeIndication`, `DiscreteSubtypeIndication`, `EntryCompletionFormalParams`, `EntrySpec`, `EnumLitSynthTypeExpr`, `EnumRepClause`, `EnumSubpSpec`, `FinallyPart`, `ForLoopIterFilter`, `FormatStringChunk`, `FormatStringTokEnd`, `FormatStringTokMid`, `FormatStringTokStart`, `FormatStringTokString`, `GenericFormalPart`, `InterfaceKindLimited`, `InterfaceKindProtected`, `InterfaceKindSynchronized`, `InterfaceKindTask`, `IterTypeIn`, `IterTypeOf`, `KnownDiscriminantPart`, `LibraryItem`, `ModeDefault`, `ModeIn`, `ModeInOut`, `ModeOut`, `MultiAbstractStateDecl`, `NullComponentDecl`, `OverridingNotOverriding`, `OverridingOverriding`, `OverridingUnspecified`, `Params`, `ParenAbstractStateDecl`, `PpElseDirective`, `PpElsifDirective`, `PpEndIfDirective`, `PpIfDirective`, `PpThenKw`, `PragmaArgumentAssoc`, `PrivatePart`, `PublicPart`, `QuantifierAll`, `QuantifierSome`, `RangeSpec`, `RecordRepClause`, `RenamingClause`, `SubpKindFunction`, `SubpKindProcedure`, `SubpSpec`, `Subunit`, `SyntheticBinarySpec`, `SyntheticRenamingClause`, `SyntheticTypeExpr`, `SyntheticUnarySpec`, `TypeAttributesRepository`, `UnconstrainedArrayIndex`, `UnconstrainedArrayIndices`, `UnknownDiscriminantPart`, `UsePackageClause`, `UseTypeClause`, `ValueSequence`, `Variant`, `VariantPart`, `WithClause`

<!-- END GENERATED COVERAGE -->

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
- **An unresolved call without parentheses does not raise.** A name like
  `Id.P_Referenced_Decl` whose callee does not resolve cannot be told apart from an object,
  so it gets no raise edge, and a handler protecting only such calls looks unreachable
  (Task 9.6, limitation I; resolved calls without parentheses do raise, see
  [Exceptions](#exceptions)).

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

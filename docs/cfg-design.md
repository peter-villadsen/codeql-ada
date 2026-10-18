# CFG specification — construct → successor structure

This is the specification of the Ada control-flow graph built by
`ql/lib/codeql/ada/controlflow/internal/ControlFlowGraphImpl.qll` on the shared
`codeql.controlflow.ControlFlowGraph` library (D-029, which replaced D-013's
`codeql.controlflow.Cfg` in 0.4.0; see `docs/cfg-migration-plan.md`). For every
control-relevant construct it gives an Ada snippet and the edges that snippet produces,
so the graph can be checked by hand. Every construct section is backed by a conformance
test under `ql/test/library/Cfg/<family>/` whose `test.adb` carries the graph's edges as
machine-checked inline annotations (D-017); the tests are the enforcement, this document
is the rule they enforce.

Every `Raw::` class and accessor named here was verified against
`ql/lib/codeql/ada/ast/internal/Raw.qll` (the generated Raw layer, pinned dbscheme — the
CFG is pure QL and does **not** change the dbscheme).

The public API is `codeql.ada.controlflow.ControlFlowGraph` (`ControlFlowNode`,
`ControlFlow::EntryNode`, `BasicBlock`, …), with the names CodeQL for Java uses.

---

## Part 1 — How the graph is built

### The library instantiation

The shared library builds the graph from a description of the AST, in three stages, as
for Java and C#: `Make0<Location, Ast>`, then `Make1<Input>` and `Make2<Input>`.

- **`Ast` implements `AstSig`.** `AstNode = Raw::AdaNode`. `getChild(n, i)` lists the
  children of `n` that are *evaluated*, in order. Abrupt completions (raise, return, exit,
  goto) propagate outward along `getChild` until a construct catches them, so it also
  includes the structural nodes between a statement and its body (statement lists,
  handled sequences). The Ada constructs that match one of the library's (`while`,
  `for … in/of`, `return`, `raise`, handlers and `finally`, `case`, `and then`/`or else`,
  `goto`, unconditional `exit`) are classified as such. The others (`if … elsif`, plain
  `loop`, `exit when`, `select`) are ordinary nodes with their own steps.
- **`Input` implements `InputSig1` and `InputSig2`.** It gives the jump labels
  (`TLoopLabel`, `TStmtLabel`), the body parts of a callable, which handler catches
  everything (`when others`), which `case` alternative matches what is left (the last:
  Ada `case` is exhaustive), the conditions, the nodes ordered after their parts
  (`postOrInOrder`), which nodes may raise (`beginAbruptCompletion`), and the steps of
  the constructs the library doesn't know (`step`).

A node with an explicit step out of its "before" node gets no default left-to-right
steps. That is how an Ada construct takes over its own control flow, the way Java's
instantiation does for Kotlin's `when`.

### The nodes

Every AST node in the graph has **one node that represents it** (`injects`, rendered
with no prefix in annotations):

- for an expression with operands, a call, an assignment, a call statement, `return`,
  `raise`, `goto` and `exit when`, a node **after** its parts (where the value, the call
  or the jump has happened; SSA writes an assignment's target there);
- for every other statement, `if` expressions, short-circuit operators and leaves, the
  node **before** it.

Most AST nodes also have a **before** node and an **after** node. A leaf that is not a
condition has just one, which is both. A node in a conditional context has one *after*
node per value, tagged `after-true`/`after-false`: a condition's two values, and also an
iterable's emptiness (`after-true` = empty) and a `case` choice's or a handler's match
(`after-true` = match).
Additional nodes carry a tag: `[LoopHeader]` for each loop, and `[select i]`/`[skip i]`
for the choice between a `select`'s alternatives. Only nodes reachable from the entry
are `ControlFlowNode`s.

### Three patterns that shape everything below

- **`getChild` follows evaluation, not syntax.** Operators (`Raw::Op`) are not nodes. A
  declaration is not a node either, but its initialiser is. Nor are a `for` loop's spec
  and a `while` loop's spec, whose parts are the loop's children. A defining name is a
  leaf; so is a `case` choice, which is matched but not evaluated (Ada choices are static,
  so they cannot raise). A pragma's arguments are not evaluated. What is left of an
  expression is evaluated left to right.
- **Conditions branch from their "after" nodes.** The `true` and `false` edges come out
  of a condition into its `after-true`/`after-false` nodes, which step to the branch.
  The value of an `and then`/`or else` comes from its operands, so `A` false in
  `A and then B` goes straight to `after-false` of the whole: no path joins the two
  values and splits them again.
- **Jumps carry their resolved target.** An `exit` is labelled with the loop it leaves and
  a `goto` with the label statement it goes to (`exitTargetLoop`, `gotoTargetLabel`).
  The completion propagates out along `getChild`, through every `finally` part it leaves,
  and is caught by that loop, or by the statement list that holds that label. A `case`
  statement never catches an `exit`.

### Scopes

Each `CfgScope` (the library's `Callable`) gets its own graph: an entry node; the
**normal exit** (`ControlFlow::NormalExitNode`, reached when the body completes or by
`return`); the **exceptional exit** (`ControlFlow::ExceptionalExitNode`, reached by an
exception nothing catches); both step to the single `ControlFlow::ExitNode`. Nested
bodies are their **own** scopes — a nested `SubpBody`'s statements are NOT part of the
enclosing body's graph.

| Scope | Raw class | Body parts, in order |
|---|---|---|
| Subprogram | `Raw::SubpBody` | its formals' default values (Task 9.6), then the initialisers of `getDecls()`, then `getStmts()` |
| Expression function | `Raw::ExprFunction` | `getExpr()` — no declarative part, no statements |
| Task body | `Raw::TaskBody` | the initialisers of `getDecls()`, then `getStmts()` |
| Entry body | `Raw::EntryBody` | `getBarrier()`, then the initialisers of `getDecls()`, then `getStmts()` |
| Package body | `Raw::PackageBody` | the initialisers of `getDecls()`, then `getStmts()` (its elaboration statements, if any) |

The parts are the library's `callableGetBodyPart` (D-031); a `declare` block elaborates
its declarative part the same way, as its first children ([Blocks](#blocks)).

### Edge labels

| Label | Successor type | Out of |
|---|---|---|
| `successor` | `DirectSuccessor` | every node completing normally |
| `true` / `false` | `BooleanSuccessor` | a condition, into its `after-true`/`after-false` node; the `[select i]`/`[skip i]` choice |
| `empty` / `non-empty` | `EmptinessSuccessor` | a `for` loop's iterable |
| `match` / `no-match` | `MatchingSuccessor` | a `case` choice, a `case` alternative, an exception handler |
| `return` | `ReturnSuccessor` | `return`, extended `return` |
| `exception` | `ExceptionSuccessor` | `raise`, and every call (it may raise; a `No_Return` call can only raise) |
| `break` | `BreakSuccessor` | `exit` (labelled with its loop) |
| `goto` | `GotoSuccessor` | `goto` (labelled with its label) |

A call node has both a `successor` and an `exception` edge; everything else is exclusive.

---

## Part 2 — How to read a construct section

Each section states the rule in one sentence, shows a numbered snippet, and lists what
runs after what:

```
l1: if (expr)
l2:    stmt
l3:

l1 -> l2 ; expression is true
l1 -> l3 ; expression is false
l2 -> l3
```

The listings name the **node that represents** each AST node (`<QlClass>@<line>:<column>`,
or just the class where the line is clear) and leave out the before/after nodes between
two of them; `after IfStmt` names the point after a statement whose own node is at its
start. The annotations in the test carry every node. The exits render as
`exitSubpBody(normal)` / `exitSubpBody(abnormal)`, both feeding `exitSubpBody`.

### The conformance tests

Each section links its test directory. A test is `test.adb` (annotated), `test.ql` (a
one-line `import library.Cfg.CfgConformance`) and an **empty** `test.expected`. The
annotation syntax is

```
-- $ edge=<predecessor>|<label>|<successor>
```

where a node is `<kind>@<line>:<column>` (`ql/lib/codeql/ada/test/CfgAnnotations.qll`):
`AssignStmt@25:7` for the node that represents an AST node, `before:IfStmt@12:4`,
`after:IfStmt@12:4`, `after-true:Identifier@12:7`, `add.[LoopHeader]:LoopStmt@9:4` for
the others, `enterSubpBody@1:1` and `exitSubpBody(normal)@1:1` for the scope's. The check
is exhaustive in both directions: an unannotated edge fails with "Unexpected result", an
annotation with no edge fails with "Missing result".

**The annotation goes on the line where the predecessor node *ends*** — the framework
matches a comment's start line against the result location's end line. Every node of an
`IfStmt` spanning lines 5–11 (before, after) is annotated on line 11 (`end if;`); for the
single-line nodes that make up most of a graph the distinction does not arise. A scope's
entry and exit nodes span the whole body, so their edges are annotated on the body's last
line.

Deliberate imprecisions are written as `$ MISSING: edge=…` rather than described in prose
(D-019), so the framework reports "Fixed missing result" the day one is fixed.

### Workflow when adding or changing a construct

1. Write the rule and the edge listing in this document **first**, derived from
   `getChild` and the construct's steps.
2. Write the minimal `test.adb`.
3. Run `scripts/annotate_cfg_test.py <dir>`, `ql/debug/CfgAnnotations.ql` or just the
   test (the "Unexpected result" lines carry the same values) to see the actual graph.
   `ql/debug/CfgConsistency.ql` runs the library's own consistency checks.
4. Compare with step 1. If they differ, decide which is wrong and say so in the commit
   message. **Never** paste the tool's output over a rule it contradicts — that turns the
   conformance test into a tautology.
5. Transcribe, run, commit.

---

## Part 3 — Construct specifications


### Linear code

Test: [`ql/test/library/Cfg/linear/`](../ql/test/library/Cfg/linear/)

**Rule.** Statements in a `StmtList` run in order, each flowing to the next one's
"before" node. Expressions are evaluated children first, left to right, then the node
itself. An assignment evaluates its **right-hand side before its left-hand side**, then
its own node. A call evaluates the callee name, then the argument list, then the call
node — which additionally completes `exception`, per the conservative raise model.

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
l5 NullStmt    -> l6 N               ; next statement, then its right-hand side first
l6 N           -> l6 1               ; left operand, then right
l6 1           -> l6 BinOp           ; then the operator node
l6 BinOp       -> l6 Total           ; RHS done, now the assignment target
l6 Total       -> l6 AssignStmt      ; the assignment's node follows its parts
l6 AssignStmt  -> l7 Log             ; next statement, entered at the callee name
l7 Log         -> l7 Total           ; then the arguments, left to right
l7 Total       -> l7 ParamAssoc(1)   ; through the association wrappers
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

**Rule.** Each of the five scope kinds gets its own graph. A body with a declarative part
**elaborates it first** — each object declaration's initialiser is evaluated, in
declaration order — and then runs its statements, exactly as a `declare` block does: these
are the body's parts, in order. Entry flows to the first of them; the last completing
normally flows to the normal exit, an uncaught exception to the exceptional exit, and both
flow to the single exit node. An entry body's barrier is evaluated before anything else,
since it is evaluated before the body is entered. Nested bodies are separate graphs: the
package body below contains four other scopes and shares no edge with any of them.

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

An expression function's body is `getExpr()`, so `is (X * 2)` yields the `ParenExpr`
chain and no statement nodes at all.

Elaboration follows the same rule as a [`declare` block](#blocks) and shares its
implementation (`elaboratedInitializer`): only `ObjectDecl` initialisers are evaluated,
so a named number is correctly skipped, and the declarative part of a *nested package*
remains unmodelled.

This was **wrong** until Phase 7.7 (defect C-1): the body was only its statements, so the
initialiser on l6 — a call that can raise — produced no CFG node at all and entry went
straight to l8. Only `declare` blocks elaborated. The consequence was a graph that
silently omitted every expression evaluated during elaboration; in particular an SSA layer
built on it (Phase 9) would have missed the defining assignment of every initialised
local.

### If statement

Test: [`ql/test/library/Cfg/if-stmt/`](../ql/test/library/Cfg/if-stmt/)

**Rule.** An `if` statement's node is at its start, and control goes straight to its first
condition. Guard *i*'s condition is `true` into guard *i*'s statements and `false` into the
next guard's condition (through its `ElsifStmtPart`); the last guard's `false` goes to the
`else` statements, or, if there is no `else`, to the point after the `if`. Every branch
completing normally goes to the point after the `if`, and from there to the next
statement. These are the statement's own steps (D-032), guard by guard, as Java's are for
Kotlin's `when`.

```
l1: if A then
l2:    N := 1;
l3: elsif B then
l4:    N := 2;
l5: else
l6:    N := 3;
l7: end if;
l8: <next statement>

l1 IfStmt     -> l1 A            ; the if's node is at its start
l1 A          -> l2 (1)          ; true  -- into the then-statements
l1 A          -> l3 B            ; false -- the next guard's condition
l3 B          -> l4 (2)          ; true
l3 B          -> l6 (3)          ; false -- no further guard, so the else statements
l2 AssignStmt -> after IfStmt    ; every branch converges after the if
l4 AssignStmt -> after IfStmt
l6 AssignStmt -> after IfStmt
after IfStmt  -> l8
```

With no `else`, the last `false` edge goes straight to the point after the `if`:

```
l1: if A then
l2:    N := 4;
l3: end if;

l1 A -> l2 (4)        ; true
l1 A -> after IfStmt  ; false
```

A condition that can raise gets an `exception` edge:

```
l1: if Check (N) then …

l1 CallExpr -> l2 (5)                  ; true
l1 CallExpr -> after IfStmt            ; false
l1 CallExpr -> exit SubpBody (abnormal); exception -- every call may raise (D-013)
```

The `case` statement's selector does the same.

### Case statement

Test: [`ql/test/library/Cfg/case-stmt/`](../ql/test/library/Cfg/case-stmt/)

**Rule.** A `case` statement is the library's `Switch`: the selector is evaluated, then
the alternatives are tested in order, each by its choices (`match` into the alternative's
statements, `no-match` on to the next choice or alternative). A choice is matched but not
evaluated: Ada requires choices to be static, so a choice is a leaf that cannot raise.
**The last alternative matches whatever is left** (`matchAll`), since Ada's `case` covers
every value; `when others` likewise. Every alternative converges after the `case`.

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

l1 CaseStmt    -> l1 N
l1 N           -> l2 0             ; the first alternative's choice
l2 0           -> l3 (10)          ; match
l2 0           -> l4 1             ; no-match -- the next alternative
l4 1           -> l5 (11)          ; match
l4 1           -> l6 others        ; no-match
l6 others      -> l7 (12)          ; match -- the only way out of `others`
l3 AssignStmt  -> after CaseStmt
l5 AssignStmt  -> after CaseStmt
l7 AssignStmt  -> after CaseStmt
after CaseStmt -> l9
```

The alternatives are told apart by their choices only as far as matching order goes: no
value is compared (so `when 0` is not known to exclude `when 1`), and every alternative
is reachable.

A selector that can raise gets an `exception` edge, exactly as an `if`'s condition does:

```
l1: case Id (N) is
l2:    when others =>
l3:       R := 20;
l4: end case;

l1 CallExpr -> l2 others        ; successor
l1 CallExpr -> exit (abnormal)  ; exception
```

This was **wrong** until Phase 7.7 (defect C-2): the selector was not among the parts an
abrupt completion propagated out of, so the `exception` edge was silently absent while the
identical call in an `if` condition produced it. The conformance tests carry both, so the
asymmetry cannot come back unnoticed. The `case` expression had the same gap.

### Plain and while loops

Test: [`ql/test/library/Cfg/loops-basic/`](../ql/test/library/Cfg/loops-basic/)

**Rule.** Every loop has a `[LoopHeader]` node, where each iteration starts. A `while` loop
goes from its node to the header, then to the condition: `true` into the body, `false` to
the point after the loop; the body's normal completion goes back to the header. A plain
`loop` goes from its node to the header and into the body, and the body goes back to the
header (its own steps: the library has none for a loop without a condition). The point
after a plain loop is reached **only** by an `exit` (or a jump out of it), so an exit-less
loop is genuinely infinite.

```
l1: while A loop
l2:    N := N + 1;
l3: end loop;
l4: <next statement>

l1 WhileLoopStmt -> [LoopHeader] -> l1 A
l1 A          -> l2 N              ; true  -- into the body
l1 A          -> after WhileLoopStmt ; false -- past the loop
l2 AssignStmt -> [LoopHeader]      ; back edge, to the header, then the condition
after WhileLoopStmt -> l4
```

```
l1: loop
l2:    N := N + 1;
l3: end loop;

l1 LoopStmt   -> [LoopHeader] -> l2 N  ; a plain loop is entered at its body
l2 AssignStmt -> [LoopHeader]          ; back edge
```

Note what is **absent** from the second listing: nothing reaches the point after the
`LoopStmt`, and consequently no `exit SubpBody (normal)` node either — a subprogram ending
in an exit-less loop never completes normally. This is the property the
`FunctionMissingReturn` query relies on, and the conformance test pins it by having no
annotation to write.

### For loops

Test: [`ql/test/library/Cfg/loops-for/`](../ql/test/library/Cfg/loops-for/)

**Rule.** A `for` loop is the library's `ForeachStmt`. The iterable is evaluated once; it
is `empty` (to the point after the loop) or `non-empty` (into the iteration). Each
iteration starts at the **loop variable's node** — its defining name, where the variable
takes its next value — then runs the body, then goes to the `[LoopHeader]`, from which
there is another iteration or the end of the loop. The iteration mechanism is otherwise
opaque (D-013). Both the range form and the `of` iterator form have this shape.

```
l1: for I in 1 .. 3 loop
l2:    N := N + I;
l3: end loop;
l4: <next statement>

l1 ForLoopStmt -> l1 1
l1 1           -> l1 3            ; the iterable is an ordinary expression: 1 .. 3 is a BinOp
l1 3           -> l1 (1 .. 3)
l1 (1 .. 3)    -> l1 I            ; non-empty -- the loop variable, then the body …
l1 (1 .. 3)    -> after ForLoopStmt ; empty -- … or skip the loop entirely
l1 I           -> l2 N
l2 AssignStmt  -> [LoopHeader]
[LoopHeader]   -> l1 I            ; iterate again …
[LoopHeader]   -> after ForLoopStmt ; … or leave
after ForLoopStmt -> l4
```

`for E of V` is identical with `V` as the iterable:

```
l1: for E of V loop

l1 V -> l1 E                 ; non-empty
l1 V -> after ForLoopStmt    ; empty
```

Because the iterable can be empty, a `for` loop — unlike a plain `loop` — always has a
path around it.

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
l1 Natural range 0 .. N -> l1 I              ; non-empty
l1 Natural range 0 .. N -> after ForLoopStmt ; empty
```

### Exit

Test: [`ql/test/library/Cfg/exit/`](../ql/test/library/Cfg/exit/)

**Rule.** An `exit` completes with `break`, **labelled with the loop it leaves** (D-034):
a bare `exit` leaves the innermost enclosing loop, `exit Name` the enclosing loop whose
`NamedStmt` declares that name (`exitTargetLoop`). The break propagates out to that loop,
through any `finally` part on the way, and reaches the point after it; no other construct
— not an inner loop, not a `case` — catches it. `exit when C` evaluates `C` first: `true`
takes the exit, `false` falls through to the next statement (its own steps: the library's
break cannot fall through). A `NamedStmt` wrapper is transparent.

```
l1: loop
l2:    exit when A;
l3:    N := N + 1;
l4: end loop;

l2 A        -> l2 ExitStmt      ; true  -- take the exit
l2 A        -> l3 N             ; false -- fall through to the next statement
l2 ExitStmt -> after LoopStmt   ; break
l3 AssignStmt -> [LoopHeader]   ; back edge
```

Named and nameless exits from nested loops:

```
l1: Outer : loop
l2:    Inner : loop
l3:       exit Outer when B;
l4:       exit Inner;
l5:    end loop Inner;
l6: end loop Outer;

l3 B          -> l3 ExitStmt          ; true
l3 B          -> l4 ExitStmt          ; false -- on to the next statement
l3 ExitStmt   -> after LoopStmt(l1)   ; break -- the *outer* loop, matched by name
l4 ExitStmt   -> after LoopStmt(l2)   ; break -- the innermost loop
after LoopStmt(l2) -> [LoopHeader](l1); leaving Inner continues Outer's body
```

### Goto and labels

Test: [`ql/test/library/Cfg/goto/`](../ql/test/library/Cfg/goto/)

**Rule.** A `goto` completes with `goto`, labelled with its target `Label` statement,
resolved by name text within the same scope (`gotoTargetLabel`, D-034). The jump
propagates out until it reaches the statement list that holds the label, and continues
before it, running any `finally` part it leaves on the way. A `goto` has **no** normal
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
l3 A           -> after IfStmt    ; false
l4 GotoStmt    -> l1 Label        ; goto -- backward
after IfStmt   -> l6 GotoStmt
l6 GotoStmt    -> l8 Label        ; goto -- forward; note there is no successor edge
l8 Label       -> l9 NullStmt
```

`N := 999;` on l7 produces **no nodes whatsoever** — it is unreachable, which is exactly
what `UnreachableStatement` reports. Because the CFG resolves `goto` properly, that query
needs none of the label-based heuristics its pre-CFG version had.

### Blocks

Test: [`ql/test/library/Cfg/blocks/`](../ql/test/library/Cfg/blocks/)

**Rule.** All three block forms pass straight through: control flows from the statement
before the block into the block's first part, and out of its last to the statement after.
The block's own "before" and "after" nodes are the only trace of it. A `declare` block
**elaborates its declarative part first**: each `ObjectDecl`'s initialiser is evaluated,
in declaration order, before the block's statements.

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

enter          -> l2 (1)          ; straight into the block
l2 AssignStmt  -> l6 Id           ; on to the declare block's *initialiser*
l6 CallExpr    -> l8 Local        ; elaboration done, now the statements
l6 CallExpr    -> exit (abnormal) ; exception -- the initialiser can raise
l8 AssignStmt  -> <after the block>
```

A named block behaves identically; `Named : declare …` adds only the `NamedStmt`'s
"before" and "after" nodes.

A **named number** (`K : constant := 3;`) is correctly skipped: it is a `NumberDecl`, not
an `ObjectDecl`, and its value is static, so there is nothing to evaluate. Only
`ObjectDecl` initialisers are elaborated, which leaves the declarative part of a *nested
package* inside a block unmodelled — a genuine but exotic gap.

A block and a body elaborate by the same rule, sharing one implementation
(`elaboratedInitializer`), so the two cannot drift apart. They did drift once: until
Phase 7.7 only blocks elaborated, which is defect C-1 in [Scopes](#scopes-1).

### Exceptions

Test: [`ql/test/library/Cfg/exceptions/`](../ql/test/library/Cfg/exceptions/)

**Rule.** A handled sequence with handlers is the library's `TryStmt`, its handlers its
`CatchClause`s. Every node in the protected region that can raise has an `exception` edge
to the **first handler**, which `match`es (into its statements) or not (`no-match`, on to
the next handler). No exception identity is compared, so every handler is reachable from
every raise. A `when others` handler matches only; without one, the last handler's
`no-match` propagates the exception out of the region (here, to the scope's abnormal
exit). A handler completing normally continues after the handled sequence.

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
l2 CallStmt  -> l5 handler          ; exception -- to the first handler
l3 RaiseStmt -> l5 handler          ; exception
l5 handler   -> l6 (1)              ; match
l5 handler   -> l7 handler          ; no-match -- the next handler
l7 handler   -> l8 (2)              ; match -- `others` matches everything
l6 AssignStmt -> l10                ; a handler body continues after the sequence
l8 AssignStmt -> l10
```

Note the absence of any edge to the scope's abnormal exit: the `when others` handler
catches everything. Remove it and the raise escapes from the last handler:

```
l1: begin
l2:    P;
l3: exception
l4:    when Constraint_Error =>
l5:       N := 3;
l6: end;
l7: <next statement>

l2 CallStmt -> l7                   ; successor
l2 CallStmt -> l4 handler           ; exception
l4 handler  -> l5 (3)               ; match
l4 handler  -> exit (abnormal)      ; no-match, then exception -- no others handler
```

When the regions nest, "escapes" means *to the enclosing handlers*, not to the scope
exit: an inner block with no `when others` sends its raise to its own handlers and, past
the last of them, to the handlers of the block around it, and only reaches the scope's
abnormal exit if no enclosing region catches it.

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

l3 CallStmt -> l5 handler    ; exception -- the inner handler …
l5 handler  -> l6 (5)        ; match
l5 handler  -> l9 handler    ; no-match, then exception -- … and the enclosing one
l9 handler  -> l10 (6)       ; match
```

Again there is no edge to the scope's abnormal exit: the outer `when others` stops it.

The exception *name* of a `raise` is evaluated first, so `raise Constraint_Error;` is
`Constraint_Error` → `RaiseStmt`.

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

### Finally parts

Tests: [`ql/test/library/Cfg/finally/`](../ql/test/library/Cfg/finally/) (normal
completion), [`ql/test/library/Cfg/finally-abnormal/`](../ql/test/library/Cfg/finally-abnormal/)
(`return`, `exit`, raise, nesting, `goto`; with the library's consistency checks).

**Rule.** GNAT's `finally` part (`begin … exception … finally … end`, an extension) is the
library's `TryStmt.getFinally()`. It runs however the protected statements and handlers
are left:

- they complete **normally**: after the `finally` part, the sequence completes normally;
- a **`return`**: after the `finally` part, the subprogram returns;
- a **raise** that no handler of the sequence catches (there is no `when others`), or a
  raise or `return` in a handler: after the `finally` part, the completion propagates
  outward, to enclosing handlers and `finally` parts;
- an **`exit`** from a loop outside the sequence, or a **`goto`** to a label outside it:
  after the `finally` part, the jump continues, through the `finally` part of any further
  sequence it leaves.

The `finally` part's own abnormal completions (a raise or `return` inside it) escape, as
a handler's do.

**Merged, not split (D-029).** There is one copy of the `finally` part. Its end continues
*every* way it was entered: after a `finally` part entered by `return` and normally, the
graph has both a `return` edge and a normal one out of it, so it also contains the path
that enters by `return` and continues as if the sequence had completed normally. The graph
is sound (every real path is in it) but over-approximate at a `finally` part. Up to 0.3.0
the graph split the `finally` part by the way it was entered; CodeQL has moved away from
splitting, and a query that needs to tell the ways apart uses `ControlFlowReachability`
instead (see `docs/cfg-migration-plan.md`, Step 5).

```
l1: begin
l2:    P;
l3:    X := 1;
l4: exception
l5:    when others =>
l6:       X := 2;
l7: finally
l8:    X := 3;
l9: end;
l10: X := 4;

l2 P;          -> l3 (normal), l5 handler (exception)
l3 X := 1      -> l8 X := 3
l6 X := 2      -> l8 X := 3
l8 X := 3      -> l10
```

With a `return` and an `exit`:

```
l1:  procedure Returns (B : Boolean) is      l10: Outer : loop
l2:  begin                                   l11:    loop
l3:     begin                                l12:       begin
l4:        if B then return; end if;         l13:          exit Outer when C;
l5:        X := 1;                           l14:          exit;
l6:     finally                              l15:       finally
l7:        X := 2;                           l16:          X := 4;
l8:     end;                                 l17:       end;
l9:     X := 3;                              l18:    end loop;
                                             l19:    X := 5;
                                             l20: end loop Outer;

l4 return     -> l7 X := 2               ; return -- into the finally part
l5 X := 1     -> l7 X := 2               ; normally
l7 X := 2     -> exit (normal)           ; return -- continuing the return …
l7 X := 2     -> l9 X := 3               ; … and the normal completion (merged)
l13 exit Outer -> l16 X := 4             ; break
l14 exit      -> l16 X := 4              ; break
l16 X := 4    -> after loop (l10)        ; break -- continuing exit Outer …
l16 X := 4    -> after loop (l11)        ; break -- … and exit (merged)
```

### Quantified expressions and raise messages

Test: [`ql/test/library/Cfg/quantified/`](../ql/test/library/Cfg/quantified/)

**Rule.** A quantified expression `(for all E of V => P (E))` evaluates what it iterates
over (`V`), then its predicate once, standing for every iteration, then itself. Data flow
defines `E` at `V`, as for a `for` loop. `raise E with Msg` evaluates the exception name,
then the message, then raises.

```
l1: B := (for all E of V => F (E));
l2: raise Program_Error with Msg;

V -> F -> E -> … -> F (E) -> QuantifiedExpr -> … -> B := …
Program_Error -> Msg -> RaiseStmt -> (exception)
```

### Return

Test: [`ql/test/library/Cfg/return/`](../ql/test/library/Cfg/return/)

**Rule.** A `return` evaluates its optional value, then its own node, which completes with
`return` to the scope's **normal** exit — an explicit return and falling off the end both
end there, and are told apart by the edge label (`return` / `successor`). An extended
return elaborates its object declaration, runs its optional `do … end return` statements,
and then completes with `return`.

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

A bare `return;` from a procedure has no value to evaluate, so its node follows its
"before" node directly:

```
l1: if A then
l2:    return;

l1 A          -> l2 ReturnStmt ; true
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

**Rule.** `and then` / `or else` are the library's `LogicalAndExpr` / `LogicalOrExpr`.
The **left** operand is a condition; one of its values decides the whole and goes straight
to the operator's "after" node for that value, the other evaluates the right operand,
whose value is the whole's. In a condition, the operator's values then branch as any
condition's do, so **the graph never joins the two values and splits them again**: `A`
false in `A and then B` leads only to the `false` branch. Plain `and` / `or` evaluate both
operands unconditionally, and the operator node then branches.

```
l1: if A and then B then
l2:    N := 1;
l3: end if;

l1 BinOp -> l1 A              ; the operator's node is at its start
l1 A     -> l1 B              ; true  -- not yet decided, evaluate the right operand
l1 A     -> after IfStmt      ; false -- short-circuit: the whole is false
l1 B     -> l2 (1)            ; true  -- the whole is true
l1 B     -> after IfStmt      ; false
```

`or else` is the mirror image — `true` decides and `false` evaluates the right operand.
Plain `and` has no Boolean edges out of its left operand at all:

```
l1: if A and B then

l1 A     -> l1 B        ; successor -- both operands are always evaluated
l1 BinOp -> l2 (4)      ; true
```

Nesting works the same way, a parenthesised operand passing its value through:

```
l1: if A and then (B or else C) then

l1 A         -> l1 B             ; true
l1 A         -> after IfStmt     ; false
l1 B         -> l2 (3)           ; true  -- the or else is true, so the whole is
l1 B         -> l1 C             ; false
l1 C         -> l2 (3), after IfStmt ; true / false
```

Up to 0.3.0 the operator had a single node that both values reached, so the graph
admitted `A` false followed by the `true` branch: an infeasible path. It no longer does.

### Conditional expressions

Test: [`ql/test/library/Cfg/cond-expr/`](../ql/test/library/Cfg/cond-expr/)

**Rule.** An `if` expression has the guard-by-guard shape of the `if` statement; its node
is at its start, and each arm's value is the expression's (`propagatesValue`), so in a
condition the arms' values branch directly. `(if C then E)` without `else` is `True` when
`C` is false. A `case` expression is the library's `Switch`, as the statement is.

```
l1: N := (if A then 1 elsif B then 2 else 3);

l1 IfExpr    -> l1 A          ; its node is at its start
l1 A         -> l1 (1)        ; true
l1 A         -> l1 B          ; false
l1 B         -> l1 (2)        ; true
l1 B         -> l1 (3)        ; false
l1 (1)       -> after IfExpr  ; every arm gives the expression its value
l1 (2)       -> after IfExpr
l1 (3)       -> after IfExpr
after IfExpr -> l1 ParenExpr  ; and then evaluation continues normally
l1 ParenExpr -> l1 N          ; the assignment's LHS, RHS having been evaluated
l1 N         -> l1 AssignStmt
```

```
l1: N := (case N is when 0 => 10, when others => 20);

l1 N        -> l1 0              ; the first alternative's choice
l1 0        -> l1 (10)           ; match
l1 0        -> l1 others         ; no-match
l1 others   -> l1 (20)           ; match
l1 (10)     -> after CaseExpr
l1 (20)     -> after CaseExpr
```

### Tasking

Test: [`ql/test/library/Cfg/tasking/`](../ql/test/library/Cfg/tasking/)

**Rule.** Tasking constructs are **opaque** (D-013): there are no inter-task edges and no
rendezvous modelling, but every statement must still appear in the graph. A `select` may
enter *any one* of its branches — each guarded alternative's statements, the `else` part,
and the abortable part of `select … then abort` — and every branch converges after the
`select`. The choice is made branch by branch through `[select i]` (take branch *i*) and
`[skip i]` (one of those after it) nodes, with Boolean successors because a node may not
have two plain ones: the choice is not a condition anyone wrote. `accept … do … end` is a
node followed by its statements (data flow defines the entry's formals at that node); a
plain `accept E;`, a `delay`, an `abort` and a `requeue` are opaque leaves that complete
normally.

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

l1 SelectStmt  -> [select 1], [skip 1]   ; true / false
[select 1]     -> l2 AcceptStmtWithStmts ; the first branch …
[skip 1]       -> [select 2], [skip 2]   ; true / false
[select 2]     -> l6 AcceptStmt          ; … the second …
[skip 2]       -> l8 NullStmt            ; … or the last
l2 AcceptStmtWithStmts -> l3 NullStmt
l3 NullStmt    -> after SelectStmt       ; all converge after the select
l6 AcceptStmt  -> after SelectStmt
l8 NullStmt    -> after SelectStmt
after SelectStmt -> l10
```

`accept E do … end` contributes its own node before its inner statements, where the
rendezvous begins; the plain `accept F;` is itself a leaf node.

```
l1: select
l2:    delay 1.0;
l3: then abort
l4:    null;
l5: end select;

l1 SelectStmt -> [select 1], [skip 1]
[select 1]    -> l2 DelayStmt   ; the triggering alternative …
[skip 1]      -> l4 NullStmt    ; … and the abortable part are both reachable
l2 DelayStmt  -> after SelectStmt
l4 NullStmt   -> after SelectStmt
```

Both branch shapes above were **wrong** until Phase 7.7. A plain `accept E;` was matched
by no control-flow tree at all, and the abortable part was never read. Both constructs
therefore had no CFG nodes, and `ada/unreachable-statement` reported them as unreachable —
two confirmed false positives, fixed and pinned by this test.

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

### shaped (36)

Has a rule of its own in `ControlFlowGraphImpl.qll` (its evaluated children, a class of the library's AST signature, or steps): its successor structure is specified in Part 3 and pinned by a conformance test.

`AcceptStmtWithStmts`, `AssignStmt`, `BeginBlock`, `BinOp`, `CallExpr`, `CallStmt`, `CaseExpr`, `CaseExprAlternative`, `CaseStmt`, `CaseStmtAlternative`, `DeclBlock`, `DefiningName`, `ElsifExprPart`, `ElsifStmtPart`, `ExceptionHandler`, `ExitStmt`, `ExtendedReturnStmt`, `ForLoopStmt`, `GotoStmt`, `HandledStmts`, `IfExpr`, `IfStmt`, `Label`, `LoopStmt`, `NamedStmt`, `OthersDesignator`, `PragmaNode`, `QuantifiedExpr`, `RaiseExpr`, `RaiseStmt`, `ReturnStmt`, `SelectStmt`, `StmtList`, `SubtypeIndication`, `UnOp`, `WhileLoopStmt`

### expression (41)

Evaluated by the library's default rule: its evaluated children left to right, then the node itself. No construct-specific shape.

`AbstractStateDeclExpr`, `Aggregate`, `AggregateAssoc`, `Allocator`, `ArraySubcomponentChoiceName`, `AssocList`, `AttributeRef`, `BoxExpr`, `BracketAggregate`, `BracketDeltaAggregate`, `CharLiteral`, `CompositeConstraintAssoc`, `ConcatOp`, `ConcatOperand`, `ConcatOperandList`, `DeclExpr`, `DeltaAggregate`, `DiscreteSubtypeName`, `DottedName`, `EndName`, `ExplicitDeref`, `ExprAlternativesList`, `FormatStringLiteral`, `Identifier`, `IntLiteral`, `IteratedAssoc`, `MembershipExpr`, `MultiDimArrayAssoc`, `NullLiteral`, `NullRecordAggregate`, `ParamAssoc`, `ParenExpr`, `QualExpr`, `RealLiteral`, `ReduceAttributeRef`, `RelationOp`, `StringLiteral`, `SyntheticDefiningName`, `SyntheticIdentifier`, `TargetName`, `UpdateAttributeRef`

### opaque (8)

A statement with no rule of its own: a leaf that completes normally. It is in the graph; its internals are not modelled (D-013).

`AbortStmt`, `AcceptStmt`, `DelayStmt`, `ErrorStmt`, `NullStmt`, `RequeueStmt`, `SimpleDeclStmt`, `TerminateAlternative`

### structural (14)

Read by the CFG but never a node: its parts are children of the construct that owns it (`getChild0`). See Part 1.

`DeclarativePart`, `ElsePart`, `ExtendedReturnStmtObjectDecl`, `FinallyPart`, `ForLoopSpec`, `ForLoopVarDecl`, `LabelDecl`, `NamedStmtDecl`, `ObjectDecl`, `ParamSpec`, `RangeConstraint`, `SelectWhenPart`, `ThenAbortPart`, `WhileLoopSpec`

### n/a (301)

Not control-relevant: nothing here is executed, so nothing is in the graph.

**operators** (24) — Operator tokens. An operator is not itself executed -- its operands are, and the enclosing `BinOp`/`UnOp` node represents applying it. `exprLike` excludes `Raw::Op` for exactly this reason.

`OpAbs`, `OpAnd`, `OpAndThen`, `OpConcat`, `OpDiv`, `OpDoubleDot`, `OpEq`, `OpGt`, `OpGte`, `OpIn`, `OpLt`, `OpLte`, `OpMinus`, `OpMod`, `OpMult`, `OpNeq`, `OpNot`, `OpNotIn`, `OpOr`, `OpOrElse`, `OpPlus`, `OpPow`, `OpRem`, `OpXor`

**presence markers** (28) — Generated `...Absent`/`...Present` pairs recording whether an optional keyword (`abstract`, `limited`, `overriding`, …) was written. Pure syntax.

`AbortAbsent`, `AbortPresent`, `AbstractAbsent`, `AbstractPresent`, `AliasedAbsent`, `AliasedPresent`, `AllAbsent`, `AllPresent`, `ConstantAbsent`, `ConstantPresent`, `LimitedAbsent`, `LimitedPresent`, `NotNullAbsent`, `NotNullPresent`, `PrivateAbsent`, `PrivatePresent`, `ProtectedAbsent`, `ProtectedPresent`, `ReverseAbsent`, `ReversePresent`, `SynchronizedAbsent`, `SynchronizedPresent`, `TaggedAbsent`, `TaggedPresent`, `UntilAbsent`, `UntilPresent`, `WithPrivateAbsent`, `WithPrivatePresent`

**type definitions and constraints** (36) — The static type system: type definitions, subtype indications, constraints, ranges used as type bounds. Elaborating a type declaration can in principle run code (a dynamic bound, say), which the CFG does not model -- a documented limitation.

`AccessToSubpDef`, `AnonymousTypeAccessDef`, `AnonymousTypeDecl`, `ArrayTypeDef`, `ClasswideTypeDecl`, `ComponentDef`, `CompositeConstraint`, `ConcreteTypeDecl`, `DecimalFixedPointDef`, `DeltaConstraint`, `DerivedTypeDef`, `DigitsConstraint`, `DiscreteBaseSubtypeDecl`, `EnumTypeDef`, `FloatingPointDef`, `FormalDiscreteTypeDef`, `FormalTypeDecl`, `IncompleteFormalTypeDecl`, `IncompleteTaggedTypeDecl`, `IncompleteTypeDecl`, `InterfaceTypeDef`, `ModIntTypeDef`, `NullRecordDef`, `OrdinaryFixedPointDef`, `PrivateTypeDef`, `ProtectedDef`, `ProtectedTypeDecl`, `RecordDef`, `RecordTypeDef`, `SignedIntTypeDef`, `SingleTaskTypeDecl`, `SubtypeDecl`, `SynthAnonymousTypeDecl`, `TaskDef`, `TaskTypeDecl`, `TypeAccessDef`

**declarations** (44) — Declarations other than the object declarations whose initialisers are elaborated in a `declare` block or a body. The declarative part of a nested *package* is still not elaborated -- see Blocks.

`AbstractFormalSubpDecl`, `AbstractStateDecl`, `AbstractSubpDecl`, `AcceptStmtBody`, `AnonymousExprDecl`, `AssertionLevelDecl`, `ComponentDecl`, `ConcreteFormalSubpDecl`, `DiscriminantSpec`, `EntryDecl`, `EntryIndexSpec`, `EnumLiteralDecl`, `ErrorDecl`, `ExceptionDecl`, `GenericFormalObjDecl`, `GenericFormalPackage`, `GenericFormalSubpDecl`, `GenericFormalTypeDecl`, `GenericPackageDecl`, `GenericPackageInstantiation`, `GenericPackageInternal`, `GenericPackageRenamingDecl`, `GenericSubpDecl`, `GenericSubpInstantiation`, `GenericSubpInternal`, `GenericSubpRenamingDecl`, `NoTypeObjectRenamingDecl`, `NullSubpDecl`, `NumberDecl`, `PackageBodyStub`, `PackageDecl`, `PackageRenamingDecl`, `ProtectedBody`, `ProtectedBodyStub`, `SingleProtectedDecl`, `SingleTaskDecl`, `SubpBodyStub`, `SubpDecl`, `SubpRenamingDecl`, `SyntheticCharEnumLit`, `SyntheticFormalParamDecl`, `SyntheticObjectDecl`, `SyntheticSubpDecl`, `TaskBodyStub`

**lists** (24) — List wrappers whose elements the owning construct reads directly. `StmtList` and `AssocList` are the exceptions and appear above.

`AbstractStateDeclList`, `AdaNodeList`, `AlternativesList`, `AspectAssocList`, `BaseAssocList`, `CaseExprAlternativeList`, `CaseStmtAlternativeList`, `CompilationUnitList`, `ConstraintList`, `DeclList`, `DefiningNameList`, `DiscriminantChoiceList`, `DiscriminantSpecList`, `ElsifExprPartList`, `ElsifStmtPartList`, `EnumLiteralDeclList`, `FormatStringChunkList`, `NameList`, `ParamSpecList`, `ParentList`, `PragmaNodeList`, `SelectWhenPartList`, `UnconstrainedArrayIndexList`, `VariantList`

**abstract base classes** (72) — Not instantiable: no node in a database has this kind.

`AbortNode`, `AbstractNode`, `AccessDef`, `AdaList`, `AdaNode`, `AliasedNode`, `AllNode`, `ArrayIndices`, `AspectClause`, `BaseAggregate`, `BaseAssoc`, `BaseFormalParamDecl`, `BaseFormalParamHolder`, `BaseId`, `BaseLoopStmt`, `BasePackageDecl`, `BaseRecordDef`, `BaseSubpBody`, `BaseSubpSpec`, `BaseSubtypeDecl`, `BaseTypeAccessDef`, `BaseTypeDecl`, `BasicAssoc`, `BasicAssocList`, `BasicDecl`, `BasicSubpDecl`, `BlockStmt`, `BodyNode`, `BodyStub`, `ClassicSubpDecl`, `CompositeStmt`, `CondExpr`, `ConstantNode`, `Constraint`, `DiscriminantPart`, `Expr`, `ExprList`, `FormalSubpDecl`, `FormatStringTokNode`, `GenericDecl`, `GenericFormal`, `GenericInstantiation`, `GenericRenamingDecl`, `IdentifierList`, `InterfaceKind`, `IterType`, `LimitedNode`, `LoopSpec`, `Mode`, `Name`, `NotNull`, `NumLiteral`, `Op`, `OverridingNode`, `PpDirective`, `PrivateNode`, `ProtectedNode`, `Quantifier`, `RealTypeDef`, `ReverseNode`, `SimpleStmt`, `SingleTokNode`, `Stmt`, `SubpKind`, `SynchronizedNode`, `TaggedNode`, `TypeDecl`, `TypeDef`, `TypeExpr`, `UntilNode`, `UseClause`, `WithPrivate`

**other syntax** (73) — Compilation units, with/use clauses, aspects, pragmas, defining names, designators and similar structure that carries no control flow.

`AnonymousType`, `AspectAssoc`, `AspectSpec`, `AtClause`, `AttributeDefClause`, `CompilationUnit`, `ComponentClause`, `ComponentList`, `ConstrainedArrayIndices`, `ConstrainedSubtypeIndication`, `DiscreteSubtypeIndication`, `EntryCompletionFormalParams`, `EntrySpec`, `EnumLitSynthTypeExpr`, `EnumRepClause`, `EnumSubpSpec`, `ForLoopIterFilter`, `FormatStringChunk`, `FormatStringTokEnd`, `FormatStringTokMid`, `FormatStringTokStart`, `FormatStringTokString`, `GenericFormalPart`, `InterfaceKindLimited`, `InterfaceKindProtected`, `InterfaceKindSynchronized`, `InterfaceKindTask`, `IterTypeIn`, `IterTypeOf`, `KnownDiscriminantPart`, `LibraryItem`, `ModeDefault`, `ModeIn`, `ModeInOut`, `ModeOut`, `MultiAbstractStateDecl`, `NullComponentDecl`, `OverridingNotOverriding`, `OverridingOverriding`, `OverridingUnspecified`, `Params`, `ParenAbstractStateDecl`, `PpElseDirective`, `PpElsifDirective`, `PpEndIfDirective`, `PpIfDirective`, `PpThenKw`, `PragmaArgumentAssoc`, `PrivatePart`, `PublicPart`, `QuantifierAll`, `QuantifierSome`, `RangeSpec`, `RecordRepClause`, `RenamingClause`, `SubpKindFunction`, `SubpKindProcedure`, `SubpSpec`, `Subunit`, `SyntheticBinarySpec`, `SyntheticRenamingClause`, `SyntheticTypeExpr`, `SyntheticUnarySpec`, `TypeAttributesRepository`, `UnconstrainedArrayIndex`, `UnconstrainedArrayIndices`, `UnknownDiscriminantPart`, `UsePackageClause`, `UseTypeClause`, `ValueSequence`, `Variant`, `VariantPart`, `WithClause`

<!-- END GENERATED COVERAGE -->

---

## Part 5 — Recorded limitations

- **Conservative-raise precision.** Because every `CallStmt`/`CallExpr` may complete with
  an `exception` edge (D-013), a paired-call query will report a call pair split by *any*
  intervening call as "not invariably paired" on the exceptional path — unless the pairing
  query ignores raise-completion edges. `MissingPairedCall` therefore exposes both a strict
  variant (all paths) and a `normalPathsOnly` variant (ignore raise edges); the
  `open-without-close` query uses `normalPathsOnly` for v1 signal quality.
- **Exception identities are not matched.** A raise in a protected region reaches the
  handlers one by one, each of which may or may not match, regardless of which exception
  it names; only `when others` is known to match.
- **`finally` parts are merged, not split.** The end of a `finally` part continues every
  way it was entered (see [Finally parts](#finally-parts)); queries recover the
  distinction with `ControlFlowReachability`.
- **`case` alternatives are not told apart by value.** A choice is matched in order, but
  no value is compared; every alternative is reachable.
- **A quantified expression's predicate is evaluated once**, standing for every
  iteration, and its iterator filter (`when`) is not evaluated. Ada 2022 `DeclExpr` is an
  opaque post-order expression.
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
  textually (`exitTargetLoop`, `gotoTargetLabel`), and for the paired-call target match.
- Named loops/blocks are wrapped: `Outer: loop … end loop Outer;` is a `Raw::NamedStmt`
  (`getDecl()` → `NamedStmtDecl`, `getStmt()` → the `LoopStmt`). An `ExitStmt` naming a
  loop matches the enclosing `BaseLoopStmt` whose `NamedStmtDecl` name text equals
  `getLoopName().getText()`; a nameless `ExitStmt` targets the innermost enclosing
  `BaseLoopStmt`.

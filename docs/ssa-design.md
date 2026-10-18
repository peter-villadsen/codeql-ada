# SSA design and conformance specification

This is the SSA counterpart to `docs/cfg-design.md`: a snippet-by-snippet specification of
what the Ada instantiation of the shared `codeql/ssa` framework (`SsaImpl.qll`, Task 9.2)
actually does, each entry pinned by a machine-checked conformance test. Read
`docs/phase9.2-plan.md` Task 9.2 first for the design rationale (anchor choices, the two
bugs the tests surfaced); this document is the specification the tests are checked against,
not the narrative of how it was built.

## How this fits together

- **`SsaImpl.qll`** (`ql/lib/codeql/ada/dataflow/internal/`) instantiates `codeql/ssa`'s
  `Make` over the control-flow graph's basic blocks (`SsaCfg`, the shared library's
  `BasicBlock` module; see `docs/cfg-design.md`). A write or read is at the node that
  represents its AST node (`injects`).
- **`SourceVariable`** is a `Raw::DefiningName` introduced by an `ObjectDecl`, `ParamSpec`
  or `ForLoopVarDecl` (D-024) — not record components, array elements, dereferences,
  `NumberDecl`s or renamings.
- **A definition is either a write or a phi node.** A write survives only if some read
  reaches it without an intervening write of the same variable (dead-store elision, part of
  the shared framework, not this project's code). An uninitialised declaration and a pure
  `out`-mode parameter get a value-less write at their scope's entry (`uninitializedWrite`),
  so that a component stored before any whole write is a store into a defined variable; it
  has no value, so nothing flows from it.
- **`codeql.ada.dataflow.Ssa`** is the public, class-based API over the same definitions:
  see the next section.

## The class-based API (`codeql.ada.dataflow.Ssa`)

`SsaImpl.qll` also instantiates the shared framework's nested `MakeSsa` module, as Java and
C# do. It gives classes whose predicates are cached, and it is the SSA shape the shared
Guards and ControlFlowReachability libraries expect (see `docs/cfg-migration-plan.md`).
Test: [`ql/test/library/Ssa/class-api/`](../ql/test/library/Ssa/class-api/).

| Class | Ada definitions |
| --- | --- |
| `SsaParameterInit` | a formal's value on entry to its body (`in`, `in out`; an `out` formal's is value-less). `getParameter()` is the public `Parameter` |
| `SsaExplicitWrite` | the above, and `X := E`, an object declaration (with or without an initialiser), a `for` loop variable, an entry formal at its `accept` |
| `SsaUncertainWrite` | an `out`/`in out` actual at a call, and a call that may store into a variable other subprograms write (`callMayWrite`) |
| `SsaPhiDefinition` | where control flow merges |

`SsaExplicitWrite.getDefinition()` is a `VariableWrite`: `asExpr()` is the name written
(the assignment's target, or the declaration's defining name) and `getValue()` is the
right-hand side or initialiser, if any. A `for` loop variable has no value: it takes the
iterable's elements, not the iterable. `SsaDefinition.getARead()` gives the reads a
definition reaches; the synthetic exit reads of `out` formals and extended-return objects
are not expressions, so they are not among them.

## How to read a construct entry

Each entry gives an Ada snippet and the `Definition`s the SSA graph is expected to contain
for it, in the notation:

```
l4: X : Integer := 1;
l7: Y := X;
l8: X := Y + 1;

def(X)@l4 reads l7's X
def(Y)@l7 reads l8's Y
```

`def(V)@lN` is a `WriteDefinition` of source variable `V`, located at line `N`; `phi(V)@lN`
is a `PhiNode`. "reads" lines list every CFG position `ssaDefReachesRead` reports for that
definition. This corresponds exactly to the `edge=`-style annotation the test enforces:

```
-- $ ssa=def(X)@4:19|reads|Identifier@7:9
```

The annotation goes on the line where the **definition** ends (mirroring the CFG tests'
predecessor-anchoring convention) — for a phi-input edge, on the line where the **input**
definition ends, since it plays the same "earlier in program order" role.

`ql/debug/SsaAnnotations.ql` prints the complete annotation comment for every line of a
file, so annotations are transcribed, not invented. Transcribe only after checking the
graph against the rule stated here — the debug query reports what the implementation
*does*, which is the thing under test.

## Construct specifications

### Straight-line code

```ada
X : Integer := 1;  --  l4
Y : Integer;       --  l5
Y := X;             --  l7
X := Y + 1;          --  l8
```

- `def(X)@l4` (the initialiser's own node — `ObjectDecl` itself has no CFG node) reads l7's
  `X`.
- `def(Y)@l7` (the `AssignStmt`'s own post-order node) reads l8's `Y`.
- `X`'s second write (l8) is dead — nothing reads it — and so is not a `Definition` at all.
  `Y`'s declaration (l5) has no initialiser, so it is not a `Definition` either; its value is
  supplied entirely by l7's write.

Test: `ql/test/library/Ssa/straight-line/`.

### Branch join

```ada
if True then    --  l6
   X := 1;       --  l7
else
   X := 2;       --  l9
end if;          --  l10
X := X + 1;      --  l11
```

- `def(X)@l7`, `def(X)@l9` — one write per branch.
- `phi(X)@l6` (at the point after the `IfStmt`, where its branches converge per
  `docs/cfg-design.md`'s if-statement rule) has both as inputs and reads l11's `X`.

**Anchoring trap:** a phi's `Definition.getLocation()` is the *whole* branching construct's
span (`6:4:10:11` here — from `if` to `end if;`), not a single point, because `codeql/ssa`
defines a phi's location as `bb.getLocation()`, and a basic block's location is its first
node's — here, the `IfStmt`'s "after" node, whose location is the entire `IfStmt`'s span.
The anchoring rule (comment's start line = result's end line) therefore puts a phi's
`reads` annotation on the line where the branching construct *ends* (`end if;`, l10) —
confirmed by a first, wrong attempt at l6 producing a "Missing result" failure pointing at
the correct line. A `from` edge is anchored at the *input*'s own (ordinarily single-line)
location as usual.

Test: `ql/test/library/Ssa/if-join/`.

### Loop

```ada
Total : Integer := 0;       --  l5
for I in 1 .. 10 loop        --  l7
   Total := Total + I;        --  l8
end loop;
```

- `def(Total)@l5` and `def(Total)@l8` (the loop body's `AssignStmt`) both feed
  `phi(Total)@l7:8` — the loop header's phi, merging the initial value with the back edge,
  exactly as ordinary SSA loop handling requires. No special casing was needed to get this:
  it falls out of the shared framework once the single static write inside the body
  (`def(Total)@l8`) is on the loop's back-edge path, which it always is.
- `def(I)@l7` (the `for`-loop variable, anchored at the iterable `1 .. 10`; see "For-loop
  variable" below) reads l8's `I`.
- The phi is at `7:8`, the loop variable `I`: in the control-flow graph each iteration
  starts at the loop variable's node, so the block where the initial value and the back
  edge meet starts there. (Up to 0.3.0 it was at `8:16`, the first read in the body.) A
  phi's location is its block's first node, so it can also coincide exactly with a read it
  reaches — not a bug, just how the two independent renderings (`phi(V)@l:c` vs.
  `nodeKey`) happen to land on the same point.

Test: `ql/test/library/Ssa/loop/`.

### Parameters — in / in out / out

```ada
procedure Modify (A : in out Integer; B : out Integer) is  --  l7
begin
   A := A + 1;  --  l9
   B := 0;      --  l10
end Modify;     --  l11
...
X := 1;                       --  l15
Modify (B => Y, A => X);      --  l16
Y := X;                       --  l17
```

- `def(A)@l7` — the entry write for the `in out` formal, anchored at index 0 of the owning
  scope's `EntryBasicBlock` (`ParamSpec` itself has no CFG node) — reads l9's `A`.
- **No value for `B`** (pure `out`): it receives nothing from the caller. It gets a
  value-less write at entry (`uninitializedWrite`, for content flow: see
  `docs/dataflow-design.md`, "Content and shared variables"), but `B := 0` comes before
  any read, so that write is dead and has no `Definition`. `Y`, declared without a value
  in the enclosing procedure, gets the same kind of write, `def(Y)@l6`, which l16's `Y`
  (the actual in `B => Y`) reads.
- `def(A)@l9` (`A := A + 1;`) and `def(B)@l10` (`B := 0;`) both read
  `exitSubpBody(normal)@l7` — the synthetic exit read (Task 9.2.3 finding 1) that keeps an
  `out`/`in out` parameter's last write alive even though nothing *inside* `Modify` reads it
  again.
- `def(X)@l15` (`X := 1;`) reads l16's `X` (the actual in `A => X`).
- `def(X)@l16` — the uncertain write-back from the call, anchored at the `CallStmt`'s own
  node (l16) — reads l17's `X`. **`Y`'s write-back from this same call does not appear at
  all**: nothing reads the value `Modify` gave `Y` through `B => Y` before `Y` is
  overwritten at l17, so it is dead, exactly like an unused local. This also confirms named
  association resolves by *name* (`A => X`, `B => Y`, reversed source order), not source
  position: swap either name and the wrong variable would get the uncertain write.
- **Anchoring trap, again:** the entry write's own `Definition.getLocation()` is the *whole
  scope's* span (`7:4` to `11:15` here), because it comes from the scope `AdaNode`'s own
  location. Its `reads` annotation therefore goes on the line where the scope *ends*
  (`end Modify;`, l11) — the same trap as a phi's multi-line location, not a new one.

Test: `ql/test/library/Ssa/params-inout/`. This fixture is also where Task 9.2.3's two real
bugs were first found (dead-store elision eating an `out`/`in out` parameter's last write;
`strictcount` dropping the first formal of every callable) — see
`docs/phase9.2-plan.md` Task 9.2.3 for that narrative.

### For-loop variable

```ada
for I in 1 .. 10 loop
   Total := Total + I;
end loop;
```

`def(I)` is anchored at the position of the loop's *iterable* expression (`1 .. 10`).
`ForLoopVarDecl` and `ForLoopSpec` are structural in the CFG's coverage appendix; the loop
variable's defining name does have a node, where each iteration starts, and the write could
move there (one write per iteration, the more precise anchor) — a possible refinement, not
done in the CFG migration so as not to change SSA results with it. The iterable anchor is a
deliberate approximation: SSA does not need one
write per dynamic iteration, only a static definition that dominates every read inside the
body (which the iterable's node does, including across the back edge) and a value origin a
later taint step can use (the iterable itself — taint into the iterated collection should
reach the loop variable). See "Loop" above for the fixture and test.

### Multi-identifier declaration

```ada
X, Y : Integer;
X := 1;   --  l4
Y := X;   --  l5
```

`ada_xref` resolves a reference to the `ObjectDecl` as a whole, not to the specific
`DefiningName` within it, so `X` and `Y` are disambiguated by matching the reference's own
name text against the declaration's defining names (D-024, `getSourceVariable`). This is a
Task 9.2.2 property, verified directly against a scratch database in
`docs/phase9.2-plan.md` (`X`/`Y` resolve as two distinct variables, never merged) rather
than as a dedicated conformance-test family here: the property lives entirely in
`getSourceVariable`, one function call away from the CFG, and does not need the def-use
graph machinery this document's other families are testing.

## Renamed-source rendering

A debugging aid, not a conformance check: `scripts/render_ssa.py` (via
`ql/debug/PrintSsaRenamed.ql` and `ql/lib/codeql/ada/test/SsaRenderAnnotations.qll`) renders
a source file with every write and read subscripted (`X_1`, `X_2`, ...) and every phi shown
as a comment, so a suspected SSA miscalculation can be read directly rather than
reconstructed from a table of edges:

```
   if True then
      X_1 := 1;
   else
      X_2 := 2;
   end if;  --  X_3 = phi(X_1, X_2)
   X := X_3 + 1;
```

**Usage** (inside the WSL/Linux LAL build env, with `codeql` on `PATH` — same environment as
every other `scripts/*.py`):

```sh
python3 scripts/render_ssa.py path/to/file.adb
```

Writes `file.ssa.adb` alongside the input; never overwrites it. Flags:

| Flag | Meaning |
| --- | --- |
| `--out <path>` | Write the rendering somewhere other than the default `<file>.ssa.adb` sibling. |
| `--file <path>` | Required when the first argument is a **directory** rather than a file: extracts that whole directory as the source root (needed when `file.adb` requires sibling files or a project to resolve names) and renders the one file named here. Without it, a single file is extracted in isolation. |
| `--codeql <path>` | Path to the `codeql` binary, if not already on `PATH`. Defaults to the `CODEQL_BIN` environment variable, then plain `codeql`. |

Not wired into `codeql test run`, CI, or any other automation — it is a standalone,
on-demand tool; there is no flag or setting that "turns it on" beyond invoking it directly.

The design problem this had to solve: a write's CFG *anchor*
(where `SsaImpl.qll`'s `variableWrite` fires, needed for dataflow correctness) is frequently
not where the variable's *name* appears in the source — an `AssignStmt` write is anchored at
the whole statement but its name is just the target; a declaration-based write (`ObjectDecl`
init, parameter entry, `for`-loop var) is anchored elsewhere entirely but its name is the
`SourceVariable`'s own `DefiningName`. `SsaImpl.qll` exposes `getWriteNameOccurrence` for
exactly this — one place to ask "where do I print this write's subscript" that cannot drift
from the real write-classification logic, because it is built from the same predicates
(each extended with an extra, ignored-everywhere-else output column) rather than
re-derived independently.

**Building this immediately surfaced two real, previously-unknown issues** — exactly the
tool's purpose, working as intended:

1. **A call's uncertain write-back and the actual's own read collide at one text span.**
   `Modify (A => X)`'s `X` is simultaneously a read (the pre-call value, from the generic
   "any reference is a read" rule) and an `UncertainWriteDefinition`'s name occurrence (the
   write-back, D-022) — the same AST node, so substituting both at once corrupted the
   output (`X_1_2`, confirmed and then fixed). Resolved by making a call-site uncertain
   write a *comment* (`writeEdit` now excludes `UncertainWriteDefinition`; a separate
   `write-back: X_2` comment is appended at the call's own line) rather than a
   substitution — the read wins the one available text position, matching how a phi's
   synthetic merge is already shown as a comment rather than forced into source text that
   has no place for it.
2. **A named association's designator (`X` in `Foo (X => Y)`) was being read at all.**
   `ada_xref` resolves a designator to the *callee's* formal `ParamSpec` (semantically
   reasonable — it does name that parameter), and the CFG evaluates it like any other
   `Identifier` (node-kind classification does not know about a reference's *role*; the
   coverage appendix's "designators" bullet is a different node kind, not this one) — so
   `variableRead` registered it as a read of the callee's `SourceVariable`, positioned in
   the *caller's* basic blocks. Harmless to the actual `Definition`/phi graph (that scope
   has no write of the callee's formal for any dominance/liveness computation to act on, so
   nothing was ever inserted incorrectly, and the existing edge-based conformance tests
   cannot see it either way, since `ssaDefReachesRead` requires a definition to exist) — but
   genuinely wrong, rendered as a confusing `B_UNDEF` on plain "B" text, and something a
   future consumer that iterates reads for reporting (a path-problem query) would otherwise
   show. Fixed with `isDesignator`, added to `SsaImpl.qll`'s `variableRead` alongside the
   existing `isAssignTarget` exclusion. Confirmed via the full SSA conformance suite that
   this changes no existing edge (as expected — the excluded reads never had a reaching
   definition to check), and via the render tool that the designator now renders as plain,
   unlabelled text, as any other syntax SSA does not track does.

Separately, and *not* a bug: a pure `out`-mode actual can render as `_UNDEF` even though its
"read" is real and correctly modelled — Ada does not actually consult an `out` parameter's
prior value, but the render tool (like `variableWrite`/`variableRead` themselves) treats
argument evaluation as a read unconditionally, a documented, harmless over-approximation
(see `outOrInOutActualWrite`'s doc comment). Seeing `_UNDEF` there is expected, not a defect
to chase.

## Recorded limitations (D-023)

- **Record components, array elements, dereferences, `NumberDecl`s and renamings are not
  SSA variables.** `SourceVariable` (D-024) is restricted to whole `ObjectDecl`/`ParamSpec`/
  `ForLoopVarDecl` names. A write through `Rec.Field := ...` or `Arr (I) := ...` is not a
  write of `Rec` to SSA — `getSourceVariable` has no result for the target, so
  `assignWrite` does not fire. Data flow follows such writes as content instead, through
  the post-update node of `Rec`'s read (`docs/dataflow-design.md`).
- **SSA is per subprogram.** A package variable or a variable shared with nested
  subprograms is an SSA variable in each subprogram that refers to it; flow between
  them is data flow's `jumpStep`. Within a subprogram, each resolved call is an uncertain
  write of every such variable that another subprogram stores into (`callMayWrite`).
- **Exceptions are not covered by a dedicated conformance-test family.** A handler that
  joins values from a partially-executed body is exactly the kind of construct this
  document's method (hand-derive, run, transcribe, verify a wrong annotation fails) should
  be applied to before it is trusted — deferred, not silently assumed correct, and named
  here so it is not mistaken for "checked."
- **Out actuals of entry calls are not written.** `getCalleeSpec` covers subprograms,
  generic subprograms (the target of a call to an instance), protected operations and
  calls through access-to-subprogram values (the access type's profile); an entry call
  has no callee spec, so an actual passed to an entry's `out`/`in out` formal is never
  modelled as a write — a documented gap, not a silent one.
- **A pure `out` actual's argument-evaluation reference is modelled as a read**, alongside
  its uncertain write, even though Ada does not actually read an `out` actual's prior value.
  Harmless (reads only consume flow, never introduce it) and deliberate — see
  `outOrInOutActualWrite`'s doc comment in `SsaImpl.qll`.

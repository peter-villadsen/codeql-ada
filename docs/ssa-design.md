# SSA design and conformance specification

This is the SSA counterpart to `docs/cfg-design.md`: a snippet-by-snippet specification of
what the Ada instantiation of the shared `codeql/ssa` framework (`SsaImpl.qll`, Task 9.2)
actually does, each entry pinned by a machine-checked conformance test. Read
`docs/phase9.2-plan.md` Task 9.2 first for the design rationale (anchor choices, the two
bugs the tests surfaced); this document is the specification the tests are checked against,
not the narrative of how it was built.

## How this fits together

- **`SsaImpl.qll`** (`ql/lib/codeql/ada/dataflow/internal/`) instantiates `codeql/ssa`'s
  `Make` over the Phase 7 CFG's basic blocks, via a small `SsaCfg` renaming adapter.
- **`SourceVariable`** is a `Raw::DefiningName` introduced by an `ObjectDecl`, `ParamSpec`
  or `ForLoopVarDecl` (D-024) — not record components, array elements, dereferences,
  `NumberDecl`s or renamings.
- **A definition is either a write or a phi node.** A write survives only if some read
  reaches it without an intervening write of the same variable (dead-store elision, part of
  the shared framework, not this project's code) — an uninitialised declaration or a pure
  `out`-mode parameter is therefore *not* a write at all; it relies on the framework
  correctly reporting "no reaching definition" for a read that precedes the first real
  write.

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
- `phi(X)@l6` (the `IfStmt`'s own post-order node, which is the join point per
  `docs/cfg-design.md`'s if-stmt convergence rule) has both as inputs and reads l11's `X`.

**Anchoring trap:** a phi's `Definition.getLocation()` is the *whole* branching construct's
span (`6:4:10:11` here — from `if` to `end if;`), not a single point, because `codeql/ssa`
defines a phi's location as `bb.getLocation()`, and a basic block's location is its first
node's — here, the `IfStmt`'s own join node, whose location is the entire `IfStmt`'s span.
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
  `phi(Total)@l8:16` — the loop header's phi, merging the initial value with the back edge,
  exactly as ordinary SSA loop handling requires. No special casing was needed to get this:
  it falls out of the shared framework once the single static write inside the body
  (`def(Total)@l8`) is on the loop's back-edge path, which it always is.
- `def(I)@l7` (the `for`-loop variable, anchored at the iterable `1 .. 10`; see "For-loop
  variable" below) reads l8's `I`.
- The phi's own location can coincide exactly with a read it reaches (both `8:16` here) when
  the join block's first evaluated node is itself the read — not a bug, just how the two
  independent renderings (`phi(V)@l:c` vs. `nodeKey`) happen to land on the same point.

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
- **No entry write for `B`** (pure `out`): it receives nothing from the caller.
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

`ForLoopVarDecl` and `ForLoopSpec` are both "n/a" in the CFG's coverage appendix — neither
gets a node of its own, so `def(I)` is anchored at the position of the loop's *iterable*
expression (`1 .. 10`) instead. This is a deliberate approximation: SSA does not need one
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

## Recorded limitations (D-023)

- **Record components, array elements, dereferences, `NumberDecl`s and renamings are not
  tracked at all.** `SourceVariable` (D-024) is restricted to whole `ObjectDecl`/`ParamSpec`/
  `ForLoopVarDecl` names. A write through `Rec.Field := ...` or `Arr (I) := ...` is invisible
  to SSA — `getSourceVariable` has no result for the target, so `assignWrite` simply does
  not fire (see `SsaImpl.qll`'s doc comment on `assignWrite`).
- **Exceptions are not covered by a dedicated conformance-test family.** A handler that
  joins values from a partially-executed body is exactly the kind of construct this
  document's method (hand-derive, run, transcribe, verify a wrong annotation fails) should
  be applied to before it is trusted — deferred, not silently assumed correct, and named
  here so it is not mistaken for "checked."
- **Call resolution is D-021/D-022's scope, not wider.** `calleeSpec` resolves functions and
  procedures only (`ClassicSubpDecl`, `BaseSubpBody`); entries, protected operations,
  dispatching calls, access-to-subprogram indirect calls and generic instantiations are all
  unresolved, so an actual passed to an unresolved call's `out`/`in out` parameter is never
  modelled as a write — a documented gap, not a silent one.
- **A pure `out` actual's argument-evaluation reference is modelled as a read**, alongside
  its uncertain write, even though Ada does not actually read an `out` actual's prior value.
  Harmless (reads only consume flow, never introduce it) and deliberate — see
  `outOrInOutActualWrite`'s doc comment in `SsaImpl.qll`.

# Phase 9.2–9.5 execution plan — SSA, dataflow, and the first taint query

> Continues [phase9-plan.md](phase9-plan.md), which set the goal and closed Tasks 9.0/9.1.
> That document says *what* and *why*; this one says *how*, in steps small enough to be
> executed without re-deriving the design. Read phase9-plan.md first — in particular
> "The goal of this phase is cross-procedure analysis" and "What this phase is *not*".

**Audience.** Someone taking this over cold, with no memory of the earlier phases. Every
command below is copy-pasteable and every API name in the "verified" sections was checked
against the installed packs on 2026-09-01, not recalled.

**The one-sentence summary.** The CFG (Phase 7/7.7) and the call graph (Task 9.1) exist;
what is missing is SSA over the CFG, a `DataFlow::Node` model over SSA, cross-procedure
call edges, and one taint query that uses all three.

---

## 0. Where the project stands

| Layer | State |
| --- | --- |
| AST + xref + types | Done (Phases 3–6) |
| CFG | Done, specified in `docs/cfg-design.md`, conformance-tested (Phase 7/7.7) |
| Basic blocks + dominance | Done — `ql/lib/codeql/ada/controlflow/BasicBlocks.qll` |
| Call graph (`ada_body_part`) | Done (Task 9.1, D-021) |
| SSA | Done (Task 9.2) — `docs/ssa-design.md` |
| Local dataflow | Done (Task 9.3) — `docs/dataflow-design.md` |
| Cross-procedure dataflow | Done (Task 9.4) — `docs/dataflow-design.md` |
| **First taint query** | **Not started — Task 9.5** |

---

## 1. Environment

Editing and git happen on Windows. **Anything that builds a database or runs a query
happens in WSL Debian.** Invoke from PowerShell (not the Git-Bash tool, which rewrites
`/bin/...` paths):

```powershell
wsl.exe -d Debian -e bash -c '<command>'
```

The command prelude, used by every step below:

```sh
cd /mnt/c/Users/peter/source/repos/codeql-ada
source /root/lal-venv/bin/activate
export PYTHONPATH=/root/adacore/python LD_LIBRARY_PATH=/root/adacore/lib
export PATH=/root/tools/codeql:$PATH      # CodeQL 2.25.6
```

The three commands you will use constantly:

```sh
# compile one query without running it (fastest feedback loop)
codeql query compile --additional-packs=ql --search-path=extractors ql/debug/PrintSsa.ql

# run one query against a database
codeql query run --database=<db> --additional-packs=ql --search-path=extractors ql/debug/PrintSsa.ql

# the whole test suite
codeql test run ql/test --additional-packs=ql --search-path=extractors
```

**`/tmp` inside WSL does not survive between `wsl.exe` invocations.** Write scratch files
under the repo or under `/root`.

**The databases under `/root` are stale.** `/root/hello-db` and `/root/stats-db` predate
Task 9.1's dbscheme change and now fail with *"The CodeQL database is not compatible with a
QL library referenced by the query"* (confirmed 2026-09-01). This is D-011 working as
designed: pre-1.0 databases are not upgraded. Rebuild any database you need, or work
through `codeql test run`, which builds its own.

---

## 2. Verified findings (spike, 2026-09-01)

These four were established by actually running the toolchain, not by reading. They are the
things that would otherwise cost the implementer a day.

### 2.1 The shared pack versions named in phase9-plan.md are wrong

phase9-plan.md's Global trap 4 names `codeql/ssa` 2.0.30 and `codeql/dataflow` 2.1.10 as
"the floating latest on 2026-08-11". **Those are 2.26.x-era packs and must not be used.**
The versions that ship with CLI 2.25.6, read from `shared/*/qlpack.yml` at the
`codeql-cli/v2.25.6` tag of `github/codeql`:

| Pack | Version at CLI 2.25.6 |
| --- | --- |
| `codeql/util` | 2.0.38 *(already pinned)* |
| `codeql/controlflow` | 2.0.35 *(already pinned)* |
| `codeql/ssa` | **2.0.27** |
| `codeql/typetracking` | **2.0.35** |
| `codeql/dataflow` | **2.1.7** |

`codeql/typetracking` is a transitive dependency of `codeql/dataflow` and is not mentioned
anywhere in phase9-plan.md. It does not go in `qlpack.yml`; `pack install` resolves it.

### 2.2 The wrong version, not the constraint syntax, is what fails — and the right one needs no pre-download

The first cut of this plan (and the corrected Global trap 4 in phase9-plan.md, before this
section existed) claimed a bare version constraint in `qlpack.yml` fails and a
`codeql pack download` pre-step is required. **That was wrong, and disproven by testing the
final versions on a fully empty pack cache.** What actually happens:

Putting `codeql/ssa: 2.0.30` in `ql/lib/qlpack.yml` (paired with the already-pinned
`codeql/controlflow: 2.0.35`) and running `codeql pack install` fails, reproducibly, on a
clean cache:

```
A fatal error occurred: Could not get manifest for codeql/ssa@2.0.31.
(eventual cause: UnrecognizedPropertyException "Unrecognized field \"digest\"
 (class com.semmle.cli2.pack.docker.DockerManifest$Co...")
```

CLI 2.25.6 cannot parse the OCI manifest of packs published by CLI 2.26.x, and asking for
`2.0.30` makes the resolver reach for `2.0.31` — the newest version satisfying the
constraint — which is a 2.26.x-era release. **Putting `codeql/ssa: 2.0.27` instead (the
version actually published alongside `codeql/controlflow` 2.0.35 at the CLI 2.25.6 cut)
resolves and installs cleanly, with a plain `codeql pack install`, on a fully empty pack
cache — no `codeql pack download` pre-step needed.** Verified 2026-09-01 by deleting
`codeql/ssa`, `codeql/dataflow` and `codeql/typetracking` from `/root/.codeql/packages`
entirely and re-running `codeql pack install ql/lib` (and `ql/src`, `ql/test`) fresh; each
installed from network on the first pass with no error, and produced exactly the lock file
in Task 9.2.0 below.

The lesson is simply: **pin `codeql/ssa`/`codeql/dataflow` to the exact versions published
together with the `codeql/controlflow` version already pinned** (section 2.1's table), not
"the floating latest" at any given date. Once that is done, the pack step is ordinary —
nothing needs adding to `ci.yml` or `release.yml` beyond the version bump in
`ql/lib/qlpack.yml` itself.

### 2.3 `CfgImpl::BasicBlocks` does not satisfy `BB::CfgSig`; a four-line adapter does

`codeql.ssa.Ssa::Make` has this signature (verified in
`/root/.codeql/packages/codeql/ssa/2.0.27/codeql/ssa/Ssa.qll:259`):

```ql
module Make<LocationSig Location, BB::CfgSig<Location> Cfg, InputSig<Location, Cfg::BasicBlock> Input>
```

`CfgSig` requires `ControlFlowNode`, `BasicBlock`, `EntryBasicBlock` and `dominatingEdge`.
The shared CFG framework's nested `BasicBlocks` module (`codeql/controlflow`
`Cfg.qll:1441`) exports `BasicBlock`, `dominatingEdge`, `EntryBasicBlock` and friends but
**not `ControlFlowNode`**, so it cannot be passed directly. The adapter below was compiled
successfully (`Done [1/1 comp 7s]`) and is the shape to use:

```ql
private import codeql.ssa.Ssa as SsaLib
private import codeql.controlflow.BasicBlock as BB
private import codeql.ada.ast.internal.Raw
private import codeql.ada.controlflow.internal.ControlFlowGraphImpl as Impl

private module SsaCfg implements BB::CfgSig<Raw::Location> {
  class ControlFlowNode = Impl::CfgImpl::Node;

  class BasicBlock = Impl::CfgImpl::BasicBlocks::BasicBlock;

  class EntryBasicBlock = Impl::CfgImpl::BasicBlocks::EntryBasicBlock;

  predicate dominatingEdge = Impl::CfgImpl::BasicBlocks::dominatingEdge/2;
}

module SsaImpl = SsaLib::Make<Raw::Location, SsaCfg, SsaInput>;
```

**Write `Raw::Location`, not `Location`.** `Location` lives inside `module Raw` in
`Raw.qll`; the bare name does not resolve in a new file and produces a confusing cascade of
`could not resolve type` errors that look like a pack problem but are not.

### 2.4 `ada_xref` resolves to a declaration, not to a defining name

`extractors/ada/tools/extractor.py:198` emits `ada_xref` from Libadalang's
`p_referenced_decl()`, which returns the **`BasicDecl`**. For

```ada
X, Y : Integer;
```

there is one `ObjectDecl` with two `DefiningName`s, and references to both `X` and `Y`
resolve to that single `ObjectDecl`. Using the declaration as `SourceVariable` would merge
`X` and `Y` into one variable and manufacture data flow between them. See Task 9.2.2 for
the resolution; Libadalang does expose `p_referenced_defining_name` (confirmed at
`/root/adacore/python/libadalang/__init__.py:17670`) if the QL-side fix proves insufficient.

---

## 3. Global traps

1. **Do not edit `ControlFlowGraphImpl.qll`** except for a bug the SSA work genuinely
   exposes — and if you do, the change needs a `docs/cfg-design.md` spec update and a
   conformance test, per D-018/D-019.
2. **Do not resolve a call by name text** (D-021). Go through `ada_body_part`, exposed as
   `BasicDecl.getBody()` / `BaseSubpBody.getDeclaration()` in `ql/lib/ada.qll`.
3. **Class and accessor names**: the authority is
   `ql/lib/codeql/ada/ast/internal/Raw.qll` (generated) and `schema/lal-nodes.json`. The
   authority for shared-pack APIs is the pack source under
   `/root/.codeql/packages/codeql/<pack>/<version>/`. **Verify before use; do not trust
   this document** for anything outside section 2.
4. **The dbscheme should not change again in 9.2–9.5.** Task 9.1 already spent the
   database-format bump. If Task 9.2.2 pushes you toward an extractor change, stop and
   raise it (section 6) rather than bundling a second bump silently.
5. **Sources and sinks in the GNAT runtime are matched semantically** (D-026, superseding
   D-015's textual rule, 2026-09-25). Burndown 8.12b extracts `Standard` and the runtime
   units a project refers to directly, so `Ada.Command_Line.Argument` resolves to its
   `SubpDecl` in `a-comlin.ads`, and `GNAT.OS_Lib.Spawn` resolves through the renaming to
   `System.OS_Lib.Spawn` in `s-os_lib.ads`. (8.12b also bumped the dbscheme, adding
   `ada_predefined_file`; point 4 is about 9.2–9.5 themselves.)
6. **Both workflows install packs before compiling** (`.github/workflows/ci.yml:118`,
   `release.yml:116`, looping over `ql/lib ql/src ql/test`). Do not undo that.
7. **Hand-derive every test expectation before transcribing it** (D-017/D-018). If actual
   and expected disagree, decide *which one is wrong* and say so in the commit message.
   Never rewrite an annotation to match the tool.

---

## 4. Decisions to record in `DECISIONS.md`

D-021 (call graph) is already recorded. D-022 (`out`/`in out` parameters are a first-class
flow mechanism) and D-023 (unsoundness is documented, not discovered) are stated in
phase9-plan.md and should be written up when 9.2 starts. Two new ones fall out of the spike:

- **D-024 — `SourceVariable` is a `DefiningName`, disambiguated in QL.** `ada_xref` targets
  a `BasicDecl`, so a multi-identifier declaration is ambiguous. QL narrows a reference to
  the `DefiningName` under the referenced declaration whose name text matches the
  reference's, which is exact because identifiers within one declaration are distinct by
  construction. The extractor is *not* changed; `p_referenced_defining_name` is recorded as
  the fallback if a case is found that text matching cannot settle.
- **D-025 — Shared packs are pinned to the exact version published alongside the
  `codeql/controlflow` version already pinned, not "the current latest".** A version
  chosen by "whatever resolves today" (section 2.2) will eventually be a 2.26.x-era patch
  release whose OCI manifest CLI 2.25.6 cannot parse. Pinning the sibling version from the
  same CLI tag needs no special install step — ordinary `codeql pack install` handles it,
  even from an empty cache.

---

## Task 9.2 — SSA

### 9.2.0 Pack wiring — **done 2026-09-01**

1. Append to the `dependencies:` block of `ql/lib/qlpack.yml`, with a comment matching the
   existing `codeql/controlflow` one (why the version is what it is, and not to bump it):
   ```yaml
     codeql/ssa: 2.0.27
     codeql/dataflow: 2.1.7
   ```
2. `for pack in ql/lib ql/src ql/test; do codeql pack install "$pack" --additional-packs=ql; done`
3. Commit the changed lock files. `ql/lib/codeql-pack.lock.yml` must end up exactly:
   ```yaml
   ---
   lockVersion: 1.0.0
   dependencies:
     codeql/controlflow:
       version: 2.0.35
     codeql/dataflow:
       version: 2.1.7
     codeql/ssa:
       version: 2.0.27
     codeql/typetracking:
       version: 2.0.35
     codeql/util:
       version: 2.0.38
   compiled: false
   ```

No `codeql pack download` step is needed (section 2.2) — a plain `pack install` resolves and
installs all three new packs from a completely empty cache, verified by deleting
`codeql/ssa`, `codeql/dataflow` and `codeql/typetracking` from
`/root/.codeql/packages/codeql/` and re-running the loop above from scratch.

**Acceptance:** the lock file matches the block above and `codeql test run ql/test` is still
green (41/41, confirmed) — adding a dependency did not change any existing result.

**CI note.** Nothing needs to change in `ci.yml` or `release.yml`. Both already loop
`codeql pack install` over `ql/lib ql/src ql/test` (`ci.yml:114-119`,
`release.yml:112-117`) before compiling anything, and — per the finding above — that is
sufficient for the new dependencies on a clean runner exactly as it was for
`codeql/controlflow` in Phase 7.0. (An earlier draft of this plan claimed otherwise and
would have had you add a redundant `codeql pack download` step; that claim did not survive
testing against a genuinely empty cache and has been removed.)

### 9.2.1 The `SsaCfg` adapter

Create `ql/lib/codeql/ada/dataflow/internal/SsaImpl.qll` with the adapter from section 2.3.
The directory is new; the `dataflow/` name matches how other CodeQL languages lay this out
(`codeql.<lang>.dataflow.internal.SsaImpl`).

**Acceptance:** a throwaway `ql/debug` query doing `from SsaImpl::Definition d select d`
compiles. (`ql/debug` needs its own lock file — `codeql pack install ql/debug
--additional-packs=ql`; it is gitignored.)

### 9.2.2 `SourceVariable` — **done 2026-09-01**

Implemented as `SsaSourceVariable` in `SsaImpl.qll` (named that at file scope, not
`SourceVariable`, only to avoid colliding with `SsaInput`'s own required member of that
name, which aliases it — external code uses `SsaImpl::SourceVariable` or this file's
`getSourceVariable`). Per D-024, restricted to those introduced by:

- `Raw::ObjectDecl` — `getIds()` gives the `DefiningNameList`
- `Raw::ParamSpec` — `getIds()`
- `Raw::ForLoopVarDecl` — `getId()`

**Not** in v1, and each to be listed as a documented limitation per D-023: record fields and
components, array elements, dereferences of access types, `NumberDecl` (static — see the
C-5 note in `BURNDOWN.md`), and renamings (`ObjectDecl.getRenamingClause()`; a renaming is
an alias for another object, and treating it as an independent variable is wrong — exclude
it and say so).

Write the reference→variable predicate as its own named, documented predicate. This is where
D-024 lives and it must be readable:

```ql
/**
 * Gets the source variable that `n` refers to.
 *
 * `ada_xref` resolves a name to its `BasicDecl`, not to the specific
 * `DefiningName` within it, so a multi-identifier declaration such as
 * `X, Y : Integer` is ambiguous at that level. Narrowing by name text is exact
 * here because identifiers within one declaration are distinct (D-024).
 */
SourceVariable getSourceVariable(Name n) { ... }
```

**Acceptance:** a `ql/debug` query over a fixture containing `X, Y : Integer;` with reads of
both shows `X` and `Y` as *two* variables, each read mapped to its own. Write the fixture
first and predict the output before running it.

Verified with `ql/debug/PrintSourceVariable.ql` against a scratch database for:

```ada
procedure Test is
   X, Y : Integer;
begin
   X := 1;
   Y := X;
end Test;
```

predicted output — line 4's `X` resolves to variable `X`; line 5's `Y` (target) resolves
to `Y` and its `X` (read) resolves to `X` — matched exactly:

```
| n          | line | variable |
| Identifier | 4    | X        |
| Identifier | 5    | X        |
| Identifier | 5    | Y        |
```

`getReferencedDecl()` used by `getSourceVariable` is `ada.qll`'s `Name` wrapper (imported
via `private import ada`), not the raw `ada_xref` relation directly — reuse over
reimplementation, consistent with the rest of `ql/src`.

### 9.2.3 `variableWrite` / `variableRead` — **done 2026-09-01**

The signature (verified, `Ssa.qll:15-42`):

```ql
predicate variableWrite(BasicBlock bb, int i, SourceVariable v, boolean certain);
predicate variableRead(BasicBlock bb, int i, SourceVariable v, boolean certain);
```

`i` is the index such that `bb.getNode(i)` is the CFG node at which the reference happens.
Implemented as `cfgPos(Raw::AdaNode, BasicBlock, int)` in `SsaImpl.qll`, going from an AST
node to its unique `AstCfgNode` (unique because this project's `Make` instantiation does
not split) and from there to its `(bb, i)`.

**Two things stated below turned out to be wrong** when actually implemented and tested
against fixture databases — both corrected here rather than left standing:

1. **"`ObjectDecl` without initialiser: certain=true"** does not hold up: `ObjectDecl`
   itself never gets a CFG node at all (it is "structural" in the coverage appendix), so
   there is no node position to anchor a write on if there is no initialiser expression to
   provide one. The correct behaviour — confirmed against `codeql/ssa`'s own semantics, see
   finding 2 below — is to emit **no write at all** for an uninitialised local, exactly
   like a pure `out`-mode parameter (next point): the framework correctly reports "no
   reaching definition" for a read that precedes the first real write, which is the
   accurate model of "this value is undefined."
2. **"parameter, on scope entry: certain=true, one write per `ParamSpec` id"** needs a mode
   qualification the original table did not make: a pure `out`-mode formal receives
   *nothing* from the caller at entry (Ada does not pass it an initial value), so it gets
   no entry write, by the same reasoning as point 1. Only `in` (`ModeDefault` included) and
   `in out` formals get one.

**Verified finding 1 — `codeql/ssa` elides a write with no live read, and this is correct,
not a bug to work around.** `Ssa.qll`'s `TWriteDef` newtype is constructed as
`TWriteDef(v, bb, i) { variableWrite(bb, i, v, _) and liveAfterWrite(bb, i, v) }` — a write
that reaches no later read produces **no `Definition` at all**, confirmed empirically with
a fixture where a declared-but-never-read variable's write genuinely disappears from
`SsaImpl::Definition`. This is standard, correct dead-store elision — except it also elides
the **last** write to an `out`/`in out` parameter inside its own callee body, since nothing
*inside that scope* reads it: the reader is the caller, after the call returns. Without
something to represent that, the return-flow value Task 9.4 needs would already be gone
before 9.4 ever runs. The fix: a synthetic `variableRead` at every normal-completion
`AnnotatedExitNode` of the parameter's owning scope, for every `out`/`in out` formal (see
`outOrInOutParamExitRead` in `SsaImpl.qll`). Confirmed with a fixture calling a procedure
with one `in out` and one `out` parameter: before the fix, only the *entry* write to the
`in out` parameter survived (the explicit reassignment inside the body, and the `out`
parameter's only write, were both silently elided); after it, both survive, each read back
by the synthetic exit read.

**Verified finding 2 — `strictcount` silently drops results for an empty range; `count`
does not.** The formal-parameter flattening (`formalIndex`, mapping a `ParamSpec` group's
`i`th name to its overall 0-based position — needed because Ada allows `A, B : Integer` to
declare two formals in one group, and positional argument matching counts names, not
groups) computed "how many other formals precede this one" with `strictcount`. For the
*first* formal, that count is legitimately zero — an empty range — and `strictcount`,
unlike `count`, has **no result** over an empty range rather than reporting `0`. The
practical effect: every `SubpSpec`'s first formal silently vanished from `formalAt`, so
`out`/`in out` mode resolution was wrong for exactly the first parameter of any callable.
Confirmed with a two-parameter procedure (`in out`, `out`): before the fix, only the
*second* parameter's mode resolved at all; after switching to `count`, both did. Recorded
here because this is a natural mistake to repeat — `count`/`strictcount` read as
interchangeable but are not once a range can be empty.

Writes emitted (`SsaImpl.qll`; each anchored per the reasoning in its own doc comment —
read those before changing this table, since several anchors are not the first position
that comes to mind):

| Ada construct | `certain` | Anchored at |
| --- | --- | --- |
| `AssignStmt` target | `true` | the `AssignStmt`'s own post-order node (after both operands) |
| `ObjectDecl` with `getDefaultExpr()` | `true` | the initialiser expression's own node — `ObjectDecl` itself has none |
| `ObjectDecl` without initialiser | *(no write)* | matches an uninitialised out-parameter; see finding 1 |
| `in`/`in out` parameter | `true` | index 0 of the owning scope's `EntryBasicBlock` — `ParamSpec` itself has no node |
| pure `out` parameter | *(no write)* | receives nothing at entry; see the corrected table row above |
| `ForLoopVarDecl` | `true` | the loop's iterable expression's own node — neither it nor `ForLoopSpec` has one; a single static write here dominates every iteration's reads via the back edge, which is all SSA needs (no per-dynamic-iteration write) |
| actual passed to an `out`/`in out` formal | **`false`** | the call's own "effect" node: the wrapping `CallStmt`'s node if there is one, else the `CallExpr`'s own |

Parameter modes come from `ParamSpec.getMode()`, returning `Raw::ModeIn`, `Raw::ModeOut`,
`Raw::ModeInOut` or `Raw::ModeDefault` (`Raw.qll:1660-1676`). **`ModeDefault` means `in`** —
handled explicitly (`receivesArgument`) rather than falling through a default branch.

The `out`/`in out` row needed the callee's `ParamSpec` for the argument position: call →
`ada_xref` (via `Name.getReferencedDecl()`, D-021) → declaration → the declaration's
`SubpSpec` (`getSubpSpecOf`, covering `ClassicSubpDecl` and `BaseSubpBody` — functions and
procedures only; entries and generics are unresolved in v1, D-023). Positional and named
associations (`Foo (X => Y)`, `Raw::ParamAssoc`) both occur and both had to map to the
right formal position (`argFormalIndex`) — verified end-to-end with a fixture using
`Modify (B => Y, A => X)` (arguments in reversed, named order): the `in out` write-back
landed on `X` (bound via `A => X`) and the `out` write-back on `Y` (via `B => Y`), matching
the *names*, not the source-list order.

Reads: a `Name` for which `getSourceVariable/1` has a result, at its CFG node, with
`certain = true`. Excludes the target of an `AssignStmt` (that is a write, not a read) but
**not** an `in out` actual, which is both (the read is the ordinary "any reference is a
read" rule; nothing extra was needed for it). Also includes the synthetic exit reads from
finding 1 above.

**Acceptance, satisfied:** `SsaImpl::Definition` is non-empty on every fixture tried, with
no consistency-query concerns noticed. Verified end-to-end (not just compiled) against four
scratch databases: a two-name declaration with both read (confirms Task 9.2.2's
disambiguation carries through); an unread declaration (confirms dead-store elision is
real, not a bug); a two-parameter (`in out`, `out`) procedure called twice, once
positionally and once named-and-reversed (confirms mode resolution, entry-write
suppression for `out`, and the exit-read fix, all together); and a `for` loop with an
accumulator (confirms the loop-var anchor and produced a phi node for the accumulator at
the loop join, as expected of any correctly-wired SSA instantiation).

**Acceptance:** `SsaImpl::Definition` is non-empty on a fixture, and the shared pack's
`SsaImpl::Consistency` query predicates report nothing.

### 9.2.4 Conformance tests — **done 2026-09-01**

Reused the Phase 7.7 machinery, as planned:

1. `ql/lib/codeql/ada/test/SsaAnnotations.qll` (mirroring `CfgAnnotations.qll`): `defKey`
   renders a `Definition` as `def(<var>)@l:c` (`phi(<var>)@l:c` for a `PhiNode`); `readsKey`/
   `phiInputKey` render the two edge kinds actually checked (below).
2. `ql/test/library/Ssa/SsaConformance.qll` implements the shared `TestSig` with tag `ssa`,
   built on two predicates the base `SsaLib::Make` (not a richer, unused layer) already
   exports — no reimplementation needed: `ssaDefReachesRead(v, def, bb, i)` (a def-use edge,
   at the position of the read) and `phiHasInputFromBlock(phi, inp, bb)` (a phi-input edge).
   Every `Definition` that survives dead-store elision reaches at least one read by
   construction, so checking `reads` edges exhaustively also exhaustively pins down which
   definitions exist, not only where they are read.
3. `ql/debug/SsaAnnotations.ql` — dumps the complete annotation comment per line, mirroring
   `ql/debug/CfgAnnotations.ql`.
4. Four test families under `ql/test/library/Ssa/`, each with a section in the new
   `docs/ssa-design.md`, written and verified in this order: `straight-line`, `if-join`
   (phi at the join), `loop` (back-edge phi, `for`-loop-var anchor), `params-inout` (entry
   writes, the exit-read fix, call-site uncertain writes for both positional and — reversed,
   named — associations).

Three families named in the original outline (`params-in`, `params-out`, `for-loop-var`,
`decl-init`, `multi-id`) are **not** separate test directories, each for a stated reason
recorded in `docs/ssa-design.md`, not silently dropped:

- `for-loop-var` is exercised by the `loop` family's own fixture (a `for` loop already
  contains a loop variable to anchor).
- `decl-init` is exercised by the `straight-line` family's own fixture (an `ObjectDecl` with
  an initialiser is the first line of it).
- `params-in`/`params-out` are one family, `params-inout`: the two modes only make sense
  tested together (a procedure with just one mode cannot show entry-write suppression is
  mode-*specific*, and the exit-read fix needs at least one of each to prove it applies to
  both).
- `multi-id` (the `X, Y : Integer` case, D-024) was verified directly against a scratch
  database in Task 9.2.2 (`getSourceVariable` returns two distinct variables, never merged)
  and is not repeated as an inline-expectations conformance test: the property is entirely
  in `getSourceVariable`, one function call removed from the CFG, and does not exercise the
  def-use graph machinery the other families are checking.

**Deferred, explicitly, not silently:** `exceptions` (a handler joining values from a
partially-executed body) has no test family. It is exactly the kind of construct this
method should be applied to before being trusted, and is named as an open item in
`docs/ssa-design.md`'s "Recorded limitations" rather than assumed correct.

**The anchoring rule caught real mistakes, not just the "everybody gets this wrong"
generic warning it reads as.** A `Definition`'s `getLocation()` is not always a single
point: a phi's location is `bb.getLocation()`, i.e. its defining block's first node's
location, which for a branch join is the *whole branching construct's span* — so its
`reads` annotation belongs on the line where that construct *ends* (`end if;`), not where it
starts (`if`). The parameter entry write hits the identical trap for a different reason:
its location is the *whole scope's* span, so its annotation belongs on the scope's `end`
line. Both were first written wrong (at the construct's start), both failed with a
"Missing result" pointing at the correct line, and both are called out explicitly in
`docs/ssa-design.md` so the next family does not repeat the mistake.

**Acceptance, satisfied:** all four families green, every expectation hand-derived and
checked against `docs/ssa-design.md`'s stated rule before being transcribed from
`ql/debug/SsaAnnotations.ql`'s output. A deliberately wrong annotation
(`straight-line`, an edge's read position changed to a nonexistent line 99) was confirmed to
fail with both a "Missing result" and an "Unexpected result" row before being reverted —
proof the harness fails when it should. Full suite green (45/45: the original 41 plus these
four).

---

## Task 9.3 — Local dataflow — **done 2026-09-25**

*Design as built: `docs/dataflow-design.md`, "Local flow".*

Do **not** build a `DataFlow::Node` type by hand. `codeql/ssa` ships
`SsaImpl::DataFlowIntegration<DfInput>` (verified, `Ssa.qll:1491`), which constructs the
node type and the local step relations for you.

`DataFlowIntegrationInputSig` (verified, `Ssa.qll:1381`) requires:

| Member | Notes |
| --- | --- |
| `class Expr` with `hasCfgNode(BasicBlock bb, int i)` | an Ada `Raw::Expr` at its CFG position |
| `class GuardValue` | `boolean` is enough for v1 |
| `class Guard` with `hasValueBranchEdge` / `valueControlsBranchEdge` | see below |
| `predicate guardDirectlyControlsBlock(Guard, BasicBlock, GuardValue)` | |

Everything else has a `default` and can be left alone: `getARead`, `ssaDefHasSource`,
`allowFlowIntoUncertainDef`, `guardControlsBlock`, `includeWriteDefsInFlowStep`,
`supportBarrierGuardsOnPhiEdges`, `keepAllPhiInputBackEdges`.

**Guards are optional for v1.** They buy barrier-guard support (`if X /= null then ...`),
which no query in this phase needs. Implement `Guard` over
`CfgImpl::BasicBlocks::ConditionBasicBlock`'s last node if it is cheap; otherwise give it an
empty characteristic predicate, set `supportBarrierGuardsOnPhiEdges()` to `none()`, and
record it as a D-023 limitation. **Decide this explicitly and write down which you chose** —
silently stubbing it and forgetting is how a "why does my barrier not work" day gets spent
in Phase 11.

`DataFlowIntegration` exports (verified): `Node`, `ExprNode`, `SsaDefinitionNode`,
`WriteDefSourceNode`, `ExprPostUpdateNode`, `SsaSynthReadNode`, `localFlowStep/4`,
`localMustFlowStep/3`, `BarrierGuard<...>`.

**Acceptance:** a `ql/debug` query showing flow from a local assignment to a later use
across a branch and across a loop. **Keep it in `ql/debug`, do not promote it to `ql/src`,
and do not polish it** — phase9-plan.md is explicit that an intraprocedural taint demo is
not a deliverable and must not be presented as the result.

---

## Task 9.4 — Cross-procedure dataflow — *the point of the phase* — **done 2026-09-25**

*Design as built, the named v1 limitations and corpus measurements:
`docs/dataflow-design.md`, "Cross-procedure flow". Beyond the plan below, it also resolves
prefixed-view (`Obj.Op`) calls, parameterless calls and subprogram renamings; separate
bodies turned out to resolve to their stub, so they stay unresolved as planned.*

Instantiate `codeql/dataflow`. This is the largest single task in the phase and the one
whose estimate is least reliable.

Create `ql/lib/codeql/ada/dataflow/internal/DataFlowImpl.qll` implementing
`codeql.dataflow.DataFlow::InputSig<Raw::Location>`, then

```ql
module AdaDataFlow = DataFlowMake<Raw::Location, AdaDataFlowInput>;
```

The signature has roughly 45 members (`DataFlow.qll:12-394` in
`/root/.codeql/packages/codeql/dataflow/2.1.7/`). Most are satisfiable trivially for v1; the
ones that carry real design are:

**Must be real:**

- `Node` — the union of `DataFlowIntegration::Node` from 9.3 plus parameter, argument and
  return nodes.
- `class DataFlowCallable` — a body (`Raw::BaseSubpBody`, and the other `CfgScope` kinds).
- `class DataFlowCall` — `Raw::CallStmt` / `Raw::CallExpr`.
- `DataFlowCallable viableCallable(DataFlowCall c)` — **this is where 9.1 pays off**:
  call → `ada_xref` → `BasicDecl` → `BasicDecl.getBody()`. Never name text (D-021). A call
  whose declaration has no `ada_body_part` row must produce *no* result, so that the call is
  visibly unresolved rather than silently mis-resolved.
- `ParameterPosition` / `ArgumentPosition` / `parameterMatch` — must handle **named**
  associations (`Foo (X => Y)`, `Raw::ParamAssoc`) as well as positional. Named association
  is idiomatic Ada, not an edge case.
- `isParameterNode` / `isArgumentNode` / `getAnOutNode` / `ReturnKind` — `ReturnKind` needs
  **at least two values**: a normal function return, and one per `out` / `in out` parameter
  position (D-022). A model with only a return-value kind is not usable for Ada.
- `simpleLocalFlowStep` — from 9.3's `localFlowStep`.
- `nodeGetEnclosingCallable` — via `CfgNode.getScope()`.

**Can be minimal for v1, each recorded under D-023:**

- `Content` / `ContentSet` / `ContentApprox` / `readStep` / `storeStep` / `clearsContent` /
  `expectsContent` — no field sensitivity in v1; record types and array elements are out of
  scope.
- `DataFlowType` / `compatibleTypes` / `typeStrongerThan` — a single unit type is acceptable
  to start; `ada_expr_type` exists if type pruning is wanted later.
- `LambdaCallKind` / `lambdaCreation` / `lambdaCall` / `additionalLambdaFlowStep` — none;
  access-to-subprogram is out of scope.
- `isUnreachableInCall` / `NodeRegion`, `jumpStep`, `CastNode`, `PostUpdateNode`,
  `nodeIsHidden`, `knownSourceModel` / `knownSinkModel`, `DataFlowSecondLevelScope`.

Explicitly unresolved in v1 — each gets a named limitation in a new
`docs/dataflow-design.md` **and**, where expressible, a test pinning the current behaviour:
dispatching calls on tagged types, access-to-subprogram indirect calls, calls into generic
instantiations, task entry calls, and separate (`is separate`) bodies.

**Acceptance — the criterion that matters in the whole phase.** Flow demonstrated across
**at least two call frames, in both directions**: a value passed down through a parameter,
and a result returned up through an `out` parameter. Hand-written tests with inline
expectations. If this is not met, nothing downstream is worth building.

---

## Task 9.5 — First end-to-end taint query

One query, with a displayed path, that is genuinely cross-procedure.

- Instantiate `TaintTracking` from `codeql/dataflow` over the 9.4 model.
- Source: `Ada.Command_Line.Argument` — a function result, matched **semantically**:
  `call.getName().getReferencedDecl().(BasicDecl).getUltimateDecl().(BasicDecl)
  .hasQualifiedName("Ada.Command_Line.Argument")` (8.12c; D-026). That covers `use`
  clauses and renamings; `isTextIoOp` in `OpenWithoutClose.ql` is the worked example.
- Sink: `GNAT.OS_Lib.Spawn` (command execution) is the obvious first choice. It resolves
  through `package GNAT.OS_Lib renames System.OS_Lib` to `System.OS_Lib.Spawn`, so
  `hasQualifiedName("System.OS_Lib.Spawn")` catches both spellings (phase8.12-plan.md
  §1.7). `Spawn` is overloaded; decide whether every overload is a sink. Test both
  spellings, and include a fixture assertion that fails if the runtime does not resolve,
  since without a GNAT runtime the query would go silently blind (D-026).
- Report only `fromSource()` elements, like every query (D-026).
- `@kind path-problem`, so the path is displayed. That is the visible payoff and the reason
  to have built the rest.
- **The test must route the tainted value through at least one intermediate subprogram**, so
  the result is not reproducible by any intraprocedural tool. A test that passes
  intraprocedurally has not tested the thing this phase was built for.

**Acceptance:** green test; the reported path names each hop; `codeql database analyze` over
the corpus stays clean — no crashes, no timeouts.

---

## Task 9.6 — Corpus validation

Unchanged from phase9-plan.md. Run over all five pinned corpus projects
(`python3 scripts/corpus_regression.py --out corpus-report.json`). Expect the project's
first real false positives — dataflow surfaces them where syntactic rules did not. Record
counts, triage a sample by hand, and write the findings up. **Where a false positive is
caused by a documented v1 unsoundness, say so rather than tuning it away** (D-023).

---

## 5. Order, and where to stop

```
9.2.0 packs -> 9.2.1 adapter -> 9.2.2 SourceVariable -> 9.2.3 writes/reads -> 9.2.4 conformance
      -> 9.3 local flow -> 9.4 cross-procedure -> 9.5 taint query -> 9.6 corpus
```

Each numbered step is a commit. Do not batch them: 9.2.3 and 9.4 are both places where a
wrong early decision is cheap to fix now and expensive to unwind later.

The off-ramps from phase9-plan.md still stand. **After 9.4** is a legitimate finish — the
capability proven and documented, without a source/sink catalogue. The off-ramp *not* to
take is stopping after 9.3 and presenting the intraprocedural demo as the result.

---

## 6. Stop and ask

Raise these rather than deciding alone; each one changes the shape of the phase.

1. **Task 9.2.2 turns out to need `p_referenced_defining_name`** — that is, a case is found
   where name-text narrowing within a declaration is not exact. That means a second dbscheme
   change and a second database-format bump, against Global trap 4.
2. **The CFG needs a change** to make SSA correct (Global trap 1). Say what is wrong and why
   before touching `ControlFlowGraphImpl.qll`.
3. **`viableCallable` resolves a large fraction of calls to nothing** on the corpus — that
   would mean `ada_body_part` coverage is worse than Task 9.1's tests suggested, and 9.4's
   acceptance criterion is unreachable without more extraction work.
4. **Task 9.4 exceeds its budget.** It is the least predictable task here; better to report a
   partial `InputSig` with a list of what is stubbed than to keep going quietly.

---

## Definition of done

A taint result, with a displayed path, that crosses at least two procedure boundaries in
real Ada — and a written statement of exactly what the analysis does not see.

# Phase 9 work plan — SSA, dataflow, and cross-procedure analysis

**The goal of this phase is cross-procedure analysis.** Everything before it is plumbing.

That framing is deliberate and should govern every trade-off below. Ada already has good
tools for local, syntactic questions — GNATcheck has 211 rules, and D-020 records why
competing there is not viable. What a deductive database gives that those tools do not is
the ability to answer questions *across* procedure boundaries: does attacker-controlled
data reach this sink, through however many frames, and by what path. That capability is
the entire reason to build this phase, so the plan is ordered to reach it as directly as
honesty allows.

The consequence for scope: **an intraprocedural taint demo is not a deliverable.** It is a
checkpoint on the way, worth building only because you cannot get cross-procedure flow
without it. Do not spend effort polishing it, and do not show it as the result.

---

## What this phase is *not*

- Not a security suite. One convincing end-to-end query is the target (Task 9.5); a
  catalogue of sources and sinks is Phase 11 work.
- Not sound. Access types, dispatching calls, generics and tasking are all out of scope for
  v1 and must be *documented* as unsound rather than quietly missing — the same discipline
  D-019 established for the CFG.
- Not a rewrite of the CFG. Phase 7 and 7.7 delivered a specified, machine-checked CFG.
  This phase consumes it. If you find yourself editing `ControlFlowGraphImpl.qll` for
  anything other than a bug the SSA work exposes, stop and reconsider.

---

## The finding that shapes everything: the call graph does not exist yet

Cross-procedure analysis needs to answer "which body does this call run?". **The database
cannot currently answer that**, and this is the single largest risk in the phase.

The only semantic relations are `ada_xref` (name → declaration), `ada_expr_type`, and
`ada_generic_instantiation`. There is **no declaration↔body relation**. In real Ada — where
a package spec in a `.ads` declares the subprogram and the `.adb` defines it — a call
resolves via `ada_xref` to the spec's `SubpDecl`, and nothing connects that to the
`SubpBody`. Phase 8 hit exactly this (see the burndown notes for 8.9/8.10) and worked around
it with name-text plus enclosing-region pairing, which is fragile and **breaks outright for
library-level subprograms**, each of which sits in its own `CompilationUnit`.

Name-text pairing is not salvageable here anyway, because Ada overloads: two subprograms
may share a name and differ only in profile. A call graph built on text would silently mix
them, and every dataflow result computed on top would be wrong in a way that is very hard
to see.

**Verified fix (2026-08-11):** Libadalang resolves this directly. On a spec/body pair,
`BasicDecl.p_body_part` (equivalently `p_body_part_for_decl`, `p_next_part_for_decl`)
returns the defining `SubpBody` — and for an expression-function completion, the
`ExprFunction` — across compilation units. So the fix is an extractor change to emit it,
not an analysis problem.

**This makes Phase 9 the first phase since Phase 3 to change the dbscheme.** Phase 7 was
pure QL by design; this is not. Plan for a database-format bump and the consequences in
D-011: pre-1.0 databases are not upgraded, so every consumer rebuilds.

---

## Decisions this phase assumes

Record these in `DECISIONS.md` when work starts; they are stated here so a later reader
knows they were chosen, not stumbled into.

- **D-021 — The call graph is extracted, never inferred.** A new relation maps a
  declaration to its completion, emitted from Libadalang's `p_body_part`. QL must never
  fall back to name-text pairing for call resolution; overloading makes that unsound. If
  the relation has no row, the call is *unresolved* and dataflow stops there, visibly.
- **D-022 — `out`/`in out` parameters are a first-class flow mechanism.** In Ada a
  procedure returning results through parameters is idiomatic and common, not an edge case.
  Any dataflow model that handles only return values is not usable for Ada. The shared SSA
  pack anticipates this: its `variableWrite`/`variableRead` carry a `certain` flag whose
  documentation cites exactly this case.
- **D-023 — Unsoundness is documented, not discovered.** Dispatching calls, access-to-
  subprogram, generic instantiation bodies, and task entry calls are unresolved in v1. Each
  gets a named limitation in the phase's design doc and, where it can be expressed, a test.

---

## Environment and global traps

Environment (WSL invocation, test commands) is unchanged — see the "Global traps" section
of [phase7.7-plan.md](phase7.7-plan.md), and note `/tmp` inside WSL does not survive
between invocations.

1. **The dbscheme changes in this phase.** After editing `ada.dbscheme` you must
   regenerate `ql/lib/ada.dbscheme.stats` and update the generator — the opposite of the
   Phase 7 rule. Do it in Task 9.1 and not incrementally afterwards.
2. **Never resolve a call by name text** (D-021).
3. ~~**Sources and sinks in the runtime must be matched textually** (D-015).~~ *Superseded
   2026-09-25 by D-026:* runtime entities the project refers to are extracted as predefined
   pseudo-sources and match semantically; see `docs/phase9.2-plan.md` Task 9.5.
4. **Pin the shared packs to CLI 2.25.6**, exactly as Task 7.0 did for `codeql/controlflow`.
   *Corrected 2026-09-01:* the versions this trap originally named (`codeql/ssa` 2.0.30 and
   `codeql/dataflow` 2.1.10, the floating latest on 2026-08-11) are **2.26.x-era packs and
   must not be used**. The versions at the `codeql-cli/v2.25.6` tag of `github/codeql` are
   `codeql/ssa` **2.0.27**, `codeql/dataflow` **2.1.7** and `codeql/typetracking` **2.0.35**
   (a transitive dependency of `dataflow` that this plan originally missed). With those
   exact versions, ordinary `codeql pack install` resolves cleanly even from an empty pack
   cache — no extra download step needed. See [phase9.2-plan.md](phase9.2-plan.md) §2.1–2.2
   for the failure mode this pin avoids, and D-025.
5. **Both workflows install packs before compiling** — do not undo that.

---

## Tasks

Order matters: **9.1 first**, because everything cross-procedure is blocked on it, and
because it is the only task that can invalidate databases.

### 9.1 — Extract the call graph

Emit a declaration→completion relation.

1. Add to `ada.dbscheme`:
   ```
   ada_body_part(
     unique int decl: @ada_basic_decl ref,
     int body: @ada_basic_decl ref
   );
   ```
   Confirm the column types against `Raw.qll`; a `SubpBody` and an `ExprFunction` are both
   `BasicDecl`, and both occur as completions.
2. Emit it in `extractors/ada/tools/extractor.py` from `p_body_part`, guarded like the
   other semantic relations (property errors are non-fatal and counted).
3. Regenerate `ada.dbscheme.stats`; update `generator/gen.py` if the relation needs a QL
   accessor.
4. Expose it in the QL library: `BasicDecl.getBody()` / `BaseSubpBody.getDeclaration()`.
5. **Test-first, per the established discipline** (Phase 7 plan, Global trap 7): write the
   `.ads`/`.adb` pair *first*, dump the relation, and confirm what it resolves to before
   building anything on it. Cover: spec+body in separate units; expression-function
   completion; body with no separate spec; two overloads with the same name and different
   profiles; a nested subprogram; a library-level subprogram (the case Phase 8's textual
   pairing broke on).

**Acceptance:** the overload case resolves each declaration to its *own* body, proving the
relation is doing something name-text pairing cannot. Full suite green; corpus regression
green; `DeadLocalSubprogram.ql` and `DirectRecursion.ql` reviewed for whether their
documented textual approximations can now be replaced (do not necessarily change them —
just record the answer).

### 9.2 — SSA

> **Tasks 9.2–9.5 have a step-by-step execution plan in
> [phase9.2-plan.md](phase9.2-plan.md)**, written 2026-09-01 for an implementer taking the
> work over cold. It supersedes the outline below wherever the two differ, and records four
> findings verified against the toolchain — including the corrected pack versions (Global
> trap 4 above) and the fact that `SourceVariable` cannot be the `BasicDecl` that
> `ada_xref` resolves to.

Instantiate `codeql/ssa` over the Phase 7 CFG and `BasicBlocks`. The input signature is
small — `SourceVariable` plus `variableWrite`/`variableRead` positioned in a basic block —
because `BasicBlocks` already exists.

- `SourceVariable`: `ObjectDecl` and `ParamSpec` for v1. Not record fields, not array
  elements, not dereferences.
- Writes: assignment targets; object-declaration initialisers (now in the CFG, see the C-1
  fix); parameter initialisation on entry; and **an actual passed to an `out`/`in out`
  parameter, marked uncertain** (D-022).
- Reads: an identifier resolving to the variable, at its CFG position.

**Build the conformance test the same way the CFG's was** — `ql/debug/PrintSsa.ql` plus
inline expectations via the existing harness and `scripts/annotate_cfg_test.py`. This is
the main reason SSA should be cheap here: the machinery from Phase 7.7 is reusable
essentially as-is, and it is what keeps the def-use relation honest.

**Acceptance:** conformance tests for straight-line code, branches (phi nodes at joins),
loops (back-edge phis), and out-parameter writes. Every expectation hand-derived before
transcription, per D-017/D-018.

### 9.3 — Local dataflow

The `DataFlow::Node` model and local flow steps: SSA def → use, expression sub-flow,
assignment, parameter/return within a single body.

This is the checkpoint where an intraprocedural taint query becomes possible. **Do not
stop here and do not polish it.** Write one throwaway query to prove local flow works, keep
it in `ql/debug/`, and move on.

**Acceptance:** a `ql/debug` query showing flow from a local assignment to a later use
across a branch and a loop.

### 9.4 — Cross-procedure dataflow — *the point of the phase*

Instantiate `codeql/dataflow`. This is where the phase's value is, and where the estimate
is least reliable.

- `DataFlowCallable` = a body; `DataFlowCall` = a `CallExpr`/`CallStmt`.
- **Call resolution goes through 9.1's relation**: call → `ada_xref` → declaration →
  `ada_body_part` → body. Unresolved calls must be visibly unresolved.
- Argument→parameter flow, positional and **named** (`Foo (X => Y)` is idiomatic Ada and
  the association carries the mapping).
- Return-value flow out of functions.
- **`out`/`in out` parameter flow back to the actual** (D-022). Treat this as equal in
  importance to return flow, not as an extension.
- Default parameter expressions.

Explicitly unresolved in v1, each documented and, where possible, given a test that pins
the current behaviour: dispatching calls on tagged types, access-to-subprogram indirect
calls, calls into generic instantiations, task entry calls.

**Acceptance:** flow demonstrated across **at least two call frames**, in both directions —
a value passed down through a parameter and a result returned up through an `out`
parameter — on hand-written tests with inline expectations. This is the acceptance
criterion that matters in the whole phase; if it is not met, nothing downstream is worth
building.

### 9.5 — First end-to-end taint query

One query, with a path, that is genuinely cross-procedure.

- Source: `Ada.Command_Line.Argument` (a function result — matched semantically per D-026;
  originally textually per D-015).
- Sink: a command-execution or file-path sink; `GNAT.OS_Lib.Spawn` is the obvious first
  choice.
- The test must route the tainted value **through at least one intermediate subprogram**,
  so the result is not reproducible by any intraprocedural tool.
- `@kind path-problem` so the path is displayed; this is the visible payoff and the reason
  to have built the rest.

**Acceptance:** green test; the reported path names each hop; `codeql database analyze` over
the corpus stays clean.

### 9.6 — Corpus validation

Run over all five pinned corpus projects. Expect the first real false positives of the
project — dataflow surfaces them where syntactic rules did not. Record counts, triage a
sample by hand, and write the findings up. Where a false positive is caused by a documented
v1 unsoundness, say so rather than tuning it away.

**Acceptance:** corpus regression green; a written triage of a sample of results; any
newly-discovered limitation recorded per D-023.

---

## Definition of done

A taint result, with a displayed path, that crosses at least two procedure boundaries in
real Ada — and a written statement of exactly what the analysis does not see.

## When to stop instead

This phase is the largest remaining commitment in the project, and D-020 leaves open
whether the audience justifies it. Two honest off-ramps:

- **After 9.1.** The call-graph relation is independently valuable: it removes the textual
  approximations in `DeadLocalSubprogram` and `DirectRecursion`, and it is the prerequisite
  for *any* future interprocedural work, including a Joern frontend (see the D-020
  appendix — a CPG frontend needs the same edge). Small, self-contained, and it leaves the
  project better whatever happens next.
- **After 9.4.** If cross-procedure flow works but building a real source/sink catalogue
  looks like more than you want, stop with the capability proven and documented. That is a
  legitimate finish.

The off-ramp *not* to take is stopping after 9.3 and presenting the intraprocedural demo as
the result — it is the one outcome that costs real effort and demonstrates nothing that
existing Ada tools cannot already do.

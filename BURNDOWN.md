# CodeQL for Ada — Pre-Coding Burndown

Goal: a CodeQL language pack for Ada — extractor (built on Libadalang), database schema,
QL standard library, and an initial query suite — usable via `codeql database create --language=ada`.

---

## Resume here (2026-10-03) — Phase 9 status

**Done:** 9.1 call graph, 9.2 SSA, 9.3 local dataflow, 9.4 cross-procedure dataflow,
9.5 the first taint query, and burndown 8.12a–c (the GNAT runtime resolves semantically,
D-026). Cross-procedure flow works across two or more call frames in both directions:
down through parameters, up through function results and through `out` parameters.
`ada/command-line-injection` (`ql/src/queries/CommandLineInjection.ql`) is a
`path-problem` query from `Ada.Command_Line.Argument` to the `Program_Name`/`Args` of
every `Spawn` and `Non_Blocking_Spawn` overload (and more, below), built on the public
`codeql.ada.dataflow.DataFlow` / `TaintTracking` modules. The design, the taint steps, the
named v1 limitations and the corpus measurements are in
[docs/dataflow-design.md](docs/dataflow-design.md), and the step-by-step plan is
[docs/phase9.2-plan.md](docs/phase9.2-plan.md). Full suite green (54/54). Task 9.5 found
and fixed two CFG gaps: `&` operands after the first, and membership alternatives
(`X in A | B`), had no node (97d1c5e, bbdbdeb). Sinks now also cover `GNAT.Expect` and
imported C `system` / `popen` / `exec*`, as extensible classes in
`codeql/ada/security/CommandInjection.qll`; `docs/query-writing.md` shows how to write
one's own source, sink and barrier. For query authors: `docs/ast-reference.md` (Ada source to AST, built
from pinned test output), a refreshed `docs/query-writing.md` with a "start here" path, and
AST printing (VS Code "View AST" via `ql/lib/ide-contextual-queries/printAst.ql`, text via
`ql/lib/tools/PrintAst.ql`). View AST has not been tried in VS Code itself yet.

**Task 9.6 done (2026-10-03):** [docs/phase9.6-corpus-triage.md](docs/phase9.6-corpus-triage.md).
About 70% of the 11,520 corpus results trace to four causes. The dataflow engine produced
no false positive in the 23 exploratory paths. Per-query counts are now recorded
(`scripts/corpus_queries.py`, `scripts/corpus_query_baseline.json`).

**Next: the fix list in that report, awaiting a decision.** Its section "Defects and
limitations found" lists, in order of payoff:
- ~~C, E~~ **done**: unused-local 3,733 -> 199, unused-parameter 3,559 -> 73,
  dead-local-subprogram 777 -> 41 (corpus total 11,520 -> 3,764).
- A, B, D: CFG changes (pragmas in statement lists, `for` over a subtype indication,
  `No_Return` calls; about 1,400 false positives, and code after pragmas becomes visible
  to SSA and data flow). These need approval first, per section 6.2 of docs/phase9.2-plan.md.
- F: user-defined operators as calls in data flow.
- H: a narrower credential heuristic.

**Open items, deliberately not started** (details in `docs/dataflow-design.md`,
"Named v1 limitations"):

- **Missing `ada_body_part` rows.** 1–4% of calls into project code reach a declaration
  that has a body but no row (for example `Alire.Put_Info`), so those calls stay
  unresolved. This is an extractor coverage gap from 9.1 and is not diagnosed yet. It is
  the only open item that is a defect rather than a scope choice, and is worth doing
  soon whatever 9.6 shows.
- **Multi-name declarations have no qualified name.** `A, B : Integer` and `X, Y : T`
  components resolve, but `ada_qualified_name` has no row for them (Libadalang computes the
  name per declaration), so `hasQualifiedName` cannot match them. Fixing it means keying the
  qualified name by defining name: a dbscheme change. Low impact today: no shipped query
  matches an object by qualified name.
- **Small limitations (hours each):** protected operations, default parameter values,
  extended `return` statements, and separate bodies. For separate bodies the extractor
  could emit a stub-to-body row; that needs no schema change, only rebuilt databases.
- **Large limitations (each a project of its own):** dispatching calls,
  access-to-subprogram calls, calls into generic instances.
- **Kept on purpose:** an `out`/`in out` write-back is uncertain, so the caller's old
  value survives the call (D-022).

**Environment notes:** see `docs/phase9.2-plan.md` §1. Corpus databases are in
`/root/.cache/codeql-ada-corpus/*-db`, and `ql/debug/DataFlowConsistency.ql` checks the
dataflow model against any database. If you edit files with Windows tools, check for
CRLF line endings (`grep -c $'\r'`).

---

## Where things stand (2026-08-10) — read this first if resuming

**The analyzer works and is finished as a v1.** Extractor, dbscheme, QL library, 24 rules,
a control-flow graph that is specified construct-by-construct and enforced by conformance
tests, packaging, release automation, and CI. 40 tests green; the full pack analyzes the
1,718-file gpr2 corpus cleanly. Nothing is half-built.

**It is not published.** No tag has been cut, so `docs/ci-integration.md` cannot be
followed: its download URLs 404 and `codeql pack download` has nothing to serve. Everything
needed to cut `v0.1.0` is done and verified locally — see [docs/releasing.md](docs/releasing.md).
Note that on a **private** repository the Release asset and the GHCR packages are private
too, so a tag makes the artifacts usable by their owner but does not make the project
adoptable by anyone else; that needs the repo or at least the packages made public.

**The strategic question is answered and it constrains what is worth building** — see
[D-020](DECISIONS.md). Briefly: AdaCore's GNATcheck has 211 rules on the same Libadalang
frontend, with certification material we cannot match, so competing on Ada coding rules is
not viable. GNATcheck has *no* taint analysis, so the differentiated value is Phase 9
(dataflow) plus platform integration — for an audience that is real but small. **Whether
that audience justifies Phase 9's cost is deliberately left undecided.**

### If you are picking this up again, the live options are

| Option | Cost | Value |
|---|---|---|
| Cross-check the 7–9 rules overlapping GNATcheck | small | Read AdaCore's LKQL rule sources (GPLv3 — read, never copy) and confirm our scope matches theirs. Catches subtly-wrong edge cases. |
| Phase 9 — SSA → dataflow → taint | large, needs its own plan (9.0) | The only genuinely differentiated capability. Gated on the undecided question in D-020. |

### Working notes for whoever resumes

- **Environment recipe** (WSL invocation, test commands, traps): see the "Global traps"
  section of [docs/phase7.7-plan.md](docs/phase7.7-plan.md). Windows-side PowerShell must
  invoke WSL directly — the Git-Bash tool rewrites `/bin/...` paths and breaks it. Note
  `/tmp` inside WSL does not survive between invocations; use a path under `/root`.
- **Never bump the CodeQL CLI or Libadalang pins casually** (D-012). Version skew presents
  as "the CodeQL database is not compatible with a QL library", which reads like a query
  bug and is not one.
- **CI skips documentation-only pushes.** The ignore list in `ci.yml` is explicit rather
  than a glob, because `docs/cfg-design.md` is verified by the coverage check and must
  still trigger a run. Do not collapse it.
- **Both workflows now install QL packs before compiling anything.** A committed lock file
  pins a version but does not put the pack on disk; only a clean checkout notices. This bit
  us twice — `ci.yml` after Phase 7.0, and latently in `release.yml`.

---

Status of the field (verified 2026-07-02):

- **No existing Ada CodeQL extractor** exists publicly. This is greenfield.
- **Libadalang (LAL)** is Apache-2.0 (relicensed from GPL), actively maintained by AdaCore,
  parses 100% of Ada 2022, and provides name resolution ("xref") driven by GNAT project
  files (GPR). APIs: Ada, Python (3.11+), C, plus experimental Java and OCaml.
- **CodeQL officially supports third-party extractors** via extractor packs
  (`codeql-extractor.yml` + `--search-path`), even though there is no public spec for
  dbscheme syntax or extractor authoring. Community extractors (IaC/Bicep, Solidity, QL-for-QL,
  Ruby) are the working documentation.

---

## Phase 0 — Decisions & groundwork (blocks everything)

> **Status 2026-07-02: all Phase 0 decisions made** — recorded as D-001…D-008 in
> [DECISIONS.md](DECISIONS.md). Summary: MIT open source; Python prototype extractor;
> build-less extraction from GPR; generated dbscheme/QL from LAL introspection;
> v1 = AST + xref + types; Ada 2012/2022; language id `ada`.

- [x] **0.1 Legal/licensing review & commercial model.** (Researched 2026-07-02.)
  - Our own code (extractor, dbscheme, QL packs, queries) is ours to license/sell freely.
    `github/codeql` libraries are MIT; Libadalang is Apache-2.0 — both fine in a commercial
    product with attribution.
  - The CodeQL CLI binary is proprietary. Its terms prohibit redistributing/bundling it and
    offering it as a hosted service → **no turnkey product or SaaS containing CodeQL**.
    Only viable commercial model: "bring your own CodeQL" — customer obtains the CLI under
    their own terms.
  - Customers analyzing proprietary code need GitHub Advanced Security / Code Security
    (~$30/committer/mo) or a negotiated GitHub license. Market-fit risk: Ada shops
    (defense/avionics, air-gapped) are often not GitHub Enterprise customers — validate the
    intersection before committing to a paid product.
  - Free-CLI terms cover testing **OSI-licensed** queries → open-sourcing the packs keeps our
    own dev/test use compliant; a closed-source pack likely requires us to hold a paid license
    during development.
  - Recommended: MIT the extractor + packs; monetize support/custom queries/services.
    Contact GitHub partner/BD team early. Get formal legal review of current terms.

- [x] **0.2 Pick the extractor implementation language.** *Decided — see D-002 (Python
  prototype).* Options, in rough order of fit:

  | Option | Pros | Cons |
  |---|---|---|
  | **Python (LAL Python API)** | Fastest to prototype; introspection API; playground | Ships a Python runtime with the extractor pack; slower on big codebases |
  | **Ada (LAL native API)** | Single static binary; fastest; "dogfooding" | Slower iteration; contributors need GNAT |
  | **Rust/C via LAL C API** | Matches modern CodeQL extractors (Ruby/QL are Rust) | Hand-written bindings; least documented path |

  Recommendation: **Python for the prototype**, decide Ada vs. keep-Python for production
  after measuring extraction speed on a large real project (e.g. GNAT sources themselves).

- [x] **0.3 Decide extraction model: build-less (recommended) vs. build-traced.**
  *Decided — see D-003 (build-less).*
  Ada has no preprocessor games like C; LAL resolves semantics from a GPR project file
  without running the compiler. Plan: build-less extractor that (a) uses a GPR file when
  present, (b) falls back to LAL's auto unit provider over all `.ads/.adb` files.
  This avoids CodeQL's compiler-tracing machinery entirely — a large complexity saving.

- [x] **0.4 Decide dbscheme generation strategy.** *Decided — see D-004 (generated from
  Libadalang/Langkit introspection).*
  Langkit (LAL's generator) exposes the full node-kind hierarchy via introspection.
  Decide: hand-write the dbscheme, or **generate dbscheme + TRAP emitter + QL AST classes
  from LAL introspection** (the Ruby/QL extractors do exactly this from tree-sitter grammars —
  their Rust generator is the model). Recommendation: generate. Keeps ~400 node kinds in sync
  automatically and follows LAL upgrades.

- [x] **0.5 Scope the v1 semantic depth.** *Decided — see D-005 (AST + xref + types in
  v1; CFG/dataflow later in QL, now Phases 7/9).* Syntax-only gets you linting; security
  queries need:
  - name resolution (definition/use links) — LAL provides via `p_referenced_decl` etc.
  - type of each expression — LAL provides
  - control flow graph — **not** provided by LAL; must be built (extractor-side or QL-side)
  - data flow — built in QL on top of CFG using CodeQL's shared dataflow library
  Decide the v1 cut line (suggested: AST + xref + types in the DB; CFG/DFG in QL later).

- [x] **0.6 Define target Ada dialect & ecosystem scope.** *Decided — see D-006 (Ada
  2012/2022, GPR-first, SPARK is just Ada, Alire test corpus).* Ada 2012/2022, SPARK subset?
  GPR-based projects only, or bare source trees too? Alire crates as test corpus?

- [x] **0.7 Name and pack identifiers.** *Decided — see D-007 (language id `ada`) and D-009
  (final pack scope `peter-villadsen/`, superseding D-007's placeholder).* e.g. language id
  `ada`, packs `<org>/ada-all` (library), `<org>/ada-queries`. Check no collisions on the
  pack registry.

## Phase 1 — Spikes (throwaway code allowed; time-boxed)

- [x] **1.1 Toolchain spike.** *Done 2026-07-02.* CodeQL CLI v2.25.6 on Windows
  (`C:\Users\peter\tools\codeql`). Libadalang: no prebuilt packages exist anywhere
  (PyPI/Debian/Fedora all verified empty) — built from source in WSL **Debian 13**
  (not Ubuntu) via `scripts/build-libadalang.sh`. ~10 failure/fix cycles, all encoded
  in the script; key traps: undocumented deps (VSS, prettier-ada, liblktlang-from-
  langkit-bootstrap, libgpr, gnatcoll_projects, gpr2, gprconfig_kb), version pinning
  (langkit/LAL master + gprbuild v25.0.0 + gpr2 v26.0.0 — masters need GNAT ≥25,
  Debian has FSF GNAT 14.2), and gpr2's incomplete source install. Result verified:
  `import libadalang` parses `tests/hello/hello.adb` cleanly.
  Env inside WSL: `source /root/lal-venv/bin/activate; export PYTHONPATH=/root/adacore/python
  LD_LIBRARY_PATH=/root/adacore/lib`.
- [x] **1.2 "Hello TRAP" spike.** *Done 2026-07-02.* Full pipeline proven on Windows:
  `extractors/ada` pack (stub Python extractor) → `codeql database create --language=ada
  --build-mode=none` → `ql/lib` + `ql/src` packs → `codeql query run` returns the extracted
  compilation units. Learnings recorded below (1.2a).
  - **1.2a Learnings:** (1) extractor pack dir name must match language id; discovered via
    `--search-path` pointing at the *parent* dir. (2) With `build_modes: [none]` the CLI runs
    `tools/autobuild.cmd|.sh` with cwd = source root and `CODEQL_EXTRACTOR_ADA_{ROOT,TRAP_DIR,
    SOURCE_ARCHIVE_DIR,...}` env vars. (3) TRAP labels are file-local; `@"key"` strings give
    global identity. (4) The QL library pack needs `ada.dbscheme.stats` next to its dbscheme
    (`codeql dataset measure` generates it) or query compilation fails. (5) Local pack
    resolution works with `--additional-packs=ql`.
- [x] **1.3 LAL introspection spike.** *Done 2026-07-02.* `scripts/dump_lal_nodes.py`
  produced `schema/lal-nodes.json`: **405 node classes, 333 concrete**, with base-class
  links, list/token-node flags, and per-class syntax fields — sufficient input for the
  dbscheme/TRAP/QL generator (D-004).
- [x] **1.4 Study reference extractors.** *Done 2026-07-02.* Ruby's generated dbscheme
  conventions extracted and mapped onto Libadalang's node model in
  [docs/dbscheme-conventions.md](docs/dbscheme-conventions.md) — includes the standard
  prelude tables, `_def`/optional-field/child-table patterns, union types from the LAL
  class hierarchy, our added semantic layer (xref/types), and the Phase 2 generator plan.
  The remaining item (study `codeql-extractor-iac`'s release-tarball layout) was done
  2026-07-03; findings folded into [docs/phase6-plan.md](docs/phase6-plan.md).
- [x] **1.5 Xref/perf spike.** *Done 2026-07-02* via `scripts/spike_nameres.py`:
  - gpr2 (345 files): parse 749 files/s; nameres 280,898 names at **3,758 names/s**,
    80.2% resolved, **0 errors** (no PropertyError crashes at all).
  - AdaSAT (16 files): 4,703 names/s, 0 errors.
  - Extrapolation: ~0.25 s/file single-threaded nameres → a 10k-file codebase ≈ 40 min
    on one core; extraction parallelizes per compilation unit (multi-process — LAL
    contexts are not thread-safe). No error policy needed beyond logging: failures are
    "resolves to null", not exceptions. The ~20% unresolved is mostly defining
    occurrences/pragma names the spike didn't filter; refine in the real extractor.

## Phase 2 — Database schema (design doc before code)

> **Status 2026-07-02: generator built and validated.** `generator/gen.py` turns
> `schema/lal-nodes.json` into `ada.dbscheme` (4,163 lines), `ql/lib/codeql/ada/ast/
> internal/Raw.qll` (2,267 lines, 405 QL classes), and `extractors/ada/tools/
> ada_tables.json` (333 kinds with per-field table mapping for the extractor).
> Validated end-to-end: `codeql database create` imports the generated dbscheme and
> a query importing the full Raw library compiles and runs.

- [x] 2.1 Core relations: standard prelude (locations, files/folders, empty_location,
  sourceLocationPrefix, diagnostics + severity, databaseMetadata, overlayChangedFiles)
  copied from Ruby's conventions. Spike-era `compilation_units` tables dropped — LAL's
  own `CompilationUnit` node kind covers it.
- [x] 2.2 AST relations: per-kind `_def` tables (tokens carry `value`), hierarchy unions
  (concrete non-leaf classes get `_or_sub` unions — LAL has concrete classes with
  subclasses, unlike tree-sitter), one table per declared field (uniform optional-style;
  required-ness is an extractor guarantee since parse errors can null any field), and
  umbrella `ada_ast_node_location` / `ada_ast_node_parent` (which also encodes list
  children — no per-kind child tables). Comments/trivia: resolved 2026-07-03
  (burndown 5.1) — a standalone hand-written `ada_comments` relation, not part
  of the AST tree/generated tables.
- [x] 2.3 Semantic relations: `ada_xref`, `ada_expr_type`, `ada_generic_instantiation`
  defined in the dbscheme (population is Phase 3; generic instance-body model still open).
- [x] 2.4 Upgrade/downgrade story: *resolved 2026-07-03 (D-011)* — pre-1.0 databases are
  rebuilt, not upgraded; no upgrade scripts until there are external users on a 1.0 dbscheme.

## Phase 3 — Extractor

> **Status 2026-07-02: core extractor working at scale.**
> `extractors/ada/tools/extractor.py` (LAL AST → TRAP, driven by generated
> `ada_tables.json`). Runs in WSL with the Linux CodeQL CLI (`/root/tools/codeql`).
> Scale test on gpr2 (345 files): **775k nodes, 185k xrefs, 90k expr types,
> 0 parse errors, 0 nameres errors** in 228 s (~0.66 s/file, single-threaded).
> First real query (`queries/ExceptionSwallowing.ql`) found a genuine
> `when others => null` in AdaCore's own gpr2 sources.

- [x] 3.1 CLI contract: autobuild.sh + `CODEQL_EXTRACTOR_ADA_*` env vars; LAL located
  via `ADA_LAL_PREFIX` (defaults to `~/adacore`) until packaging bundles it.
- [x] 3.2 Project discovery: `CODEQL_EXTRACTOR_ADA_GPR` env var → single `.gpr` under
  root → auto unit provider. Open: scenario variables, multi-GPR repos.
- [x] 3.3 TRAP emission: per-file TRAP; node identity = (file, kind, span) — stable and
  cross-unit computable; known limitation: pathological same-kind-same-span nodes merge.
  Open: TRAP compression, incremental caching.
- [x] 3.4 Error tolerance: parse errors become `diagnostics` rows (severity error) without
  failing the file; nameres wrapped per-node. Open: corpus with intentionally broken code.
- [x] 3.5 *Done 2026-07-03.* Multi-process pool (one LAL context per fork;
  `CODEQL_EXTRACTOR_ADA_JOBS`, default nproc). gpr2: 228 s → **76.6 s** with 12 jobs,
  identical stats (deterministic). Sublinear because each worker re-parses dependency
  closures for nameres; good enough until proven otherwise.

## Phase 4 — QL library pack (`ada-all`)

- [x] 4.1 *Done 2026-07-02.* Generated `Raw.qll` (Phase 2) + hand-written layer in
  `ada.qll`: `Name.getText()` (recursive over token values/dotted names),
  `Name.getReferencedDecl()`, `Expr.getType()`, `BasicDecl.getADefiningName()/getAName()/
  isReferenced()`, `AdaNode.getEnclosingSubprogram()/getEnclosingUnit()`.
  Fix along the way: token-node detection (SingleTokNode hierarchy) — token kinds now
  store their source text in the `_def` tables' `value` column.
- [x] 4.2 `File`/`Location` with `hasLocationInfo` — test framework renders locations
  correctly (relativized paths in `.expected` files prove the contract works).
- [ ] 4.3 CFG library in QL (per decision 0.5, post-v1). → **Now planned as Phase 7**
  (D-013, [docs/phase7-plan.md](docs/phase7-plan.md)).
- [ ] 4.4 Dataflow: instantiate the shared `codeql/dataflow` framework (post-v1).
  → **Now outlined as Phase 9** (needs its own plan doc after Phase 7 ships).

## Phase 5 — Queries, tests, CI

- [x] 5.1 *Done 2026-07-03 — 8 queries shipped:* ExceptionSwallowing, PragmaSuppress,
  UncheckedConversion, UnusedVariable (xref-based), UncheckedDeallocation,
  HardcodedCredential (name-pattern + string-literal-initializer heuristic),
  SparkModeOff (`pragma SPARK_Mode (Off)`), TodoComment (TODO/FIXME/XXX/HACK).
  TodoComment required adding comment/trivia extraction, which Phase 2.2 had
  deferred: comments aren't LAL AST nodes (they're token trivia), so they get a
  small hand-written `ada_comments(id, text, location)` relation (added to
  `generator/gen.py`'s hand-written prelude, *not* the LAL-introspection-driven
  generated tables) plus a `Raw::Comment` QL class and an `emit_comments` pass
  in the extractor that walks `unit.first_token`/`.next`/`.is_trivia` directly,
  independent of the AST `walk()`. `ql/lib/ada.dbscheme.stats` regenerated via
  `codeql dataset measure` to match (required — stale stats missing a relation
  didn't break compilation but should stay in sync). No further "still open"
  query ideas queued; more can be added anytime following the existing patterns.
- [x] 5.2 *Done 2026-07-03.* `codeql test run` harness live: `ql/test/queries/<Q>/` with
  `.qlref` + Ada snippets + `.expected`; extractor's qltest entry point is
  `tools/index.sh` (legacy_qltest_extraction). All 8 query tests green, plus
  2 golden-output extractor regression tests added in `ql/test/extractor/`
  (test-local `.ql` files, no `.qlref`, generated via `codeql test run --learn`):
  `PrintAst` dumps every AST node's kind/parent/index (guards the Phase 3
  `walk()`/dbscheme node-parent pipeline even where no security query happens
  to touch the affected relation), `PrintComments` dumps extracted comment text
  (guards the new `emit_comments` path specifically, since it's structurally
  separate from `walk()`).
- [x] 5.3 *Done 2026-07-03.* `scripts/corpus_regression.py` drives the real
  `codeql database create` pipeline (not a Libadalang-only spike) over 5 pinned
  real projects in `scripts/corpus.json`: gpr2, AdaSAT (both already known from
  spike 1.5), libadalang-tools, Alire, and libkeccak (a SPARK-flavored crypto
  lib, for D-006 coverage). Projects are fetched by exact commit SHA (`git
  fetch origin <sha>`), not branch tips, so runs are reproducible. Extracts,
  parses the extractor's summary stats line, and compares against
  `scripts/corpus_baseline.json`: file-count drift or new parse errors are
  hard failures (exit 1); nameres/timing drift are warnings only, since LAL
  itself is built from a moving `master` branch (D-002/D-008) and can
  legitimately shift those numbers between builds.
  - Learning: naively pinning each project's "main" `.gpr` broke 3 of the 5
    projects (`alire`, `libadalang-tools`, `libkeccak`) — their project graphs
    `with` dependency crates that Alire fetches at build time and that aren't
    vendored in a plain git clone. Left `"gpr": null` for those (and for gpr2,
    whose `.gpr` needs a generated `gprconfig_kb` dir); the extractor's own
    auto-unit-provider fallback handles all of them without crashing, at the
    cost of weaker name resolution than a fully-configured build would give.
- [x] 5.4 *Done 2026-07-03, verified green on GitHub Actions 2026-07-03.*
  `.github/workflows/ci.yml`: single job on `container: debian:13` (matching
  burndown 1.1/D-008 — this is the only environment the extractor has been
  verified on; plain `ubuntu-latest` was not attempted and may hit the same
  GNAT-version traps `build-libadalang.sh` works around). Steps: apt prereqs →
  checkout → restore-or-build Libadalang (`actions/cache/restore`+`/save`
  keyed on the build script's hash plus a manually-bumped `LAL_CACHE_VERSION`,
  since upstream `master` can drift without the script text changing) →
  restore-or-download the pinned CodeQL CLI release → `codeql test run
  ql/test` (Phase 5.2 harness) → `corpus_regression.py` → upload the JSON
  report as an artifact.
  - Two bugs found only by running on real GitHub Actions (not reproducible by
    validating the YAML or running steps manually in WSL): (1) `index.sh`/
    `autobuild.sh` were committed with git mode `100644` — Windows doesn't
    track the Unix executable bit, so this was invisible locally but caused
    `EACCES` when the Linux runner tried to exec them directly; fixed via
    `git update-index --chmod=+x`. (2) `actions/cache@v4`'s save step is
    `post-if: success()` on the *whole job* — since bug (1) always failed the
    QL test suite step, the Libadalang/CodeQL-CLI caches were silently never
    saved on any run, forcing a full ~45min rebuild every time. Fixed by
    splitting each into `actions/cache/restore@v4` (early) +
    `actions/cache/save@v4` (`if: cache-hit != 'true' && success()`,
    immediately after the build/download step) so a good build is cached
    regardless of unrelated later failures (e.g. corpus-regression network
    flakes). Confirmed both caches populate on the first green run.
  Windows/macOS packaging (the rest of 5.4's original scope) is still open —
  revisit at Phase 6.
- [x] 5.5 *Done 2026-07-03 (post-Phase-6) — 3 more queries, 11 total:*
  UnusedWithClause (a `with` clause no other resolved name in the file refers
  back to; deliberately conservative — only fires when the with'd unit's own
  declaration is in the analyzed sources, so it silently no-ops on
  standard-library units rather than risk a false positive when the GNAT
  runtime isn't part of the source set), SelfComparison (`X = X`/`X <= X`/...,
  matched by comparing `getReferencedDecl()` on both sides of a `RelationOp`,
  not by text), UnreachableStatement (the statement immediately after an
  unconditional `raise`/`return` in the same `StmtList`, skipping a
  following `Label` since a `goto` this project doesn't analyze could still
  target it). All three reuse existing `ada.qll`/`Raw::` surface with no
  extractor or dbscheme changes. 13/13 QL tests green;
  `codeql database analyze` clean (11 rules, no errors) against the full
  suite.

## Phase 6 — Packaging & release

> **Status 2026-07-03: all Phase 6 tasks complete** (6.0, 6.4, 6.1, 6.2, 6.3, executed in
> that order per [docs/phase6-plan.md](docs/phase6-plan.md)). Pack scope renamed; LAL
> commits pinned and verified via a from-scratch build and a green CI rebuild; release
> tarball script isolation-tested; release workflow's `workflow_dispatch` dry run green on
> GitHub Actions with the tarball as an inspectable artifact; docs rewritten with every
> command verified. No release has been tagged yet — that's a deliberate, separate step
> the user pulls the trigger on (see CONTRIBUTING.md's release checklist), not something
> left undone here.

- [x] **6.0 Scope rename** `codeql-ada/` → `peter-villadsen/` in the three qlpack.yml files.
  *Done 2026-07-03* — 5 occurrences updated; full WSL test suite green (10/10).
- [x] 6.1 Release tarball: `scripts/create-extractor-pack.sh` bundling the LAL runtime
  (shared-lib closure incl. GNAT runtime + ctypes Python bindings + third-party notices);
  verified in a clean environment with no dev-machine LAL install.
  *Done 2026-07-03* — isolation test (`env -i`, no access to the dev machine's
  `$HOME/adacore`) creates a database and runs a real query cleanly; found and fixed a
  dangling-symlink bug in the closure copy (`cp -a` vs `cp -L` on system deps like
  `libgmp.so.10`); THIRD_PARTY_NOTICES.md written from each dependency's actual LICENSE
  file, not assumed — GNATcoll/libgpr/XML-Ada/GNAT-runtime turned out to be GPLv3 +
  GCC Runtime Library Exception, not Apache-2.0 like Libadalang/Langkit/VSS/prettier-ada/
  AdaSAT/gpr2.
- [x] 6.2 Release workflow on tag `v*`: version-consistency gate → tests → tarball →
  GitHub Release → `codeql pack publish` of `ada-all` + `ada-queries` to GHCR.
  *Done 2026-07-03* — `workflow_dispatch` dry run green on GitHub Actions (cache hits on
  the pinned LAL/CodeQL CLI builds, ~2 min), tarball uploaded as an 81.5MB workflow
  artifact, Release/publish steps correctly skipped (no tag). Version-gate script verified
  locally for all four cases: no tag, matching tag, wrong tag, and manifest-to-manifest
  mismatch. **Found and fixed along the way: the repo's default branch was `main` (a
  stub with only the auto-generated initial commit) while all real history lived on
  `master`; GitHub Actions silently refuses to register `workflow_dispatch` for a
  workflow that only exists off the default branch, so `release.yml` never showed up in
  the workflow list until `master` was made the default branch.** Also added an
  `actions/upload-artifact` step that the first dry run was missing.
- [x] 6.3 Docs: README rewrite, user guide, query-writing guide, CONTRIBUTING (dev env,
  regeneration pipeline, release checklist, pin-bump procedure).
  **Audience/quality bar (set 2026-07-03, applies to all four files): textbook quality,
  not reference-manual quality.** Assume the reader is a skilled Ada programmer who has
  never used CodeQL — explain CodeQL concepts (extractor, database, QL, pack, query
  suite) in prose the first time each appears, don't assume familiarity with the
  `github/codeql` ecosystem or its jargon. Do not assume Ada knowledge needs explaining.
  *Done 2026-07-03.* Every documented command was actually executed at least once
  (copy-paste fidelity) before being included — this caught three unrelated pre-existing
  bugs, fixed in separate commits along the way: (1) all 8 queries were `@kind table`,
  which `codeql database analyze` cannot interpret at all (needs `problem`/`path-problem`)
  — fixed by adding `@kind problem` + `@problem.severity` to each (no `.expected` files
  needed regenerating, since `codeql test run` ignores `@kind`); also dropped a stray
  spike-era `ql/src/spike/ListFiles.ql` that would otherwise ship in the published
  `ada-queries` pack. (2) The repo's default branch was a stale, empty `main` created at
  `gh repo create` time, while all real work has always been on `master` — GitHub silently
  refuses to register `workflow_dispatch` for a workflow that only exists off the default
  branch, which is why 6.2's dry run didn't show up until `master` was made the default.
  (3) The four generator-produced files (`ada.dbscheme` ×2, `Raw.qll`, `ada_tables.json`)
  were committed with CRLF while `.gitattributes` normalizes everything else to LF —
  regenerating from WSL/Linux Python produced a spurious 100%-of-lines diff (content
  identical, confirmed via `git diff -b -w`); fixed by normalizing to LF and extending
  `.gitattributes`.
- [x] 6.4 Pin LAL/Langkit (and other tip-of-master deps) to exact commits in
  `build-libadalang.sh`; support policy = CodeQL CLI 2.25.6 tested.
  *Done 2026-07-03* — 8 repos pinned (gnatcoll-core, gnatcoll-bindings, adasat, VSS,
  langkit, libadalang, prettier-ada, gprconfig_kb), fetched shallow at the exact commit
  rather than at branch tip. Verified with a full from-scratch WSL build to a throwaway
  `$HOME` (moves prefix/src/venv together) — clean import and parse, 0 diagnostics — and
  with a real CI run that rebuilt LAL from the pinned commits and went green end to end
  (QL test suite + corpus regression), confirming the cache repopulates correctly.

## Phase 7 — Control flow graph (planned 2026-07-03)

> Decisions D-013/D-014; execution plan in [docs/phase7-plan.md](docs/phase7-plan.md).
> Goal: a CFG good enough for the paired-call query ("a call to Foo not invariably
> followed by a call to Bar"). Pure QL — no dbscheme or extractor changes.

- [x] 7.0 Wire up shared `codeql/controlflow` pack (version matched to CLI 2.25.6).
- [x] 7.1 CFG design doc `docs/cfg-design.md` (construct→successor mapping table).
- [x] 7.2 Skeleton: scopes + straight-line code.
- [x] 7.3 Branching, loops, exit, goto.
- [x] 7.4 Exceptions (conservative raise model), short-circuit, conditional exprs.
- [x] 7.5 PrintCfg golden-test harness (one .adb per construct family).
      → superseded by 7.7; the learned `.expected` is gone and `PrintCfg.ql` now
      lives in `ql/debug/`.
- [x] 7.6 Consumer layer: basic blocks/dominance re-export, `MissingPairedCall`
      parameterized module, UnreachableStatement rewritten on the CFG,
      `ada/function-missing-return`, `ada/open-without-close`.

## Phase 7.7 — CFG specification & conformance tests (planned 2026-08-10)

> Decisions D-016..D-019; execution plan in [docs/phase7.7-plan.md](docs/phase7.7-plan.md).
> Turns `docs/cfg-design.md` from prose into a checkable specification and replaces the
> single learned edge dump with per-construct inline-expectation tests. No CFG features.

- [x] 7.7.0 Inline-expectation harness (`codeql/ada/test/InlineExpectationsTest.qll`,
      `CfgConformance.qll`, `ql/debug/` PrintCfg + CfgAnnotations), golden harness retired.
- [x] 7.7.1 `docs/cfg-design.md` rewritten as a snippet→edges specification.
- [x] 7.7.2–7.7.15 Fourteen construct families, each with a spec section and a
      conformance test whose `.adb` carries exhaustive machine-checked edge annotations:
      linear, scopes, if-stmt, case-stmt, loops-basic, loops-for, exit, goto, blocks,
      exceptions, return, short-circuit, cond-expr, tasking.
- [x] 7.7.16 Coverage appendix: all 405 node kinds carry a verdict, enforced in CI by
      `scripts/check_cfg_coverage.py`.
- [x] 7.7.17 Close-out: bundled `test_*.adb` retired after construct-by-construct check.

Defects the conformance tests surfaced (all four fixed):

- [x] C-1 **Declarative parts were not elaborated.** A subprogram's, package's, task's or
      entry body's local object initialisers produced no CFG nodes at all — only `declare`
      blocks elaborated — so every expression evaluated during elaboration, including
      calls that can raise, was missing from the graph. `BodyTree` now sequences
      "elaborate the declarative part, then run the statements" for all four body kinds,
      sharing its elaboration rule with `DeclBlockTree`; an entry barrier is evaluated
      first of all. The `scopes` family's MISSING/SPURIOUS tripwires reported all nine
      predicted edges on the fix.
- [x] C-2 `CaseStmtTree`/`CaseExprTree` dropped the selector's abnormal completions.
- [x] C-3 A plain `accept E;` was matched by no control-flow tree and vanished.
- [x] C-4 `select … then abort`'s abortable part was in no branch and unreachable.
- [x] C-5 resolved as *not* a defect: a `NumberDecl`'s value is static.

C-1 changes no current query result: `ada/open-without-close` matches `CallStmt` only, and
`Ada.Text_IO.Open`/`Create` are procedures, so they cannot appear as an initialiser. (An
earlier note here claimed otherwise — it was wrong.) What the fix buys is a graph that no
longer omits elaboration: a user instantiating `MissingPairedCall` with a *function*-shaped
acquire (`H : Handle := Acquire (…)`) now sees it, exception edges out of initialisers
exist, and — the substantive one — the SSA layer planned for Phase 9 will see the defining
assignment of every initialised local, which it could not have before.

## Phase 10 — Adoption (planned 2026-08-10)

> Making the analyzer usable by someone who did not build it. Everything here is
> documentation and packaging; no analysis behaviour changes.

- [x] 10.1 `docs/ci-integration.md` — GitHub Actions + code scanning, Azure DevOps
      (hosted and air-gapped). Leads with the constraint that `github/codeql-action`
      cannot accept `languages: ada`, so third-party extractors install the CLI
      themselves and use the action only for `upload-sarif`.
- [x] 10.2 `docs/releasing.md` + release prep: `release.yml`'s missing `codeql pack
      install` fixed (it would have failed any tag), manifests bumped 0.0.1 → 0.1.0,
      release checklist with a verified isolation test.
- [x] **10.3 Cut v0.1.0.** *Done 2026-09-25.* GitHub Release published with
      `codeql-extractor-ada-linux64.tar.gz` attached; `peter-villadsen/ada-all` and
      `peter-villadsen/ada-queries` published to GHCR at `0.1.0`. Verified after the fact:
      authenticated `gh release download` retrieves the tarball; `gh api .../packages`
      shows both container packages tagged `0.1.0`.
      - **First tag attempt failed and was redone.** `release.yml`'s `Publish QL packs`
        step used `codeql pack publish ... --github-auth-stdin <<< "$GITHUB_TOKEN"` — the
        job runs in a `container: debian:13`, where GitHub Actions defaults `run:` steps to
        the container's `/bin/sh` (dash), not `bash`. `<<<` is a bash-only here-string, so
        this was a dash **syntax error**: the publish command never executed at all, only
        the preceding `codeql pack install` did. Fixed by piping instead:
        `printf '%s' "$GITHUB_TOKEN" | codeql pack publish ... --github-auth-stdin`.
      - **Found alongside it, not yet consequential:** the version-consistency gate's tag
        check used `if [[ "$GITHUB_REF" == refs/tags/v* ]]`. dash has no `[[`, so it treats
        `[[` as an external command, gets "not found," and — because that failure sits
        inside an `if` condition — POSIX `errexit` doesn't fire on it. The check silently
        no-ops instead of failing loudly. Harmless this time (tag and manifests already
        matched) but latent. Fixed with a POSIX `case` statement.
      - **Recovery:** the failed run's `Create GitHub Release` step had already succeeded
        (tarball attached, no packs) before `Publish QL packs` failed, and dash's
        statement-by-statement execution meant neither `codeql pack publish` call had run —
        confirmed via `gh api` before deleting anything. Since nothing had reached GHCR,
        deleted the `v0.1.0` Release and tag, fixed `release.yml`, and re-tagged `v0.1.0` on
        the fixed commit rather than bumping to `0.1.1` — no consumers existed yet to
        protect against a version bump. The Libadalang/CodeQL CLI build caches survived the
        failed run (only the last step failed), so the redo completed in 3m30s instead of
        the ~50 minutes a cold cache would need.
      - **Environment note for next time:** this machine's WSL only had Ubuntu 26.04
        installed, not the Debian 13 used to build Libadalang in burndown 1.1/5.4 — the
        local pre-tag checklist in `docs/releasing.md` (tarball build + isolation test)
        could not be run here. The release was cut by trusting `release.yml`'s own
        server-side test suite/corpus-regression/tarball-build steps instead, which is what
        caught nothing here (the bug was in code the local checklist doesn't exercise:
        publish-step shell syntax, not extraction correctness). Rebuilding the WSL Debian
        Libadalang environment is still open if a fully-local pre-tag check is wanted again.
- [ ] 10.4 Cross-implementation validation — **blocked on tool acquisition**, see the
      note under Phase 9 below.

## Phase 8 — Wave A queries (planned 2026-07-03; independent of Phase 7)

> Eleven AST+xref+types-only queries, specs in [docs/phase7-plan.md](docs/phase7-plan.md)
> §Phase 8 — any order, one at a time. Rule ideas ported per D-014 (GNATcheck / C-C++ /
> C# quality suites — ideas, not code). Takes the pack 11 → 22 rules.

- [x] 8.1 boolean-literal-comparison · 8.2 identical-operands · 8.3 useless-if
      · 8.4 empty-loop-body · 8.5 float-equality · 8.6 goto-statement
      · 8.7 raise-predefined-exception · 8.8 unused-parameter
      · 8.9 dead-local-subprogram · 8.10 direct-recursion · 8.11 warnings-off
      *Done 2026-07-03 — all 11 shipped, 24/24 QL tests green, full pack
      compiles and evaluates cleanly against a real database (`hello-db`).*
      Two notable findings from test-first xref checks (Global trap 7), both
      documented as comments in the affected query files:
      - **8.5 float-equality**: `ada_expr_type` is only emitted when the
        resolved type declaration is itself in the analyzed source set.
        `Standard.Float`/`Long_Float` never qualify (they live in the
        unanalyzed `Standard` package), so v1 only catches comparisons on
        *user-declared* floating-point types — confirmed by testing with
        plain `Float` (zero matches) vs. a custom `digits 6` type (matches).
      - **8.8 unused-parameter / 8.9 dead-local-subprogram / 8.10
        direct-recursion**: a reference to a *parameter* inside a body
        always resolves to that body's own `ParamSpec`, never to a separate
        forward declaration's copy — so 8.8 needs no decl/body pairing at
        all. A *call*, by contrast, does resolve to the separate forward
        declaration's `SubpDecl` when one exists, so 8.9/8.10 do need the
        pairing. That pairing broke for library-level (top-level) subprograms
        because each is wrapped in its own private `LibraryItem`/
        `CompilationUnit` node — two top-level siblings only share a parent
        three levels up, at the file's `CompilationUnitList` (worked around
        in `DirectRecursion.ql`; `DeadLocalSubprogram.ql` never hits this
        since it only pairs *nested* siblings, which share an immediate
        parent). Also found: a body's closing `end Name;` is extracted as
        two self-referencing `ada_xref` rows (the `EndName` node and its
        inner `Identifier` child), so a naive `isReferenced()` on a
        `SubpBody` is always true and must exclude both.

## Phase 9 — SSA + dataflow (outline only)

- [ ] 8.12 Extract package `Standard` (and possibly the runtime spec closure) as
      pseudo-sources so semantic relations resolve predefined entities (`Float`,
      `Boolean`, `Constraint_Error`, ...). Removes the source-set blindness recorded
      in D-015: `float-equality` starts catching plain `Standard.Float` comparisons,
      and the textual matchers listed in D-015 become candidates for semantic
      rewrites. Extractor-side work; re-audit those queries when this lands.
      → **Spiked 2026-09-25: [docs/phase8.12-plan.md](docs/phase8.12-plan.md)**
      (`scripts/spike_standard.py`). The spike reframed the item: under the auto unit
      provider (4 of 5 corpus projects) the GNAT runtime is not visible at all, so every
      statement mentioning a runtime entity fails resolution *including the user's own
      names in it*. The result is false positives in shipped queries: libkeccak
      unused-parameter 155 → 10 and unused-local 181 → 8 once the runtime is visible,
      322 results lost in total, alire 748 lost. The corpus baseline's large
      `nameres_errors` counts were this, undiagnosed. Making resolution work also
      exposes two latent bugs in `self-comparison`/`identical-operands` (dotted names
      compared by declaration only; multi-identifier declarations, cf. D-024). Split into:
  - [x] **8.12a** Runtime discovery for the auto provider
        (`CODEQL_EXTRACTOR_ADA_RUNTIME`, else `gcc -print-file-name=adainclude`, else a
        `no-runtime` warning diagnostic), plus the two query fixes, plus a
        corpus-baseline refresh. **Done 2026-09-25.** libkeccak `nameres_errors`
        16,458 → 3,017. Full-suite results before → after: adasat 36 → 34, alire
        2,854 → 2,095, gpr2 11,868 → 5,039, libadalang-tools 4,538 → 3,804, libkeccak
        732 → 350; only additions are true-positive `direct-recursion` hits (alire 6,
        gpr2 59, libadalang-tools 3). `self-comparison`/`identical-operands` now compare
        via `Name.denotesSameEntityAs` (component-wise dotted names, D-024 narrowing),
        which also removed long-standing false positives on multi-identifier
        declarations (e.g. libkeccak 40, libadalang-tools 146). Triage of the new
        `direct-recursion` results: the sampled ones are real self-calls; the query's
        textual spec pairing matched *other overloads* in the same declarative part
        (gpr2 9), so it now uses `ada_body_part` (D-021). Extraction time up (alire
        19 s → 44 s), as the spike predicted.
  - [x] **8.12b** Extract `Standard` (real unit, 1,800 nodes, but reported at
        `<cwd>/__standard`, so it needs a pseudo path) and the *direct* target units
        only (+26–37% nodes; the transitive closure is +300–1,700%), marked with a new
        `ada_predefined_file` table so queries can report `fromSource()` only. Records
        D-026, superseding D-015's textual-matching rule. Before Task 9.5.
        **Done 2026-09-25.** Two-pass extractor; `Standard` at
        `/__codeql_ada_predefined__/standard.ads`; out-of-project targets only when
        walkable (excludes Libadalang's synthetic operator/class-wide/char-literal nodes,
        which would dangle). Predefined units per project: adasat 9, libkeccak 30, alire
        67, libadalang-tools 74, gpr2 121; nodes +12–87%; extraction alire 44 s → 50 s,
        libkeccak 8 s → 14 s. All 24 queries report `fromSource()` only (guarded by the
        `WarningsOff`/`TodoComment` fixtures, whose runtime dependencies would otherwise
        report; `PrintPredefined` guards the extraction). `float-equality` catches plain
        `Float` (libadalang-tools +2, true positives). `unused-with-clause` sees runtime
        units, and two latent bugs surfaced with them: the with clause's own selector
        (`Text_IO` in `with Ada.Text_IO;`) counted as a use, so a dotted `with` was never
        reported; and where a use fails name resolution the query reported a false
        positive (gpr2's testsuite, 143 in 8.12a). Fixed both; the second by not reporting
        when an unresolved identifier spelled like the unit occurs in the file. Results
        8.12a → 8.12b: adasat 34 → 34, alire 2,095 → 2,105, gpr2 5,039 → 5,241,
        libadalang-tools 3,804 → 3,819, libkeccak 350 → 341; the changes are all
        `unused-with-clause` except the two float hits and gpr2 noise (next item). CFG/SSA
        conformance unchanged; `PrintSsa` over alire/libkeccak fine (12 s / 5 s).
        Deferred from the plan's step 4: the four textual matchers stay textual (8.12c).
  - [x] **8.12c** Semantic rewrites of the textual matchers D-015 listed
        (`unchecked-conversion`, `unchecked-deallocation`, `raise-predefined-exception`,
        `boolean-literal-comparison`), and of `OpenWithoutClose`'s `isTextIoOp` fallback.
        Each only with a test that the rewrite loses no case the textual form caught
        (renamings, `use` clauses, `Standard.`-qualified names), and one that fails if the
        runtime entity stops resolving.
        **Done 2026-09-25.** New `ada_qualified_name` table (Libadalang's
        `p_fully_qualified_name` for every declaration) behind
        `BasicDecl.hasQualifiedName`, plus `BasicDecl.getUltimateDecl()` (follows
        exception/object/subprogram/package renamings) and
        `GenericInstantiation.getDesignatedGeneric()`. All five match semantically and
        fall back to text only for names that do not resolve. Verified per query against
        the old textual query on the same fixtures: every case the old one caught that
        was right is still caught; it additionally caught user entities that merely share
        the name (a user `My_Unchecked_Conversion`, a shadowing `Constraint_Error`, a user
        enumeration literal `True`, a file closed through a renaming), and missed generic
        renamings, exception renamings, `Standard.True`, derived-Boolean literals, and
        `Open`/`Close` under `use` or a package renaming. On a database built with no
        runtime the new queries equal or beat the old ones (`Standard` always resolves).
        The old `isTextIoOp` "xref" branch never fired: it compared the package name to
        `text_io`, but the package is declared as `Ada.Text_IO`. Corpus: adasat 34 → 24 and
        gpr2 −10 `boolean-literal-comparison` (adasat's own `type Variable_Value is (True,
        False, Unset)`, vendored in gpr2); `open-without-close` gpr2 −4/+5,
        libadalang-tools +22 (bare `Open`/`Create` under `use`, and bare `Close` now
        recognised). Extraction cost of the new table is within noise.
  - [ ] **Nondeterministic resolution in projects with duplicate unit names.** Found in
        8.12b: two identical extractions of gpr2 gave `nameres_errors` 93,114 and 93,105.
        gpr2's testsuite reuses unit names (`Test`, `Pkg`, ...); under the auto provider
        which duplicate a name resolves to depends on what the worker's Libadalang
        context loaded earlier, and `pool.map` hands out chunks by timing. E.g.
        `testsuite/tests/exchange/test.adb` resolves nothing in a fresh context but did
        in the 8.12a database. Predates 8.12b; small (±0.01% of names) but it makes
        corpus diffs noisy. Options: a fresh context per file (cost), deterministic
        chunk assignment, or a diagnostic for duplicate unit names.
- [ ] **10.4 Cross-implementation validation — GNATcheck differential is blocked.**
      The intent was to run GNATcheck over the 5-project corpus and diff its findings
      against ours rule by rule: no files copied (so no licensing question), ~1,700 real
      files rather than toy cases, and it answers the question this audience actually
      asks — "does this agree with the tool I already trust?".
      GNATcheck turns out not to be obtainable cheaply. Checked and ruled out on
      2026-08-10: not in Debian (the ASIS-based `asis-programs` is gone from modern
      GNAT); not in `libadalang-tools`, whose public testsuite has only laltools,
      metric, pp and stub; and no crate in the Alire index. What remains is building
      AdaCore/gnatcheck from source, which pins its own Libadalang/Langkit versions —
      and ours are pinned by D-012 for extractor stability and must not move to suit it,
      so this likely means a *second* Libadalang build.
      Alternatives, if the differential is not worth that: (a) port the imperative-core
      C# tests as Ada tests with hand-derived expectations (MIT, no toolchain, ~6–9
      overlapping rules, cost is adjudicating each divergence); (b) write Ada test cases
      from GNATcheck's *documented* rule semantics without running the tool — cheap, no
      toolchain, weaker evidence.
- [x] 9.0 Phase 9 plan doc → [docs/phase9-plan.md](docs/phase9-plan.md). The soak gate is
      satisfied: the CFG has been run over the full corpus and four defects were found and
      fixed. **Key finding: the call graph does not exist yet.** There is no
      declaration↔body relation, so a call in a spec/body-split package resolves only to
      the spec's `SubpDecl` — and name-text pairing cannot substitute, because Ada
      overloads. Verified 2026-08-11 that Libadalang's `p_body_part` resolves it across
      compilation units, so the fix is extraction, not analysis. That makes Phase 9 the
      first phase since Phase 3 to change the dbscheme, with the database-format
      consequences in D-011.
- [x] **9.1 Extract the call graph.** *Done 2026-08-11 — see [D-021](DECISIONS.md).* New
      relation `ada_body_part(decl, body)` in the dbscheme, emitted in
      `extractors/ada/tools/extractor.py` from Libadalang's `p_body_part`. Exposed as
      `BasicDecl.getBody()` / `BaseSubpBody.getDeclaration()` in `ql/lib/ada.qll`.
      `ql/lib/ada.dbscheme.stats` regenerated (`codeql dataset measure`), per the plan's
      trap 1. Full suite green (41/41); corpus regression green on all 5 pinned projects
      (gpr2 1,718 files included).
      - **`p_body_part` is inconsistent across Libadalang node kinds**: a `@property` on
        `BasePackageDecl`/`GenericPackageDecl` (returns the value directly), a callable
        method with an `imprecise_fallback` parameter on `ClassicSubpDecl`/`EntryDecl`/
        `GenericSubpDecl`. The extractor normalizes both shapes with `callable(bp)` rather
        than special-casing node kinds — found by reading the generated Python bindings
        before writing the extraction code, not by trial and error.
      - **Test-first, per Global trap 7**: a new golden-output regression test,
        `ql/test/extractor/PrintBodyPart/`, dumps every `ada_body_part` row over a fixture
        covering all six cases the task asked for (spec+body in separate units,
        expression-function completion, a body with no separate spec, two overloads with
        different profiles, a nested subprogram, a library-level subprogram). The learned
        output confirms the overload case resolves each declaration to its own body (`Foo
        (X : Integer)` → its body at pkg.adb:2, `Foo (X : Float)` → its body at
        pkg.adb:7, never crossed) and that the no-separate-spec body produces no row —
        exactly what name-text pairing cannot guarantee (D-021's acceptance criterion).
      - **`DeadLocalSubprogram.ql` / `DirectRecursion.ql` reviewed as asked:** both
        `getMatchingDecl` helpers (name-text-plus-region approximations, one of them with
        a documented library-level special case) could now be replaced by
        `BaseSubpBody.getDeclaration()`, exactly and without the library-level
        special-casing. Not changed here — 9.1 was scoped to extraction, and the two
        queries' current approximations are tested and correct for the cases they cover;
        swapping them is a small, low-risk follow-up whenever someone next touches either
        file, not urgent enough to justify unbudgeted scope now.
- [ ] SSA (`codeql/ssa`) over the CFG → dataflow (`codeql/dataflow`) → first taint
      queries with Ada sources/sinks (`Ada.Command_Line` → `GNAT.OS_Lib.Spawn`,
      `GNATCOLL.SQL`, file-path sinks). This is where the C# security suite's ideas
      become portable (D-014 Wave C).
      → **Step-by-step execution plan: [docs/phase9.2-plan.md](docs/phase9.2-plan.md)**
      (2026-09-01), covering tasks 9.2 (SSA), 9.3 (local dataflow), 9.4 (cross-procedure)
      and 9.5 (first taint query). Findings verified against the toolchain while writing
      it, each of which would otherwise have been discovered the expensive way: the
      shared pack versions named in the Phase 9 plan are 2.26.x-era and unusable on CLI
      2.25.6 (correct set: ssa 2.0.27, dataflow 2.1.7, typetracking 2.0.35, the last of
      which the plan had missed entirely) — pinned to those exact versions, a plain
      `codeql pack install` resolves cleanly even from a fully empty pack cache, no extra
      download step needed (an earlier pass at this plan claimed one was required; that
      did not survive testing against a genuinely empty cache); `CfgImpl::BasicBlocks`
      does not satisfy the SSA pack's `CfgSig` because it does not export
      `ControlFlowNode`, so a small adapter module is needed (written and compiled
      successfully); and `ada_xref` resolves a name to its `BasicDecl` rather than its
      `DefiningName`, so `X, Y : Integer` would collapse into one SSA variable unless
      references are narrowed by name text.
- [x] **9.2.0 Pack wiring.** *Done 2026-09-01.* `codeql/ssa` 2.0.27 and `codeql/dataflow`
      2.1.7 added to `ql/lib/qlpack.yml` (pulling `codeql/typetracking` 2.0.35
      transitively); lock files regenerated for `ql/lib`, `ql/src`, `ql/test`. Full suite
      green (41/41) with the new dependencies present but unused.
- [x] **9.2.1 The `SsaCfg` adapter.** *Done 2026-09-01.* `codeql/ada/dataflow/internal/
      SsaImpl.qll` renames `CfgImpl::BasicBlocks` into the shape `codeql/ssa`'s `Make`
      wants (it does not itself export `ControlFlowNode`). Compiled with a placeholder
      `SsaInput` (`SourceVariable`/`variableWrite`/`variableRead` all `none()`); 9.2.2/9.2.3
      filled it in.
- [x] **9.2.2 `SourceVariable`.** *Done 2026-09-01.* `SsaSourceVariable`: `ObjectDecl`,
      `ParamSpec` and `ForLoopVarDecl` ids only. `ada_xref` resolves to a `BasicDecl`, not
      the specific name within it, so `getSourceVariable` disambiguates a multi-identifier
      declaration (`X, Y : Integer`) by matching the reference's own name text against the
      declaration's defining names — verified against a scratch database that `X` and `Y`
      resolve as two distinct variables, never merged (D-024).
- [x] **9.2.3 `variableWrite`/`variableRead`.** *Done 2026-09-01.* Full write/read model:
      assignment targets, object-declaration initialisers, `in`/`in out` parameter entry
      (never `out`, which receives nothing from the caller), `for`-loop variables (anchored
      at the iterable, since neither it nor `ForLoopVarDecl` has a CFG node of its own),
      and `out`/`in out` actuals at call sites (uncertain writes, D-022, resolved through
      `ada_body_part`/`ada_xref` — never name text, D-021 — and correct for both positional
      and named associations).
      Two real bugs surfaced by testing against scratch databases, not by inspection:
      **`codeql/ssa`'s own dead-store elision** (`TWriteDef` requires a write to reach a
      live read to become a `Definition` at all) silently dropped the *last* write to any
      `out`/`in out` parameter, since its only reader is the caller after the call returns
      — fixed with a synthetic read at the callee's own normal-exit node, so the SSA
      framework itself doesn't discard the value Task 9.4 needs. And **`strictcount` has no
      result over an empty range** (unlike `count`), which silently dropped the *first*
      formal parameter of every callable from the mode-resolution logic — switching to
      `count` fixed it. Both confirmed with scratch databases before and after: full
      writeup with fixtures in `docs/phase9.2-plan.md` Task 9.2.3. Full suite still green
      (41/41).
- [x] **9.2.4 Conformance tests.** *Done 2026-09-01.* `docs/ssa-design.md` (the SSA
      counterpart to `cfg-design.md`) plus four inline-expectation test families under
      `ql/test/library/Ssa/`: `straight-line`, `if-join` (phi at a branch join),
      `loop` (back-edge phi, `for`-loop-var), `params-inout` (entry writes, the 9.2.3
      exit-read fix, and call-site uncertain writes for both positional and reversed-named
      associations, all in one fixture). `params-in`/`params-out`/`for-loop-var`/
      `decl-init`/`multi-id` from the original outline are folded into these four or
      already verified in 9.2.2, each with its reasoning recorded in `docs/ssa-design.md`
      rather than silently dropped; `exceptions` is explicitly deferred, not assumed
      correct.
      The anchoring rule (comment start line = result end line) caught two real mistakes
      while writing these, not just the CFG tests' well-known trap: a `Definition`'s own
      `getLocation()` is the *whole enclosing construct's* span for both a phi
      (`bb.getLocation()`, the branching construct) and a parameter's entry write (the
      whole scope) — so each one's `reads` annotation belongs on the construct's *end*
      line, not its start. Both were first written wrong and both failed with a correctly
      pointed "Missing result" before being fixed. A deliberately wrong annotation was
      separately confirmed to fail both directions (Missing + Unexpected). Full suite
      green (45/45).

**Phase 9.2 (SSA) is complete** — `SsaImpl.qll` (`ql/lib/codeql/ada/dataflow/internal/`),
specified in `docs/ssa-design.md` and conformance-tested. Next: Task 9.3, local dataflow
(`codeql/ssa`'s `DataFlowIntegration`), then Task 9.4, cross-procedure dataflow — see
[docs/phase9.2-plan.md](docs/phase9.2-plan.md).

- [x] **9.3 Local dataflow.** *Done 2026-09-25.* `SsaFlow` (`codeql/ssa`'s
      `DataFlowIntegration`) in `SsaImpl.qll`, wrapped by `dataflow/internal/LocalFlow.qll`
      (`Node`, `localFlowStep`, `localFlow`, `BarrierGuard`). The integration only makes
      expression nodes for variable reads, so `Node` adds every CFG expression, plus steps
      from a written value into its definition and through parentheses, qualified,
      `if` and `case` expressions. **Guards implemented, not stubbed**, since the shared
      basic-block API made them ~20 lines. Only an expression that *branches* is a guard,
      and the right operand of `and then` does not (it completes into the operator), so
      `BarrierGuard` lifts a check through `and then`/`or else`/`not`/parentheses. That
      was found by testing, after the design note first claimed otherwise. Flow into
      uncertain (`out`/`in out` actual)
      writes is allowed (D-022). Design in the new `docs/dataflow-design.md`.
      Test `ql/test/library/LocalFlow`, hand-derived: straight line, across a branch, into
      and out of a loop, killed by overwrite, through an if-expression in parentheses, and
      guarded vs unguarded uses under `Is_Safe` (plain, as a short-circuit operand, and
      both branches of `not`). Debug dump `ql/debug/PrintLocalFlow.ql`
      (the plan's acceptance query; kept in `ql/debug`, unpolished). Next: Task 9.4.

- [x] **9.4 Cross-procedure dataflow.** *Done 2026-09-25.* `dataflow/internal/DataFlowImpl.qll`
      implements `codeql/dataflow`'s `InputSig` (`AdaDataFlowInput`) and instantiates
      `AdaDataFlow`. **Acceptance met:** flow across two call frames downward (through
      parameters, positional and named) and upward (through function results *and*
      through `out` parameters), with inline expectations in `ql/test/library/DataFlow`.
      `ReturnKind` has `return` plus one `out i` per formal position (D-022). The call
      model is shared with SSA's write-backs in `SsaImpl.qll` (`getCallTarget`,
      `callActual`). It covers parameterless calls, prefixed-view calls (`Obj.Op`,
      where the prefix is formal 0; 5,374 of gpr2's call sites) and subprogram renamings,
      including renaming-as-body. Two traps that testing surfaced: `DataFlowIntegration`
      makes nodes only for reads that are expressions, so an `out` formal's exit read
      needed a synthetic expression (`DfExpr`); and it matches a read to a variable by CFG
      position alone, so several formals' exit reads at one exit node leaked into each
      other (`Swap (A, B)` returned `B` through `A`). The fix filters local steps by
      their variable (`isExitReadOfOther`). Named v1 limitations are pinned as `MISSING`
      or `SPURIOUS`: dispatching, access-to-subprogram, generic instances, entries,
      separate bodies (they resolve to the stub), protected operations, defaults, extended
      return, and the uncertain write-back. The shared consistency checks are a test
      (`Consistency.ql`) and are empty on all five corpus projects. Call resolution on
      the corpus: 1–4% of project calls hit a declaration with no `ada_body_part` row,
      not enough to trigger stop-and-ask 3. Broad global flow runs in 5–20 s per project.
      Also fixed, from 9.2: a reference and a designator were matched to their variable
      or formal by exact name text, but Ada ignores case (`x := 1` wrote no `X`).
      Design, limitations and numbers are in `docs/dataflow-design.md`. Next: Task 9.5.

- [x] **SSA renamed-source debug tool** (requested, not in the original Phase 9 plan).
      `scripts/render_ssa.py` renders a source file with every write/read subscripted
      (`X_1`, `X_2`, ...) and every phi shown as a comment — a readable complement to the
      edge-table debug queries, for when the SSA calculation itself is suspect. Building it
      immediately surfaced two real issues, exactly its intended purpose: (1) a call's
      uncertain write-back (D-022) and the actual argument's own read collide at the exact
      same text span, corrupting the naive rendering (`X_1_2`) — fixed by rendering the
      write-back as a comment instead of a substitution, since the read already owns that
      position; (2) a named association's designator (`X` in `Foo (X => Y)`) was being
      registered as a read of the *callee's* formal, positioned in the *caller's* basic
      blocks — harmless to the actual `Definition`/phi graph (nothing there ever writes the
      callee's formal, so nothing was ever inserted incorrectly) and invisible to the
      existing edge-based conformance tests (which only check edges that have a reaching
      definition), but genuinely wrong and something a future reads-iterating consumer would
      have shown. Fixed with a new `isDesignator` exclusion in `SsaImpl.qll`'s
      `variableRead`, alongside the existing `isAssignTarget` one. Full suite green (45/45,
      confirming the fix changes no existing conformance edge). Full write-up in
      `docs/ssa-design.md`, "Renamed-source rendering".

---

## Top risks

1. **Undocumented internals** — dbscheme syntax and extractor contract have no public spec;
   everything is reverse-engineered from `github/codeql`. CLI upgrades can silently change
   expectations. Mitigation: pin CLI versions; copy patterns from in-repo extractors verbatim.
2. **Generics** — Ada generic instantiation semantics don't map cleanly onto a per-file AST
   database; getting this wrong poisons dataflow later. Decide the model in Phase 2, not Phase 4.
3. **LAL nameres robustness/perf** at scale (spike 1.5 exists to de-risk this early).
4. **Windows dev environment** — LAL tooling is Linux-first; budget for WSL or containers.
5. **Scope creep toward dataflow** — a syntax+xref v1 is genuinely useful; full taint tracking
   is a multi-quarter effort. Hold the v1 line drawn in 0.5.

## Suggested order of attack

Phase 0 decisions → spikes 1.1–1.2 (pipeline proof) → 1.3–1.5 → dbscheme design doc (Phase 2)
→ then start real coding at Phase 3. Phases 3/4 iterate together (extractor and QL library
co-evolve); queries (5) begin as soon as one query can run end-to-end.

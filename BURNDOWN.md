# CodeQL for Ada — Pre-Coding Burndown

Goal: a CodeQL language pack for Ada — extractor (built on Libadalang), database schema,
QL standard library, and an initial query suite — usable via `codeql database create --language=ada`.

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

- [ ] **0.2 Pick the extractor implementation language.** Options, in rough order of fit:

  | Option | Pros | Cons |
  |---|---|---|
  | **Python (LAL Python API)** | Fastest to prototype; introspection API; playground | Ships a Python runtime with the extractor pack; slower on big codebases |
  | **Ada (LAL native API)** | Single static binary; fastest; "dogfooding" | Slower iteration; contributors need GNAT |
  | **Rust/C via LAL C API** | Matches modern CodeQL extractors (Ruby/QL are Rust) | Hand-written bindings; least documented path |

  Recommendation: **Python for the prototype**, decide Ada vs. keep-Python for production
  after measuring extraction speed on a large real project (e.g. GNAT sources themselves).

- [ ] **0.3 Decide extraction model: build-less (recommended) vs. build-traced.**
  Ada has no preprocessor games like C; LAL resolves semantics from a GPR project file
  without running the compiler. Plan: build-less extractor that (a) uses a GPR file when
  present, (b) falls back to LAL's auto unit provider over all `.ads/.adb` files.
  This avoids CodeQL's compiler-tracing machinery entirely — a large complexity saving.

- [ ] **0.4 Decide dbscheme generation strategy.**
  Langkit (LAL's generator) exposes the full node-kind hierarchy via introspection.
  Decide: hand-write the dbscheme, or **generate dbscheme + TRAP emitter + QL AST classes
  from LAL introspection** (the Ruby/QL extractors do exactly this from tree-sitter grammars —
  their Rust generator is the model). Recommendation: generate. Keeps ~400 node kinds in sync
  automatically and follows LAL upgrades.

- [ ] **0.5 Scope the v1 semantic depth.** Syntax-only gets you linting; security queries need:
  - name resolution (definition/use links) — LAL provides via `p_referenced_decl` etc.
  - type of each expression — LAL provides
  - control flow graph — **not** provided by LAL; must be built (extractor-side or QL-side)
  - data flow — built in QL on top of CFG using CodeQL's shared dataflow library
  Decide the v1 cut line (suggested: AST + xref + types in the DB; CFG/DFG in QL later).

- [ ] **0.6 Define target Ada dialect & ecosystem scope.** Ada 2012/2022, SPARK subset?
  GPR-based projects only, or bare source trees too? Alire crates as test corpus?

- [ ] **0.7 Name and pack identifiers.** e.g. language id `ada`, packs
  `<org>/ada-all` (library), `<org>/ada-queries`. Check no collisions on the pack registry.

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
- [ ] 4.3 CFG library in QL (per decision 0.5, post-v1).
- [ ] 4.4 Dataflow: instantiate the shared `codeql/dataflow` framework (post-v1).

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

## Phase 6 — Packaging & release

> **Status 2026-07-03: all Phase 6 decisions made** (D-009…D-012): pack scope
> `peter-villadsen/`; Linux-x86_64-only tarball with bundled Libadalang; tag-driven
> release workflow; pinned LAL commits; pre-1.0 = rebuild databases, no upgrade scripts
> (closes 2.4). Reference layout studied: `codeql-extractor-iac` ships one
> `extractor-<lang>.tar.gz` release asset + publishes QL packs to GHCR under the repo-owner
> scope via `GITHUB_TOKEN`. Detailed per-task instructions with acceptance criteria:
> **[docs/phase6-plan.md](docs/phase6-plan.md)** — execution order 6.0 → 6.4 → 6.1 → 6.2,
> with 6.3 anytime after 6.0.

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
- [ ] 6.3 Docs: README rewrite, user guide, query-writing guide, CONTRIBUTING (dev env,
  regeneration pipeline, release checklist, pin-bump procedure).
  **Audience/quality bar (set 2026-07-03, applies to all four files): textbook quality,
  not reference-manual quality.** Assume the reader is a skilled Ada programmer who has
  never used CodeQL — explain CodeQL concepts (extractor, database, QL, pack, query
  suite) in prose the first time each appears, don't assume familiarity with the
  `github/codeql` ecosystem or its jargon. Do not assume Ada knowledge needs explaining.
- [x] 6.4 Pin LAL/Langkit (and other tip-of-master deps) to exact commits in
  `build-libadalang.sh`; support policy = CodeQL CLI 2.25.6 tested.
  *Done 2026-07-03* — 8 repos pinned (gnatcoll-core, gnatcoll-bindings, adasat, VSS,
  langkit, libadalang, prettier-ada, gprconfig_kb), fetched shallow at the exact commit
  rather than at branch tip. Verified with a full from-scratch WSL build to a throwaway
  `$HOME` (moves prefix/src/venv together) — clean import and parse, 0 diagnostics — and
  with a real CI run that rebuilt LAL from the pinned commits and went green end to end
  (QL test suite + corpus regression), confirming the cache repopulates correctly.

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

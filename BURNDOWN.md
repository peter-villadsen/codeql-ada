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

- [ ] **1.1 Toolchain spike.** *Half done 2026-07-02:* CodeQL CLI v2.25.6 installed
  (`C:\Users\peter\tools\codeql`). Remaining: Libadalang — no PyPI wheels exist (verified),
  so install via Alire or AdaCore GNAT FSF inside WSL Ubuntu (per D-008).
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
- [ ] **1.3 LAL introspection spike.** Dump the full node-kind hierarchy, fields, and token
  types from LAL's Python introspection; confirm it contains everything needed for generation
  (decision 0.4).
- [ ] **1.4 Study reference extractors.** Read `github/codeql` Ruby + QL extractors
  (Rust, generated dbscheme, build-less) and `advanced-security/codeql-extractor-iac`
  (packaging/distribution of a third-party extractor, incl. the release-tarball layout that
  `codeql-extractor-action` consumes).
- [ ] **1.5 Xref/perf spike.** Run LAL name resolution across a large GPR project; measure
  time and failure rate (nameres can fail on individual nodes — need an error policy).

## Phase 2 — Database schema (design doc before code)

- [ ] 2.1 Core relations: files, folders, locations, lines, diagnostics/extraction errors,
  compilation units, `sourceLocationPrefix` — copy conventions from an existing dbscheme.
- [ ] 2.2 AST relations: node kind hierarchy → union types (`@ada_expr`, `@ada_stmt`, …),
  parent/child-index tables, token/trivia storage (needed for comments & exact locations).
- [ ] 2.3 Semantic relations: `ref → decl` xref table, expression-type table, generic
  instantiation links (Ada generics are the hard part — decide instance-body handling).
- [ ] 2.4 Upgrade/downgrade story: dbscheme versioning policy from day one
  (`upgrades/` machinery), even if v1 ships empty.

## Phase 3 — Extractor

- [ ] 3.1 CLI contract: implement the extractor entry points CodeQL invokes
  (`codeql-extractor.yml`: `file_types`, `build_modes: [none]`, autobuild script, env vars
  `CODEQL_EXTRACTOR_ADA_*`).
- [ ] 3.2 Project discovery: locate `.gpr` files, handle multiple projects, scenario
  variables, source dirs; fallback auto-provider mode.
- [ ] 3.3 TRAP emission: AST walk → tuples; stable IDs; TRAP compression; per-file caching.
- [ ] 3.4 Error tolerance: partial parses, nameres failures, mixed-language repos —
  extractor must never hard-fail the whole database for one bad file.
- [ ] 3.5 Parallelism across compilation units.

## Phase 4 — QL library pack (`ada-all`)

- [ ] 4.1 Generated AST classes mirroring the dbscheme, plus hand-written convenience layer
  (`getEnclosingSubprogram()`, `getType()`, pretty `toString()`s).
- [ ] 4.2 `File`/`Location` classes conforming to CodeQL conventions (required for SARIF).
- [ ] 4.3 CFG library in QL (per decision 0.5, likely post-v1).
- [ ] 4.4 Dataflow: instantiate the shared `codeql/dataflow` framework (post-v1).

## Phase 5 — Queries, tests, CI

- [ ] 5.1 Seed query suite (syntax/xref-level is enough to be useful): unused
  declarations, exception-swallowing handlers (`when others => null`), suspicious
  `Unchecked_Conversion` / `Unchecked_Deallocation`, `pragma Suppress` of checks,
  hardcoded credentials in strings, TODO/FIXME. SPARK-adjacent checks later.
- [ ] 5.2 Test infrastructure: `codeql test run` harness with small Ada snippets per
  query; golden-output extractor tests (source → expected TRAP/AST dump).
- [ ] 5.3 Corpus regression: extract 3–5 real projects (e.g. libadalang-tools, Alire itself,
  an avionics-style open project) in CI; track extraction success rate and timing.
- [ ] 5.4 CI matrix: Linux first (primary), then Windows/macOS packaging.

## Phase 6 — Packaging & release

- [ ] 6.1 Extractor pack tarball layout + GitHub Releases, compatible with
  `advanced-security/codeql-extractor-action`.
- [ ] 6.2 Publish QL packs to the GitHub container registry (`codeql pack publish`).
- [ ] 6.3 Docs: user guide (database creation against a GPR project), query writing guide,
  dbscheme/versioning policy, contribution guide.
- [ ] 6.4 Pin support policy: which CodeQL CLI versions and LAL versions are tested.

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

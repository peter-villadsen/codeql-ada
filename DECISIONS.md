# Decision log

## D-001 (2026-07-02) — Open-source model, MIT license
The CodeQL CLI's proprietary terms prohibit redistributing/bundling it or offering it as a
hosted service, and the free CLI terms only cover testing OSI-licensed queries. MIT-licensing
the extractor and packs keeps development and all users compliant, and matches the
`github/codeql` ecosystem. Monetization, if any, is services around the tool, not the tool.

## D-002 (2026-07-02) — Extractor prototype in Python
Libadalang's Python API (Python 3.11+) is the fastest path to a working extractor and exposes
Langkit introspection needed for generation (D-004). Revisit Python-vs-Ada for production
after measuring extraction throughput on a large corpus (burndown 1.5).

## D-003 (2026-07-02) — Build-less extraction
Libadalang resolves Ada semantics from GPR project files without running a compiler, so the
extractor uses `build_modes: [none]` and skips CodeQL's compiler-tracing machinery.
Discovery order: explicit GPR (env var) → single GPR found in tree → auto unit provider over
all `.ads`/`.adb` files.

## D-004 (2026-07-02) — Generate dbscheme, TRAP emitter, and QL AST classes
Generated from Libadalang/Langkit node-kind introspection (~400 kinds), following the pattern
of the Ruby and QL-for-QL extractors (generated from tree-sitter grammars). Hand-written code
is limited to the generator itself, core relations (files/locations/diagnostics), semantic
relations, and a QL convenience layer on top of the generated classes.

## D-005 (2026-07-02) — v1 semantic cut line
Stored in the database: full AST, tokens/comments, xref (ref → decl), expression types,
generic instantiation links. Not in v1: control flow graph and dataflow (built later in QL,
per burndown phases 4.3/4.4).

## D-006 (2026-07-02) — Scope: Ada 2012/2022, GPR-first
Target Ada 2012 and 2022 (whatever Libadalang parses); SPARK is just Ada to the extractor.
GPR-based projects are the primary target; bare source trees supported via auto provider.
Test corpus drawn from Alire crates.

## D-007 (2026-07-02) — Names
Language id `ada`; extension `.ads`/`.adb`/`.ada`. QL packs: `ada-all` (library) and
`ada-queries`, under a scope to be finalized before first `codeql pack publish`
(placeholder: `codeql-ada/`).

## D-008 (2026-07-02) — Dev environment
Primary dev on Windows where possible; Libadalang install on native Windows is expected to be
awkward, so WSL Ubuntu (already installed) is the fallback for anything Libadalang-touching.
CodeQL CLI pinned at v2.25.6 (installed at `C:\Users\peter\tools\codeql`).

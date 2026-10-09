# User guide

Running this in CI rather than on your own machine? See
[ci-integration.md](ci-integration.md) — this guide covers the analysis itself,
that one covers wiring it into GitHub Actions and code scanning.

This expands on the [README](../README.md) quickstart: how the extractor
picks a project, how to control it, what ends up in the database when your
code doesn't parse cleanly, and what to expect from the pre-1.0 database
format. If a term like "extractor" or "database" is unfamiliar, the
[README](../README.md#what-codeql-is-briefly) introduces them first.

## Creating a database

```sh
codeql database create mydb --language=ada --build-mode=none \
  --search-path=<dir containing ada/> --source-root=<path to your Ada project>
```

`--build-mode=none` is not a shortcut — it's a statement about how this
extractor works at all. Most CodeQL extractors watch a real compiler run (a
"traced build") to learn which files exist and how they depend on each
other. This one doesn't: Libadalang resolves Ada's semantics (what a name
refers to, what type an expression has) directly from your GNAT project
file, without invoking GNAT. That's what "build-less extraction" means in
this project's design docs, and it's why there's no `--command` to pass — the
extractor doesn't watch a build, it *is* the whole analysis.

## Project discovery and name-resolution quality

The extractor looks for a GNAT project in three steps, each a fallback for
the one before:

1. **`CODEQL_EXTRACTOR_ADA_GPR`** — set this environment variable to an exact
   `.gpr` path to skip discovery entirely. Use this for multi-`.gpr` repos,
   where auto-detection (step 2) can't pick for you.
2. **Single `.gpr` under the source root** — if exactly one `.gpr` file
   exists anywhere under `--source-root`, the extractor uses it automatically.
3. **Auto unit provider** — with no `.gpr` (zero found, or more than one and
   no env var to disambiguate), Libadalang falls back to parsing every
   `.ads`/`.adb`/`.ada` file under the source root as one flat unit, with no
   project-level configuration (no scenario variables, no `with`-clause
   resolution against a specific build profile).

All three modes extract successfully — this is not a hard failure path.
What changes is **name-resolution quality**: with a real `.gpr`, cross-unit
references resolve against the exact sources and configuration that project
declares; with the auto provider, resolution is best-effort over whatever
Ada files happen to be present, and references into code outside that flat
set (a separate crate, a vendored dependency not on disk) won't resolve. If
your queries rely heavily on `Name.getReferencedDecl()` or `Expr.getType()`
(see [query-writing.md](query-writing.md)), a working `.gpr` is worth setting
up.

### The GNAT runtime (auto provider only)

In auto-provider mode the extractor also needs the GNAT runtime's specs
(`Ada.*`, `Interfaces.*`, `GNAT.*`, `System.*`) to be resolvable. Without
them, Libadalang fails to resolve any statement that mentions a runtime
entity — *including the project's own names in that statement* — which shows
up as false positives in queries such as `ada/unused-parameter`. It is found
by:

1. **`CODEQL_EXTRACTOR_ADA_RUNTIME`** — an explicit directory containing the
   runtime's `.ads` files (GNAT's `adainclude`).
2. **`gcc -print-file-name=adainclude`** — works whenever a GNAT toolchain is
   installed (e.g. Debian/Ubuntu `apt install gnat`).

If neither yields a directory, extraction still succeeds but records a
`no-runtime` warning diagnostic (and prints it) saying resolution is
degraded. A `.gpr` project finds its runtime through the toolchain on its
own, so none of this applies to modes 1 and 2 above.

### Predefined pseudo-sources

In every mode, package `Standard` and the runtime units your code refers to
*directly* are extracted too, so that `Float`, `Constraint_Error` or
`Ada.Text_IO.Put_Line` resolve to real declarations (D-026). They are marked
as predefined: `Standard` appears at the pseudo path
`/__codeql_ada_predefined__/standard.ads`, runtime units at their real paths,
and no query reports anything inside them. Units reached only indirectly
through the runtime itself are not extracted. The extractor's summary line
reports their number as `predefined_files`.

## Parallelism

Extraction runs one file per worker process, controlled by
**`CODEQL_EXTRACTOR_ADA_JOBS`** (default: number of CPUs). Each worker loads
its own Libadalang analysis context — contexts aren't thread-safe or
picklable, so this is process-based parallelism, not threads. Each worker
also re-parses the dependency closure needed for name resolution, so
speedup is sublinear (measured: 228s → 76.6s at 12 jobs on a 345-file
project — see [BURNDOWN.md](../BURNDOWN.md) Phase 3.5) — still a large win,
just don't expect it to scale linearly with core count. Set the variable to
`1` to force single-process extraction (useful when debugging a specific
file's extraction).

## Parse errors and diagnostics

A file that doesn't parse cleanly does not fail the extraction run. Every
parse error Libadalang reports becomes a row in the database's
`diagnostics` relation (the same mechanism CodeQL's UI and
`codeql database interpret-results` use to surface build problems), tagged
`parse-error`, and extraction continues with whatever Libadalang could
recover. A file with parse errors still contributes whatever AST it
produced to the database — it's not silently dropped.

Name-resolution failures are different: if resolving a specific reference or
expression type raises an internal Libadalang error, the extractor catches
it, counts it, and moves on — that reference simply doesn't get an
`ada_xref`/`ada_expr_type` row. These are *not* recorded as diagnostics in
the database; they only show up in the extractor's own per-file summary line
on stdout (`nameres_errors` in the `{'nodes': ..., 'xref': ..., ...}`
counters), which CI's corpus regression check tracks over time. If your
queries are getting fewer results than expected on a file, check the build
log's summary line before assuming the query itself is wrong.

## Database rebuild policy (pre-1.0)

There is no upgrade path between dbscheme versions before 1.0 (decision
D-011): a new release means you re-run `codeql database create` from
scratch, not migrate an existing database. This is a deliberate simplicity
trade-off while the schema can still change — writing and testing
upgrade/downgrade scripts for a schema that isn't stable yet would be waste.
Once there's a 1.0 dbscheme and external users depending on database
longevity, this policy is revisited.

## Known limitations

- **Same-kind-same-span node merging.** A node's identity in the database is
  computed from `(file, kind, source span)` — this is what makes cross-file
  references possible without a global counter shared across worker
  processes (see [Parallelism](#parallelism)), but it means two distinct AST
  nodes of the *same kind* at the *exact same source span* would collapse
  into one row. This is a pathological, rare case in practice; it hasn't
  been observed to affect any of the shipped queries or the 5-project test
  corpus, but a query relying on such nodes being distinct could see merged
  results.
- **Generic instantiation bodies** aren't modeled as separate instantiated
  copies in the database — `ada_generic_instantiation` links an
  instantiation to the *generic* declaration it instantiates, not to a
  synthesized instance body. Queries that need to reason about what a
  specific instantiation's body actually does (as opposed to the generic
  template) aren't supported yet, and a call to an instance
  (`procedure P is new G (...)`, then `P (X)`) does not resolve to a target.
- **What data flow does not follow (v1).** There is a control-flow graph
  and a data-flow and taint-tracking library that follows values across
  subprograms (see [query-writing.md](query-writing.md), "Data flow and taint
  tracking"). It does not follow: dispatching calls (bound to their static
  target), calls through access-to-subprogram values, calls to generic
  instances, values stored in record components, array elements or
  containers, and variables of enclosing subprograms or packages written by a
  nested subprogram. A query built on it misses flows through these, and a
  query that needs to *prove* something (that storage is freed, say) reports
  them as unproven. The full list is in
  [dataflow-design.md](dataflow-design.md), "Named v1 limitations".

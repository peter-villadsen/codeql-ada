# Changelog

## 0.2.0 (2026-10-09)

The first release meant for people other than its author. Databases built with 0.1.0
cannot be read by 0.2.0: rebuild them (the database format is pre-1.0, see
[docs/user-guide.md](docs/user-guide.md), "Database rebuild policy").

### What changes in your results

- **Far fewer false positives.** On the five-project test corpus (adasat, alire, gpr2,
  libadalang-tools, libkeccak), results fell from 11,520 to about 2,200, nearly all of
  the difference false positives. The causes, each fixed: pragmas inside statement
  lists broke the control-flow graph; calls to `No_Return` subprograms were treated as
  returning; `unused-*` queries took a name that did not resolve (a missing dependency)
  as unused; specs and bodies were paired by name text; and the names GNAT treats as
  deliberately unused (`Dummy`, `Ignore`, `Unused_...`) were reported. The per-query
  analysis is in [docs/phase9.6-corpus-triage.md](docs/phase9.6-corpus-triage.md) and
  [docs/v0.2.0-precision-check.md](docs/v0.2.0-precision-check.md).
- **New query: `ada/command-line-injection`**, a path query from `Ada.Command_Line.Argument`
  to the command run by `GNAT.OS_Lib.Spawn`, `GNAT.Expect` and imported C `system`,
  `popen` and `exec*`, across subprogram boundaries.
- **`ada/direct-recursion` finds more**: recursive expression functions, calls without
  parentheses, prefixed-view calls (`Obj.Op`), calls through renamings, recursive
  generics.
- **Messages name the code.** Results show `Free_All`, `X`, `... = ...`,
  `raise Constraint_Error` where they showed `SubpBody`, `ParamSpec`, `RelationOp`,
  `RaiseStmt`.
- **Runtime entities resolve.** Package `Standard` and the GNAT runtime units a project
  uses are extracted, so queries match `Ada.Text_IO.Open` by meaning, through `use`
  clauses and renamings, instead of by spelling.

### For query writers

- **Queries read like CodeQL for other languages**: `Subprogram`, `Parameter`, `Call`,
  `Type`, `Component`, `Variable` and `Package` classes, AST classes without a `Raw::`
  prefix, and readable `toString`. `Raw::X` still works.
- **Data flow and taint tracking** across subprograms (`codeql.ada.dataflow.DataFlow`,
  `TaintTracking`), with an extensible command-injection model.
- **Worked, tested examples** in [docs/query-writing.md](docs/query-writing.md): three taint
  queries and one listing allocations that are not provably deallocated.
- **AST printing**: VS Code's "View AST", and `scripts/print_ast.py` for text, JSON or
  XML.
- `BasicDecl.getBody()` is renamed `getCompletion()`; use `Subprogram.getBody()` or
  `Package.getBody()` for the usual case.

### Known limitations

Data flow does not follow dispatching calls (bound to their static target), calls
through access-to-subprogram values, calls to generic instances, or values stored in
record components, arrays and containers; GNAT's `finally` parts are not modelled. See
[docs/user-guide.md](docs/user-guide.md), "Known limitations". Linux x86_64 and WSL only.

## 0.1.0 (2026-09-25)

First tagged release: the extractor, the QL library, 24 queries, and CI integration.

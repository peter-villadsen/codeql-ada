# Changelog

## Unreleased (0.4.0)

The control-flow graph is now built on the shared `codeql.controlflow.ControlFlowGraph`
library, as CodeQL for Java's and C#'s are, instead of `codeql.controlflow.Cfg`, which
GitHub means to delete (D-029; `docs/cfg-migration-plan.md`). The database format and the
extractor are unchanged.

### Extractor options

- **`-O ada.<name>=<value>`** on `codeql database create` (or `CODEQL_EXTRACTOR_ADA_<NAME>`):
  `gpr`, `scenario` (gprbuild's `-X`), `target`, `rts` and `config` load the project as
  gprbuild would; `charset` is the source encoding; `extensions` adds file extensions
  besides `.ads`/`.adb`/`.ada` when there is no project; `runtime` and `jobs` as before
  (D-036). A project's sources are read by its `Naming` package (other extensions were
  dropped before).
- **The user guide** has sections on analyzing code built with GNAT and with DDC-I Ada (or
  another non-GNAT compiler): no compiler is needed, a file may hold several units.

### Breaking changes

- **The CFG API is `codeql.ada.controlflow.ControlFlowGraph`**, with Java's names:
  `ControlFlowNode`, `ControlFlow::EntryNode`, `ControlFlow::NormalExitNode`,
  `ControlFlow::ExceptionalExitNode`, `ControlFlow::ExitNode`, `BasicBlock`,
  `EntryBasicBlock`, `dominatingEdge`, `CfgScope`. `codeql.ada.controlflow.Cfg` keeps the
  old names as deprecated aliases for this release (`CfgNode`, `EntryNode`, `ExitNode`,
  `AnnotatedExitNode`, `AstCfgNode`, `getScope()`). `getAControlFlowEntryNode` is gone: a
  statement is reached when `exists(ControlFlowNode n | n.isBefore(s))`.
- **The graph has more nodes.** Most AST nodes have a "before" and an "after" node besides
  the one that represents them (`injects`), and a condition has one "after" node per value.
  An `if`, `case` or loop is represented by a node at its start, not by a join at its end.
- **`BasicBlocks.qll`** exports the shared library's blocks; the join and condition block
  classes are gone (`ExitBlock` is new).

### Control flow

- **GNAT `finally` parts are merged, not split.** The end of a `finally` part continues
  every way it was entered. CodeQL has moved away from splitting; queries that need the
  distinction will use `ControlFlowReachability`.
- **`and then` / `or else` no longer join their values.** The old graph let `A` false in
  `if A and then B` lead to the `then` branch; the new one does not.
- **A `goto` out of a sequence runs its `finally` part**, as Ada does.
- **`case` alternatives are matched in order**, each by its list of choices at once (one
  `match` edge, so the alternative guards its statements, also for `when 2 | 3`), the last
  matching what is left; choices are static and never raise.
- **A `for` loop's variable has a node**, where each iteration starts.

### Feasible paths through `finally` parts

- **`codeql.ada.controlflow.PathReachability`** follows only the paths on which a
  `finally` part continues the way it was entered (D-035). `MissingPairedCall`,
  `ada/function-missing-return` and `ada/unreachable-statement` use it, so the merged
  `finally` parts cost them no precision: a file closed on every real path around a
  `finally` part, and a function that returns through one, are not reported.
- **`ada/unreachable-statement`** now also checks statements in `finally` parts, and finds
  code after a block whose every path returns through its `finally` part.

### Guards

- **`codeql.ada.controlflow.Guards`**, the shared Guards library, as Java has: `Guard`
  with `controls`, `valueControls` (Boolean, null, constant and integer-range values),
  `isEquality`, and implications through `and then`, `or else`, `not`, parentheses and
  SSA variables (`OK := X > 0; if OK then` is guarded by `X > 0`).
- **Data-flow barrier guards use it**: `BarrierGuard` now also sees a check carried by a
  variable or a wrapper function.

### SSA

- **`codeql.ada.dataflow.Ssa`** is a class-based SSA API (`SsaDefinition`,
  `SsaExplicitWrite`, `SsaParameterInit`, `SsaUncertainWrite`, `SsaPhiDefinition`,
  `VariableWrite`), the shared `MakeSsa` module, as Java and C# have.
- A loop's phi is now located at the loop variable rather than at the first read in the
  body; the definitions it merges are unchanged.

### AdaControl parity

Queries for the rules of [AdaControl](https://www.adalog.fr/compo/adacontrol_ug.html)
(issue #73). Each rule's subrules are predicates in `codeql/ada/adacontrol/<Rule>.qll`;
the query checks a fixed default selection of them, until configuration through data
extensions (#7). `docs/adacontrol.md` lists, rule by rule, what is implemented, what the
query checks, and what is left out. The queries carry the tag `adacontrol`.

- **`ada/function-missing-return`** (`Abnormal_Function_Return`) also reports an exception
  handler of a function's body that can complete normally, on its own. A handler the
  control-flow graph does not reach (it raises only at calls and `raise`) is judged by its
  last statement, as AdaControl does.
- **`ada/actual-parameters`** (`Actual_Parameters`): an instance of
  `Unchecked_Conversion` called directly as the actual of a call. The library also has
  `default_used`, `default_not_used` and `default_positional`, for calls and
  instantiations.
- **`ada/allocators`** (`Allocators`): allocators of an anonymous access type, and
  allocators naming another subtype than their access type designates. Allocators by type
  or category are in the library; categories (`TypeCategories.qll`) are shared by the
  rules that take them.


## 0.3.0 (2026-10-11)

Data flow follows much more (components, arrays, containers, shared variables,
dispatching and access-to-subprogram calls, entries), two security queries are new, GNAT
`finally` parts are modelled, and the user guide is now a complete manual. The database
format and the extractor are unchanged since 0.2.0: databases built with 0.2.0 can be
analyzed with 0.3.0's packs without rebuilding. On the five-project test corpus the
result count is unchanged (2,334).

### Breaking change

- **`AdaNode.getEnclosingSubprogram()`** now gives the `Subprogram` whose body most
  closely encloses the node, like Java's `getEnclosingCallable()`. It used to give any
  enclosing subprogram body, at any depth, as an AST node; that is now
  `getAnEnclosingBody()`.

### Data flow follows much more

- **Record components, array elements and standard containers.** A value stored in
  `R.F`, `V (I)`, an aggregate, or an `Ada.Containers` vector, list, map or set
  (`Append`, `Insert`, `Include`, ...) is followed to where it is read back (`R.F`,
  `V (I)`, `Element`, cursors, `for E of V`). Elements of one array or container count
  as one.
- **Package variables and variables shared with nested subprograms.** A value stored by
  one subprogram reaches reads in another, regardless of call order. A qualified
  reference (`Pkg.V`) is the same variable as `V`.
- **Calls to generic subprogram instances** resolve to the generic: `Call.getTarget()` of
  `Free (X)` is `Ada.Unchecked_Deallocation`, and data flow enters the generic's body.
- **Dispatching calls** (a class-wide actual) flow into every override. New:
  `Subprogram.overrides`, `getAnOverride` and `isPrimitiveOf`.
- **Calls through access-to-subprogram values** (`Fn (X)`, `Fn.all (X)`) flow into the
  subprograms whose `'Access` reaches them, including through record components.
- **Task and protected entry calls** pass their actuals to the `accept` statement or
  entry body.
- The "not provably deallocated" example in `docs/query-writing.md` now proves frees
  through shared variables and record components, and uses `Call` instead of matching
  `Free` by its syntax. `docs/known-limitations.md` lists what remains approximate.

### New queries

- **`ada/path-injection`**: data received from the network names a file or directory
  that is opened, created, deleted, renamed or copied (`Ada.Text_IO`,
  `Ada.Streams.Stream_IO`, `Ada.Sequential_IO`, `Ada.Direct_IO`, `Ada.Directories`,
  `GNAT.OS_Lib`). `Ada.Directories.Simple_Name` is a barrier.
- **`ada/sql-injection`**: data received from the network in the text of an SQL
  statement run with `GNATCOLL.SQL.Exec`.
- Both use the new shared sources in `codeql/ada/security/FlowSources.qll`:
  `RemoteFlowSource` (`GNAT.Sockets`, AWS request data) and `LocalUserInput` (command
  line, environment, standard input), each an extension point.

### Control flow

- Calls in the message of `raise E with Msg` and in quantified expressions
  (`for all E of V => P (E)`) are evaluated, so data flow and `Call`-based queries see
  them.
- **GNAT `finally` parts** run however their sequence is left: normally, by `return`,
  by an exception, or by an `exit` from an enclosing loop, and then continue the way
  they were entered (the subprogram returns, the exception propagates, the loop is left).
  The graph has a copy of the `finally` part for each way in, as CodeQL for C# and Ruby
  do for `finally` and `ensure`, so no path enters by `return` and leaves normally. A
  `goto` out of the sequence does not run it.
- An `accept ... do` statement has its own node, where the rendezvous begins.

### Other changes

- **Subprogram metrics**: `Subprogram.getMetrics()` gives `getNumberOfStatements()` and
  `getCyclomaticComplexity()`, like Java's `MetricCallable`.
- **Taint through array elements**: a value stored in one element of an array or
  container (`S (I) := C`, `Append (V, X)`) taints the whole array or container, and an
  element read from a tainted one (`for C of S`) is tainted. A string built or copied
  character by character keeps its taint; before, such flows were missed.
- **The user guide is the complete manual**: setup including the CodeQL CLI, ad-hoc
  queries with worked examples (recursion, statement counts, cyclomatic complexity, SQL
  injection with sources, sinks and barriers), GitHub Actions and Azure DevOps, and
  troubleshooting. Its examples are tests (`ql/test/examples/UserGuide`,
  `ql/test/examples/SqlInjectionCustomSink`).
- The extractor needs glibc 2.38 or newer (Ubuntu 24.04, Debian 13), the oldest its
  bundled libraries require; the docs said Debian 13.
- Taint tracking follows conversion attributes (`X'Image`, `T'Value (S)`, ...) and the
  `Ada.Directories` path builders (`Compose`, `Full_Name`, ...).
- **New query `ada/indirect-recursion`**: a subprogram that calls itself through other
  subprograms (P -> Q -> R -> P), next to `ada/direct-recursion`. 162 results on the
  test corpus, most in gpr2's generated recursive-descent parser.
- `ql/lib/codeql-pack.lock.yml` is no longer committed: VS Code's "View AST" deleted
  it on every run. `codeql pack install ql/lib` regenerates it.

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

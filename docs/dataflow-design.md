# Data-flow design

The data-flow layers on top of SSA (`docs/ssa-design.md`): Task 9.3 (local flow) and
Task 9.4 (cross-procedure flow), with the named v1 limitations `docs/phase9.2-plan.md`
requires (D-023).

## Local flow (Task 9.3)

**Files.** `ql/lib/codeql/ada/dataflow/internal/SsaImpl.qll` instantiates
`codeql/ssa`'s `DataFlowIntegration` as `SsaFlow`, with input module `SsaDataFlowInput`.
`ql/lib/codeql/ada/dataflow/internal/LocalFlow.qll` wraps it as `Node`,
`localFlowStep`, `localFlow` and `BarrierGuard`. Regression test:
`ql/test/library/LocalFlow`. Debug dump: `ql/debug/PrintLocalFlow.ql`.

**Division of labour.** `DataFlowIntegration` builds the SSA part of the graph:
definition, phi and read nodes, post-update nodes for reads, and every step between them,
including phi inputs across branches and loop back edges. It creates expression nodes
only for *reads of tracked variables*. `LocalFlow.qll` adds what it leaves to the
language:

| Addition | Why |
| --- | --- |
| `Node` covers every expression with a CFG node | A value has to be followed from where it is computed (a call result, a literal), not only from variable reads. Reads are the same `Node` whichever layer created them (`fromSsa`). |
| Written value → write definition | `getWrittenValue` in `SsaImpl.qll`: an assignment's right-hand side, an object declaration's initialiser. |
| Value-preserving expression steps | Parenthesised expression, qualified expression (`T'(X)`), the branches of `if` and `case` expressions. |

**Write kinds with no local source.** A parameter's entry write (its value comes from
the caller) and an `out`/`in out` actual's uncertain write (its value comes from the
callee) have no written-value step. Task 9.4 connects them (parameter nodes and
`out`/`in out` write-back, below). A `for` loop variable gets
none either, deliberately: its value is an element of the iterable, not the iterable,
so at most a *taint* step belongs there, never a value step.

**Uncertain writes let the old value through.** `allowFlowIntoUncertainDef` holds for
every uncertain write, because the callee may leave an `out`/`in out` actual unchanged
(D-022). Without this, passing a variable to any procedure with an `in out` formal would
cut its flow.

**Guards: implemented, not stubbed** (the decision `docs/phase9.2-plan.md` asks to be
made explicitly). A guard is any expression whose CFG node ends a basic block with
`BooleanSuccessor` edges: an `if`/`elsif`/`while`/`exit when` condition, or the *left*
operand of `and then`/`or else`. `hasValueBranchEdge` reads that edge,
`guardDirectlyControlsBlock` is edge dominance (`dominatingEdge` plus `dominates`), and
`supportBarrierGuardsOnPhiEdges` keeps its default. This took about 20 lines on the shared
basic-block API. It gives `BarrierGuard`: uses of the checked SSA value, in blocks the
validating outcome controls, are barrier nodes.

The *right* operand of a short-circuit operator is not a guard: it completes normally into
the operator node, which is what branches (`docs/cfg-design.md`, "Short-circuit
operators"). So in `if C and then Is_Safe (X)` only the whole condition branches, and the
check is merely implied by it. `LocalFlow`'s `BarrierGuard` therefore lifts the user's
check through the logical operators: `and then`/`and` true implies both operands true,
`or else`/`or` false implies both false, `not` inverts, and parentheses are transparent.
The test pins a plain guard, a short-circuit operand, the failed branch of `not`
(unguarded), and its other branch (guarded).

**Not value flow, by design.** Operators (`X + 1`), function calls, conversions and
attribute references do not propagate values; they are taint steps and belong to the
taint layer (Task 9.5). Record components, array elements and dereferences are not
tracked (SSA's own scope, D-023).

## Cross-procedure flow (Task 9.4)

**Files.** `ql/lib/codeql/ada/dataflow/internal/DataFlowImpl.qll` implements
`codeql/dataflow`'s `InputSig` as `AdaDataFlowInput` and instantiates the global library
as `AdaDataFlow` (`AdaDataFlow::Global<Config>`). The call model underneath it (which
expressions are calls, what they call, which actual binds which formal) lives in
`SsaImpl.qll`, because the SSA layer's `out`/`in out` write-backs (D-022) need the same
answers. Tests: `ql/test/library/DataFlow/test.ql` (inline expectations,
`-- $ flow=N`) and `Consistency.ql` (the shared library's consistency checks,
`DataFlowConsistency.qll`, all empty). Debug: `ql/debug/DataFlowConsistency.ql` runs the
same checks over any database.

### Calls

A `DataFlowCall` is an expression whose callee resolves (D-021: `ada_xref`, never name
text) to a declaration with its own `SubpSpec`. This is `getCallTarget` in `SsaImpl.qll`.
A call takes one of two syntactic shapes:

- a `CallExpr`: `Foo (X)`, `Pkg.Foo (X)`, `Obj.Op (X)`;
- a bare name, for a call without parentheses: `V := Get;`, `Obj.Op;`. A name counts
  only where it is evaluated (it has a CFG node), which rules out `end` names, renamed
  names and default expressions. It also does not count where it is part of a larger
  callee: a `CallExpr`'s name, a dotted name's suffix, an expanded name's prefix, an
  attribute's prefix (`F'Access`), or a designator.

A dotted callee `P.S` can mean three different things, and the meaning decides the
argument positions:

| `P` | Meaning | Treatment |
| --- | --- | --- |
| a package, a package renaming or instance, or a unit that declares `S` | expanded name | ordinary call |
| a value (it has an `ada_expr_type`) | prefixed view (`Obj.Op`) | `P` is the actual for formal 0, and positional actuals shift by one |
| anything else (unresolved, or no type) | undecidable | not a call (unresolved) |

Prefixed views are common in modern Ada: 5,374 of gpr2's call sites and 947 of alire's
use them, so they had to be handled. A protected operation (`PO.Op`) looks like a prefixed
view, but its prefix is not a formal, so it is left out (see the limitations below).

`viableCallable` starts from the target and follows any subprogram renamings
(`resolveSubpRenaming`). It then takes the `ada_body_part` completion, or keeps the target
when it is itself a body with no separate declaration. A renaming-as-body completion is
followed once more in the same way. Only a result that is a CFG scope survives. A renaming
has the same number, order and modes of formals as what it renames, so binding actuals
through the renaming's own spec is exact even when the renaming changes the formals'
names. A target with no body row (imported, abstract, generic-formal and runtime
subprograms; null procedures, which have no CFG; separate-body stubs) gives no result, so
the call is visibly unresolved (D-021).

### Positions, parameters, arguments

`ParameterPosition` and `ArgumentPosition` are both the 0-based formal index, flattened
across `ParamSpec` groups: in `A, B : in out Integer`, `A` is formal 0 and `B` is formal 1
(`formalAt` in `SsaImpl.qll`). `callActual` binds each actual to one position:

- a named association binds by its designator, compared ignoring case as Ada does;
- a positional association binds by its source position, because Ada puts every
  positional association before every named one;
- in a prefixed view, the prefix is formal 0 and positional actuals shift by one;
- a formal left to its default has no actual.

The formals of the body and of the declaration are matched by position, which Ada's
conformance rules make safe. Formal names are read only from the callee's declaration,
when a named actual is bound.

A `ParameterNode` is a new node for each formal of a body with a CFG that receives a
value, meaning mode `in` or `in out`. It has a local step into the formal's entry
definition (Task 9.2's `paramEntryWrite`). A pure `out` formal gets no parameter node,
because it receives nothing. An `ArgumentNode` is the actual's expression node.

### Returns: two kinds, as D-022 requires

| `ReturnKind` | `ReturnNode` (callee) | `OutNode` (caller) |
| --- | --- | --- |
| `return` | a `return` statement's expression, or an expression function's body | the call expression |
| `out i`, one per formal position | the exit read of the `i`th formal, which is `out` or `in out` | the source of the call's uncertain write-back to the `i`th actual |

The exit read is Task 9.2's synthetic read of an `out`/`in out` formal at its scope's
normal exit (`outOrInOutParamExitRead`), which keeps the formal's last write alive. It is
not an expression, and `DataFlowIntegration` creates nodes only for reads that are. So
`SsaDataFlowInput::Expr` is a union type (`DfExpr`): either an Ada expression or the exit
read of one formal. There is one exit read per formal, not one per exit node, so that the
formals stay separate.

The union type alone did not keep them separate. All of a scope's exit reads sit at the
same CFG node, and `DataFlowIntegration` matches a read node to a variable by position
alone (`ReadNode.readsAt`). A step into one formal's exit read therefore arrives from
every formal read at that node, so `Swap (A, B)` would have returned `B`'s value through
`A`. Each step records which variable it is for, so `LocalFlow.localFlowStep` drops any
step into or out of an exit read of a different variable (`isExitReadOfOther`). The
`Two_Out` and `Swap` cases in the test pin this.

The `OutNode` of an `out i` kind is the `WriteDefSourceNode` of the uncertain write that
Task 9.2 already places at the call for that actual. The value flows into that write's
definition and on to later reads. Because the write is uncertain, the definition also
lets the old value through (Task 9.3's `allowFlowIntoUncertainDef`). So even a callee
that always overwrites its `in out` formal still passes on the caller's old value. This
is a deliberate over-approximation, pinned as `SPURIOUS` in the test.

### Minimal in v1

| Member | v1 |
| --- | --- |
| `DataFlowType` | One type, so `compatibleTypes` always holds. `ada_expr_type` is available if type pruning is wanted later. |
| `Content`, `ContentSet`, `ContentApprox`, `readStep`, `storeStep`, `clearsContent`, `expectsContent` | Empty: no field or element flow. |
| `PostUpdateNode` | None: there are no stores, so a post-update node would never receive anything. For the same reason the `argHasPostUpdate` consistency check is excluded. |
| `jumpStep` | None: package-level variables are not SSA variables. |
| `LambdaCallKind` and the lambda predicates | None: no access-to-subprogram flow. |
| `isUnreachableInCall`, `NodeRegion`, `CastNode`, `localMustFlowStep`, `knownSourceModel`, `knownSinkModel`, `DataFlowSecondLevelScope` | Empty. |
| `nodeIsHidden` | Hides the SSA layer's bookkeeping nodes, except an `out` write-back. That is where a value re-enters the caller, so a path should show it. |

### Named v1 limitations (D-023)

Where a limitation can be expressed as a test, it is pinned in `ql/test/library/DataFlow`
as `MISSING` (a real flow that is not reported) or `SPURIOUS` (a reported flow that cannot
happen):

| Limitation | Effect | Pinned |
| --- | --- | --- |
| **Dispatching calls.** A call binds only to its static target. | A class-wide call misses every override. A call on a specific type is exact. | `MISSING: flow=22` |
| **Access-to-subprogram calls** (`Fn (X)`, `Fn.all (X)`). | Unresolved. | `MISSING: flow=21` |
| **Calls into generic instantiations.** | Unresolved, because the instance has no body row. Calls inside a generic body to its generic formal subprograms are also unresolved. | `MISSING: flow=20` |
| **Task entry calls.** | Unresolved: an entry has no `SubpSpec` target. | `MISSING: flow=24` |
| **Separate bodies.** The call resolves to the `is separate` stub, which has no body row. | Unresolved. | `MISSING: flow=25` |
| **Protected operations** (`PO.Op`). | Left out, because the prefix is not a formal. | `MISSING: flow=31` |
| **Default parameter values.** They are not evaluated in any CFG. | A formal left to its default receives nothing. | `MISSING: flow=27` |
| **Extended return statements** (`return R : T do ... end return`). | Not a return node. | `MISSING: flow=30` |
| **Uncertain write-back.** | The actual's old value survives every `out`/`in out` call. | `SPURIOUS: flow=12`, `flow=15` |
| **Renamings of prefixed views or attributes** (`renames Obj.Op`, `renames T'Image`). | Unresolved. | none |
| **Missing `ada_body_part` rows.** Some declarations that have a body have no row, because Libadalang's `p_body_part` fails or is not reached. | Unresolved. | none (see the corpus numbers below) |
| **No content, no package-level variables, no call-context pruning.** | See "Minimal in v1". | none |

### Measured on the corpus (2026-09-25)

Call sites in project code (`fromSource()`), by how they resolve:

| Project | Resolved | Runtime targets | No body row | Abstract / null / generic formal | Renaming not followed | Prefixed-view calls (of all) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| libkeccak | 525 | 504 | 9 | 452 | 0 | 187 |
| adasat | 131 | 15 | 0 | 2 | 0 | 48 |
| alire | 2,051 | 753 | 91 | 66 | 6 | 947 |
| libadalang-tools | 5,385 | 1,194 | 59 | 19 | 21 | 39 |
| gpr2 | 11,040 | 5,411 | 210 | 228 | 8 | 5,374 |

Runtime subprograms have no bodies because only the runtime specs a project refers to are
extracted (D-026). That is expected, and Task 9.5's source and sink models are built on
those specs. The "no body row" column is a coverage gap in Task 9.1: 1–4% of calls into
project code. That is small enough not to count as stop-and-ask case 3 in
`docs/phase9.2-plan.md`.

The consistency checks are empty on all five projects. A stress configuration (every
string literal as a source, every argument of an unresolved call as a sink) runs in 5–20 s
per project, compilation included. It finds 27 cross-procedure flows in alire, 18 in
libadalang-tools and 80 in gpr2. The alire flows that were checked by hand were real: a
literal passed down into `Locate_In_Path` and on to `Locate_Exec_On_Path`, and a
`return ""` coming back up into the `Full_Path` passed to `GNAT.OS_Lib.Spawn`.

## Taint tracking and the first query (Task 9.5)

**Entry points.** Queries import `codeql.ada.dataflow.DataFlow` and
`codeql.ada.dataflow.TaintTracking`, not the `internal` modules.
`DataFlow::Global<Config>` is value-preserving flow and `TaintTracking::Global<Config>`
adds derived-value steps; both take a `DataFlow::ConfigSig`. `DataFlow` also has the
helpers sources and sinks are written with, all resolving through renamings and `use`
clauses (D-026):

| Helper | Holds / gives |
| --- | --- |
| `isCallTo(call, "Pkg.Sub")` | `call` invokes the subprogram with that qualified name (every overload). |
| `getAnArgument(call)` | Any actual of `call`, positional or named. |
| `isArgumentFor(call, actual, "Formal")` | `actual` is passed for the formal of that name, however it was associated. |
| `isArgumentAt(call, actual, i)` | `actual` is passed for the `i`th formal (0-based). |
| `isParameterOf(node, "Pkg.Sub")` | `node` is an `in`/`in out` formal of that subprogram as it receives the caller's value. |
| `getCallTarget(call)` | The declaration called. |

`docs/query-writing.md`, "Data flow and taint tracking", shows them used.

**Taint steps** (`internal/TaintTrackingImpl.qll`; all are steps between expressions, and
each is pinned in `ql/test/library/TaintTracking`):

| Step | Why |
| --- | --- |
| `A & B` (both `BinOp` and `ConcatOp` chains) | Building a command line by concatenation. |
| Aggregate element to aggregate, allocator operand to allocator, `P` to `P.all` | Stand-ins for the content flow v1 lacks: building an `Argument_List` as `(1 => new String'(X))` keeps `X`'s taint. Coarse: the whole aggregate is tainted, not one element. |
| Type conversion `T (X)`; indexing and slicing `S (I)` | Derived values of the same data. Only a simple or dotted prefix makes a conversion: `T'(...) (I)` indexes, although Libadalang has the qualified expression reference `T`. |
| `Ada.Strings.Unbounded.To_String` / `To_Unbounded_String`, `Ada.Strings.Fixed.Trim`, `Ada.Characters.Handling.To_Lower` / `To_Upper`, `System.OS_Lib.Argument_String_To_List`, `Interfaces.C.To_C`, `Interfaces.C.Strings.New_String` | Runtime functions have no bodies (D-026), so these are summarised "any argument to result". The list is deliberately short; it is the place to add models. |

There are no default sanitizers.

**`codeql/ada/security/CommandInjection.qll`** holds the query's model as extension
points: abstract classes `CommandInjection::Source`, `Sink` and `Barrier`, which a query
importing the module extends by declaring subclasses, plus `CommandInjection::Config` and
`CommandInjection::Flow`. The built-in members:

- **Source:** the result of `Ada.Command_Line.Argument`.
- **Sinks, GNAT runtime:** `Program_Name` and `Args` of every overload of
  `System.OS_Lib.Spawn` and `Non_Blocking_Spawn` (so `GNAT.OS_Lib`, which renames it,
  too); `Command` and `Args` of `GNAT.Expect.Non_Blocking_Spawn`; `Command` and
  `Arguments` of `GNAT.Expect.Get_Command_Output`. Every overload is covered because the
  sink is written by formal name, and all eight `OS_Lib` overloads (GNAT 14
  `s-os_lib.ads`) share those two formals. Formals that name files (`Output_File`,
  `Stdout_File`, `Stderr_File`), carry stdin data (`Input`) or return results are not sinks.
- **Sinks, imported C:** a subprogram imported by `pragma Import` / `Interface` or by
  the `Import` aspect whose external name is `system` or `popen` (its first argument), or
  one of the `exec` family (every argument: the program and its argument vector). The
  external name is the explicit `External_Name` / `Link_Name` (aspect, pragma third
  argument, or named) or else the Ada name lower-cased, GNAT's default for C.
- **Not yet:** `posix_spawn`, `GNAT.Expect.TTY`, and commands assembled in a record
  component or a package-level variable (no content flow, no jump steps).

**`ada/command-line-injection`** (`ql/src/queries/CommandLineInjection.ql`, path-problem)
is `CommandInjection::Flow` restricted to sinks in project code. Its test
(`ql/test/queries/CommandLineInjection`) routes every tainted value through at least one
intermediate subprogram, and covers:
- a function result followed by concatenation;
- an `Argument_List` aggregate;
- named associations in a different order from the formals;
- each of the sink kinds above;
- four negative cases: `Output_File`, a constant command, `Get_Command_Output`'s
  `Input`, and `popen`'s mode argument.

A second test, `RuntimeResolves.ql`, counts the fixture's calls that resolve to `Argument`
and to `Spawn`. If the GNAT runtime was not found it has no rows and fails, so the query
cannot go blind without the test noticing.

**Path display.** A path shows the source call, each formal parameter it enters, any taint
step that ends a local step (for example `... & ...`), and the sink. Steps inside a
procedure that only copy a value are folded away by the shared library. Node labels are
close to source text (`Argument (...)`, `[param] Cmd`, `Argument_String_To_List (...).all`).

**On the corpus (2026-10-03).** `codeql database analyze` with this query completes on all
five projects in 7–28 s each, with no errors and **no results**. None of them passes a
command-line argument to a command sink, so this is the expected outcome rather than
evidence of blindness: `RuntimeResolves` shows that both ends resolve when the runtime is
present. Task 9.6 judges precision on the full suite.

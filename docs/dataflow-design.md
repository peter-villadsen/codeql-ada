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
`out`/`in out` write-back, below). A `for` loop variable has no
written-value step either: `for C in V.Iterate` gets a value step from the iterable (a
cursor stands for its container), `for E of V` a read of `V`'s element content (see
"Content and shared variables").

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
A call takes one of three syntactic shapes:

- a `CallExpr`: `Foo (X)`, `Pkg.Foo (X)`, `Obj.Op (X)`;
- an operator application (`UnOp`, `BinOp`) whose operator resolves to a user-written
  subprogram (`function "/" (L : Path; R : Relative) return Path`, or a renaming such
  as `"+" renames To_Unbounded_String`). The operands bind formals 0 and 1 by position.
  Predefined operators do not resolve (D-026), so they stay plain expressions. Added in
  Task 9.6: alire builds paths with a user `"/"` and converts strings with `"+"`, and
  flow through them was lost;
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
use them, so they had to be handled. A protected operation (`PO.Op (X)`) looks like a
prefixed view, but its prefix is the protected object, not a formal, so its actuals bind
as written, with no shift. That also holds for an object of a protected type
(`Obj.Op (X)`), which the prefixed-view rule would otherwise claim (Task 9.6; `flow=31`,
`flow=37`).

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
| `return` | a `return` statement's expression, or an expression function's body, or the read of an extended return's object at the statement (Task 9.6) | the call expression |
| `out i`, one per formal position | the exit read of the `i`th formal, which is `out` or `in out` | the source of the call's uncertain write-back to the `i`th actual |

The exit read is Task 9.2's synthetic read of an `out`/`in out` formal at its scope's
normal exit (`outOrInOutParamExitRead`), which keeps the formal's last write alive. It is
not an expression, and `DataFlowIntegration` creates nodes only for reads that are. So
`SsaDataFlowInput::Expr` is a union type (`DfExpr`): either an Ada expression or the exit
read of one formal. There is one exit read per formal, not one per exit node, so that the
formals stay separate. An extended return statement gets the same treatment: a synthetic read
of its object at the statement's node (`extendedReturnRead`), which is a `return`-kind
return node.

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

### Content and shared variables

**Files.** `ql/lib/codeql/ada/dataflow/internal/Content.qll` (the shapes),
`DataFlowImpl.qll` (`readStep`, `storeStep`, `jumpStep`). Regression tests:
`ql/test/library/ContentFlow`, and the cases from `flow=38` on in
`ql/test/library/DataFlow`.

**Content.** One content per record component (`Component`), and one for all the
elements of an array or container: indices are not told apart.

| Shape | Step |
| --- | --- |
| `R.F := X`, `V (I) := X` | store `X` into the post-update node of `R` / `V`; a nested target (`R.P.A := X`) stores that post-update node into its own prefix's in turn. `Ptr.all.F` is `Ptr.F`. |
| `R.F`, `V (I)` | read from the prefix. `V (I)` is a call-shaped name with no subprogram target, not a type, whose actual is not a range (a slice is a whole array). User-defined indexing on a container (`Vec (1)`, `Map ("k")`) does not resolve to a call, so it is read the same way. |
| `(F => X)`, `(1 => X)`, `(others => X)`, positional array aggregate | store `X` into the aggregate. A positional *record* aggregate stores nothing. |
| `for E of V` | read an element of `V` into `E`'s definition. |
| `Ada.Containers` `Append`, `Prepend`, `Insert`, `Include`, `Replace`, `Replace_Element` | store `New_Item` into the write-back of the `in out` `Container` actual. |
| `Element`, `First_Element`, `Last_Element`, `Constant_Reference`, `Reference` | read from the `Container` or `Position` actual. |
| `First`, `Last`, `Find`, `To_Cursor`, `Next`, `Previous`, `Floor`, `Ceiling`, `Iterate` | a value step: the cursor stands for its container. |

The container bodies are not extracted (D-026), so these are models, matched by
qualified name under `Ada.Containers.` and by formal name.

**Post-update nodes.** `codeql/ssa` gives every variable read one; an updated prefix that
is not a variable read (`R.P` in `R.P.A := X`) gets its own (`TPostUpdateNode`). For the
post-update node of a variable to reach the next read, the variable needs a definition
even before its first whole write, so an object declared without an initialiser and an
`out` formal get a write with no value at their scope's entry (`uninitializedWrite`).

**Shared variables.** SSA tracks a variable within one subprogram. A package variable, or
a variable of an enclosing subprogram used by a nested one, also flows between
subprograms by `jumpStep`: from each value stored into it (assignment, initialiser) to
each read of it in a different subprogram, regardless of call order. Two refinements
keep this from swamping local precision: a read reached by a certain write in its own
subprogram is not a jump target, and each resolved call is an uncertain write of every
variable that is read in the caller and stored into elsewhere (`callMayWrite`), so a
write before a call does not hide what the callee stores. A qualified reference
(`Store.G`) is the same variable as `G`.

### Minimal in v1

| Member | v1 |
| --- | --- |
| `DataFlowType` | One type, so `compatibleTypes` always holds. `ada_expr_type` is available if type pruning is wanted later. |
| `ContentSet` | A single content; `ContentApprox` is the content itself. `clearsContent` and `expectsContent` are empty: a store does not clear the other components, and a whole write of the variable is what replaces them. |
| `jumpStep` | Shared variables only, order-insensitive (see "Content and shared variables"). |
| `LambdaCallKind` | One kind. `lambdaCreation` is `P'Access` (also `'Unchecked_Access`, `'Unrestricted_Access`); `lambdaCall` is `Fn (X)` or `Fn.all (X)` where `Fn` is of an access-to-subprogram type, whose profile binds the actuals (`CallResolution::accessCallSpec`). `additionalLambdaFlowStep` carries an access value from a store into a record component to every read of that component. |
| `isUnreachableInCall`, `NodeRegion`, `CastNode`, `localMustFlowStep`, `knownSourceModel`, `knownSinkModel`, `DataFlowSecondLevelScope` | Empty. |
| `nodeIsHidden` | Hides the SSA layer's bookkeeping nodes, except an `out` write-back. That is where a value re-enters the caller, so a path should show it. |

### Named v1 limitations (D-023)

Where a limitation can be expressed as a test, it is pinned in `ql/test/library/DataFlow`
(or `ContentFlow`) as `MISSING` (a real flow that is not reported) or `SPURIOUS` (a reported flow that cannot
happen):

| Limitation | Effect | Pinned |
| --- | --- | --- |
| **Dispatching goes to every override.** A call dispatches when an actual for a controlling parameter is class-wide: a `T'Class` conversion, or an object, parameter or access value declared `T'Class`. Its callables are the static target and every override (`Subprogram.overrides`: same name and parameter count, primitive of a descendant type). Interfaces are not covered. | Flow into an override the actual object never has. A call on a specific type is exact. | `flow=22` (four shapes) |
| **Access-to-subprogram values in components** reach every call through that component (`additionalLambdaFlowStep`), whatever the object. | A callback stored in one record reaches calls through another of the same type. | `flow=46` |
| **Generics have one body for all instances.** A call to a generic subprogram instance (`function Inst is new G`) targets the generic `G` (`CallResolution::instanceGeneric`), and a subprogram of a generic *package* instance resolves to its declaration in the generic: either way flow enters the generic's single body, shared by all instances, and each return still goes back to its own call site. Calls inside a generic body to its generic formal subprograms are unresolved. | `flow=20`, second instance clean; package instance `flow=32` |
| **Entries pass values in only.** An entry call's actuals jump to the formals of each `accept` statement for the entry (in the body of the task that declares it, matched by name) and of its entry body; an `accept` statement has its own CFG node, where its formals are written. | Values passed back through an entry's `out` formals are lost. | `flow=24`, `flow=47` |
| **Default parameter values are evaluated in the callee** (Task 9.6). Ada evaluates a default at each call that omits the actual; the CFG evaluates it once at the callee's entry. | The default's value reaches the formal on every call, including those that pass an actual. | `flow=27`; `SPURIOUS: flow=36` |
| **Uncertain write-back.** | The actual's old value survives every `out`/`in out` call. | `SPURIOUS: flow=12`, `flow=15` |
| **Renamings of prefixed views or attributes** (`renames Obj.Op`, `renames T'Image`). | Unresolved. | none |
| **Shared variables ignore call order** (`jumpStep`). | A store into a package variable, or into a variable shared with nested subprograms, reaches every read of it in another subprogram, including reads that run before the store and stores in subprograms never called. | `SPURIOUS: flow=40`, `flow=42`, `flow=43` |
| **Content is coarse.** Array and container elements share one content; map keys are not tracked; a positional record aggregate stores nothing; a container outside `Ada.Containers`, or an operation not in the model, is not followed. | `V (1) := X` reaches `V (2)`; `(Source, 0)` assigned to a record loses the value (taint tracking still marks the record). | `ContentFlow`: `MISSING: flow=11`; `flow=3` reaching `V1 (2)` |
| **No call-context pruning.** | See "Minimal in v1". | none |

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

**Closed (2026-10-03).** The gap had one cause. Libadalang pairs a spec with its body by
checking that their profiles conform, which needs the formals' types resolved, so a type
from a missing dependency made the pairing raise or return nothing (alire's
`Put_Info (Text : String; Level : Trace.Levels := Info)`). The extractor now falls back to
a syntactic pairing for a subprogram declaration with no body: same name, kind, formal
names and modes in the matching region, with the type text breaking ties. It also pairs a
`separate` stub with its subunit's body. Calls to a project declaration with no body row,
re-measured:

| Project | Before | After | Of which imported |
| --- | ---: | ---: | ---: |
| alire | 91 | 4 | 3 |
| gpr2 | 210 | 207 | 206 |
| libadalang-tools | 59 | 59 | 42 |
| libkeccak | 9 | 11 | 11 |

libkeccak's count rose because two imported SIMD operators became calls when user-defined
operators did. Apart from imported foreign subprograms, what remains is 17 test-suite
specs in libadalang-tools whose bodies are not in the repository, plus one call each in
alire and gpr2. libadalang-tools' count did not drop: its remaining gaps were never
pairing failures.

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
| Conversion attributes: `T'Image (X)`, `X'Image`, `X'Img`, `T'Value (S)`, `T'Val (N)`, `T'Pos (X)` (and the wide forms) | The same data as text, or text as a value. From the argument, or from an object prefix (`X'Image`). `T'Image (X)` parses as a call whose name is the attribute; both shapes are covered. |
| `Ada.Strings.Unbounded.To_String` / `To_Unbounded_String`, `Ada.Strings.Fixed.Trim`, `Ada.Characters.Handling.To_Lower` / `To_Upper`, `System.OS_Lib.Argument_String_To_List`, `Interfaces.C.To_C`, `Interfaces.C.Strings.New_String`, and the `Ada.Directories` path builders `Compose`, `Full_Name`, `Containing_Directory`, `Simple_Name`, `Base_Name`, `Extension` | Runtime functions have no bodies (D-026), so these are summarised "any argument to result". The list is deliberately short; it is the place to add models. (`ada/path-injection` treats `Simple_Name` as a barrier.) |

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
  component (no content flow).

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

**Exploratory taint on the corpus (Task 9.6).** `ql/debug/ExploratoryTaint.ql` widens the
sources (environment variables, `Get_Line`, `GNAT.Command_Line`) and adds file-name sinks.
It finds 23 paths, all real flows and none a vulnerability, including one through three
subprograms and a generic package instance. Details, and why alire shows none, are in
[phase9.6-corpus-triage.md](phase9.6-corpus-triage.md).

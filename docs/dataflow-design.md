# Data-flow design

The data-flow layers on top of SSA (`docs/ssa-design.md`). Task 9.3 (local flow) is
recorded here; Task 9.4 (cross-procedure flow) extends this document with its own design
and the named v1 limitations `docs/phase9.2-plan.md` requires.

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
callee) have no written-value step. Task 9.4 connects them. A `for` loop variable gets
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

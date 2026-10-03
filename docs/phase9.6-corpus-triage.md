# Task 9.6 — corpus validation and triage (2026-10-03)

The full query suite and an exploratory taint configuration, run over the five pinned
corpus projects (`scripts/corpus.json`), with a hand triage of a sample of results.
The headline finding: **about 70% of all 11,520 results trace to four causes**, and
two of the four are defects in the control-flow graph that also hide code from SSA and
data flow. The dataflow engine itself produced no false positive in the paths
examined.

## How it was run

```sh
python3 scripts/corpus_regression.py          # re-extract; compare to corpus_baseline.json
python3 scripts/corpus_queries.py             # all 25 queries; counts per query
```

`corpus_queries.py` is new in this task. It runs `codeql database analyze` over each
database, keeps the SARIF, and compares counts with `scripts/corpus_query_baseline.json`,
which records the counts below. Before this, only per-project totals were ever recorded,
so the earlier totals (after burndown 8.12a: adasat 34, alire 2,095, gpr2 5,039,
libadalang-tools 3,804, libkeccak 350) cannot be broken down by query.

The extraction regression is green: file counts and parse errors equal the baseline.
gpr2 resolved 98 fewer cross-references and 91 fewer types than the baseline, and had 9
more resolution errors. Libadalang varies by about that much from run to run, and the
script reports it as a warning.

Samples were drawn with a fixed seed (9006), not hand-picked.

## Counts

| Query | gpr2 | adasat | libadalang-tools | alire | libkeccak | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| unused-local | 1,631 | 0 | 1,262 | 832 | 8 | 3,733 |
| unused-parameter | 1,630 | 0 | 1,015 | 904 | 10 | 3,559 |
| unreachable-statement | 234 | 12 | 811 | 38 | 298 | 1,393 |
| dead-local-subprogram | 339 | 1 | 305 | 125 | 7 | 777 |
| goto-statement | 566 | 0 | 36 | 9 | 0 | 611 |
| unused-with-clause | 342 | 0 | 18 | 12 | 0 | 372 |
| raise-predefined-exception | 91 | 0 | 161 | 71 | 2 | 325 |
| todo-comment | 58 | 2 | 14 | 48 | 0 | 122 |
| direct-recursion | 77 | 0 | 15 | 13 | 0 | 105 |
| unchecked-deallocation | 72 | 5 | 12 | 3 | 8 | 100 |
| warnings-off | 36 | 1 | 55 | 4 | 0 | 96 |
| unchecked-conversion | 74 | 3 | 7 | 1 | 8 | 93 |
| hardcoded-credential | 51 | 0 | 0 | 3 | 0 | 54 |
| function-missing-return | 11 | 0 | 7 | 35 | 0 | 53 |
| empty-loop-body | 1 | 0 | 49 | 0 | 0 | 50 |
| open-without-close | 6 | 0 | 28 | 0 | 0 | 34 |
| pragma-suppress | 3 | 0 | 8 | 0 | 0 | 11 |
| useless-if | 4 | 0 | 7 | 0 | 0 | 11 |
| self-comparison | 0 | 0 | 10 | 0 | 0 | 10 |
| exception-swallowing | 3 | 0 | 0 | 2 | 0 | 5 |
| boolean-literal-comparison | 1 | 0 | 0 | 3 | 0 | 4 |
| float-equality | 0 | 0 | 2 | 0 | 0 | 2 |
| command-line-injection | 0 | 0 | 0 | 0 | 0 | 0 |
| identical-operands, spark-mode-off | 0 | 0 | 0 | 0 | 0 | 0 |
| **Total** | **5,230** | **24** | **3,822** | **2,103** | **341** | **11,520** |

**This session's two CFG fixes changed nothing here.** Those fixes were the `&` chain
(97d1c5e) and membership alternatives (bbdbdeb). With the query library checked out from
before them, the five CFG and call-graph queries give identical result sets on all five
databases: same rule, file, line and column.

## Triage by query

| Query | Sampled | Verdict | Cause |
| --- | --- | --- | --- |
| unreachable-statement | 5 | 5 false positives | **CFG defects** A and B below. Of the 1,393 results, 1,215 are pragmas in statement lists. 49 are `for` loops over a subtype indication, and libkeccak's 82 "other" results are the bodies of such loops. |
| unused-local, unused-parameter | measured, then 5 sampled | ~94% (6,945 of 7,292) have an **unresolved** identifier of the same name in the same body | **Missing dependencies** (C below). Of the rest, the 5 sampled were 4 objects marked `with Unreferenced` (the query ignores the aspect, defect E) and 1 intentionally unused parameter `Unused_Stop`. |
| dead-local-subprogram | 4 | 4 false positives | Every call site is unresolved (missing Libadalang dependency in libadalang-tools), and the query has no textual fallback (C). |
| function-missing-return | 53, all classified | 38 end in a call to a `No_Return` procedure (**CFG defect D**); the 3 others read also call one, but the call does not resolve | No true positive found. |
| direct-recursion | 3 | 3 true positives (intended recursion: tree printing, environment walks) | Informational query; as designed. |
| hardcoded-credential | 4 | 4 false positives | "token" in lexer names (`Token_Kind_Name_5`, `Protected_Token`). Name heuristic. |
| self-comparison | 3 | 3 true positives | Pretty-printer test fixtures that are deliberately odd code. |
| open-without-close | 3 | 1 true positive (a test helper never closes its files), 2 false positives | The two closes are conditional (`if Is_Open (F) then Close (F)`), and the query is path-insensitive. That is the documented limit of CFG-only pairing. |

The syntactic queries (`goto-statement`, `todo-comment`, `warnings-off`,
`unchecked-*`, `unused-with-clause`, `raise-predefined-exception`, ...) were not
sampled in this round. Phase 9 did not change them.

## Exploratory taint (`ql/debug/ExploratoryTaint.ql`)

The shipped dataflow query, `command-line-injection`, has no results on the corpus. To
exercise data flow on real code, a developer-only configuration widens the sources:
environment variables, `Ada.Text_IO.Get_Line` and `GNAT.Command_Line`. It adds
file-name parameters of the file and directory APIs to the command sinks.

**Result: 23 paths. All are real flows; none is a vulnerability.**

| Project | Paths | What they are |
| --- | ---: | --- |
| gpr2 | 3 | A project file opened by a name read from the environment; two test programs creating files named by their arguments. |
| libadalang-tools | 19 | 18 test helpers passing `Argument (N)` straight to `Open`/`Create`; `gnatpp` reading pairs of file names from its own scratch file and moving/deleting those files, through `Utils.String_Utilities.Move_File`. |
| libkeccak | 1 | A test runner opening the test-vector file named on its command line, through three subprograms and a generic package instance (33 instances share the one body). |

(`Get_Line (File)` reads a file, not standard input; the exploratory query's label for
that source is imprecise.)

**Why alire has none.** alire has both ends: 3 `Spawn` calls, 10 `Copy_File`, and 5
calls to `GNAT.OS_Lib.Getenv` inside its own `Getenv` wrappers. A focused check showed
that taint does reach all 20 call sites of those wrappers. It is lost afterwards, for
three independent reasons:

1. **User-defined operators are not calls** (new limitation F). alire converts with a
   user-defined `"+"` everywhere: `+OS_Lib.Getenv (+Key)`. 213 unary and 153 binary
   operator nodes in alire resolve to a user-written function, but data flow treats an
   operator application as an expression, not a call, so taint stops there.
2. **Element-wise construction:** `Arg_List (I) := new String'(Args (I))`. Without
   content flow, a write to an array element is not tracked (documented, D-023).
3. **Generic containers:** `Args` is an `AAA.Strings.Vector`, and `Args (I)` goes
   through a generic instance (documented).

## Defects and limitations found

Recorded per D-023. The CFG items need approval before `ControlFlowGraphImpl.qll` is
changed (docs/phase9.2-plan.md §6.2).

| | What | Effect | Kind |
| --- | --- | --- | --- |
| **A** | A `pragma` inside a statement list has no CFG tree. | The statement chain breaks there. The pragma and *everything after it* in the list are unreachable to the CFG, SSA and data flow. 1,215 false positives in `unreachable-statement`. Heaviest in SPARK-style code (`pragma Assert`, `Loop_Invariant`). | CFG defect |
| **B** | A `for` loop whose iteration part is a subtype indication (`for I in Natural range A .. B`) has no first node. | The loop, its body, and everything after it are unreachable. 49 loops flagged, plus their bodies. | CFG defect |
| **C** | `unused-local`, `unused-parameter` and `dead-local-subprogram` decide "unused" from resolved references only. | When the project's dependencies are absent, statements fail to resolve and every name in them looks unused: about 7,000 false positives. The project's own rule for queries (D-026: match semantically, fall back to text only when a name does not resolve at all) is not applied in these three. | Query defect |
| **D** | Calls to `No_Return` subprograms (aspect or pragma) are modelled as returning. | `function-missing-return` reports functions ending in such a call: 38 of 53. The aspect is often on the spec while calls inside the body resolve to the body, so both must be checked. | CFG defect |
| **E** | `unused-local` ignores `with Unreferenced`. `unused-parameter` honours `pragma Unreferenced` but not the aspect. | Intentional guards are reported (67 aspect uses in alire alone). | Query defect |
| **F** | User-defined operators (`function "+" ...`) are not calls to the data-flow library. | Flow through them is lost. | New v1 limitation |
| **G** | The limitation "calls into generic instantiations are unresolved" was too broad. | Only calls to a generic *subprogram* instance are unresolved. A subprogram of a generic *package* instance resolves into the generic's single body, and returns stay matched to their call sites. Now pinned as `flow=32` in `ql/test/library/DataFlow`. | Doc correction |
| **H** | `hardcoded-credential` matches "token" in lexer names. | 4 of 4 sampled false positives in gpr2. | Heuristic |

Also seen, already documented: path-insensitive pairing in `open-without-close`, and
resolution failures when dependencies are missing (user guide, "Project discovery and
name-resolution quality").

## What to do next

In order of results removed per hour of work:

1. **C and E**: query-only changes to three queries, following D-026. Expected to
   remove about 7,000 false positives.
2. **A, B and D**: CFG changes. A pragma becomes a no-op step, a `for` loop over a
   subtype indication enters at its constraint, and `No_Return` calls complete only
   abruptly. These remove about 1,400 false positives and, more importantly, make the
   code after pragmas visible to SSA and data flow.
3. **F**: model operator applications that resolve to a user subprogram as calls, with
   the operands as positional actuals. This is the gap that blinds data flow in alire.
4. **H**: a narrower name heuristic.

After 1–3, re-run `corpus_queries.py`; the baseline shows the change per query.

## Follow-up: C and E fixed (2026-10-03)

`unused-local`, `unused-parameter` and `dead-local-subprogram` now treat an unresolved
identifier spelled like the declaration, inside the same subprogram body, as a possible
use (`BasicDecl.hasUnresolvedNamesakeIn`). They also honour the `Unreferenced` aspect and
pragma (`BasicDecl.isMarkedUnreferenced`). Attribute designators, pragma and aspect
identifiers, declared names and `end` names never count. Each new fixture case was
checked to be reported by the old query and not by the new one.

| Query | Before | After |
| --- | ---: | ---: |
| unused-local | 3,733 | 199 |
| unused-parameter | 3,559 | 73 |
| dead-local-subprogram | 777 | 41 |
| **All queries** | **11,520** | **3,764** |

No other query changed. Spot checks of what was removed: all 8 libkeccak `unused-local`
results (all used, in statements involving the absent AUnit), and 5 sampled from gpr2
(each name is read or assigned in a later unresolved statement). All were false
positives. The cost is false negatives when an unrelated unresolved name happens to match
inside the same body. `scripts/corpus_query_baseline.json` now records the new counts.

## Follow-up: A, B and D fixed (2026-10-03)

A pragma in a statement list is now a no-op step. A `for` loop over a subtype indication
evaluates its range and enters normally. A call to a `No_Return` subprogram (aspect or
pragma, on the callee or on the spec it completes) completes only by raising. New CFG
conformance tests: `Cfg/pragmas`, `Cfg/for-subtype`, `Cfg/no-return`.

| Query | Before | After |
| --- | ---: | ---: |
| unreachable-statement | 1,393 | 34 |
| function-missing-return | 53 | 17 |
| **All queries** | **3,764** | **2,369** |

No other query changed. What remains in `unreachable-statement` (sampled 5):
- two syntactically broken test fixtures (a missing `end`, preprocessor directives);
- a `pragma Annotate (Xcov, Exempt_Off)` after `return`: unreachable by definition, but
  a coverage-tool idiom;
- two exception handlers that look unreachable, a new, smaller limitation **I**: a call
  written without parentheses (`return Id.P_Referenced_Decl;`) is a name, not a
  `CallExpr`, so it gets no raise edge. When the callee is unresolved, as here because the
  Libadalang API is absent, the CFG cannot even tell it is a call. Not fixed.

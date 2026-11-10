/**
 * AdaControl rule `Max_Call_Depth`: the depth of calls, roughly the number of frames a
 * call stacks (`docs/adacontrol.md`). A call of a subprogram that calls nothing has
 * depth 1; if `A` calls `B` and `B` calls nothing, a call of `A` has depth 2.
 *
 * A subprogram without a body in the database (imported, or from the Ada library) is
 * assumed to call nothing, and makes the depth a minimum (`isExact`); so does a
 * recursive subprogram, whose calls have no finite depth. Predefined operators are
 * assumed inlined (depth 0). As in AdaControl, calls through access-to-subprogram
 * values and dispatching calls are counted as calls of their static target, or not
 * at all when there is none.
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Calls
private import codeql.ada.Subprograms

module MaxCallDepth {
  /** The largest depth computed; deeper chains are reported as at least this deep. */
  int maxComputedDepth() { result = 100 }

  /** Holds if `s` is a predefined operator (`"+"` of `Standard`), assumed inlined. */
  predicate isPredefinedOperator(Subprogram s) {
    s.getName().charAt(0) = "\"" and not s.fromSource()
  }

  /** Holds if `caller` contains `c`, a call of `callee` that counts: not a predefined operator. */
  predicate callEdge(Subprogram caller, Call c, Subprogram callee) {
    c.getCaller() = caller and
    callee = c.getTarget() and
    not isPredefinedOperator(callee)
  }

  private predicate calls(Subprogram caller, Subprogram callee) { callEdge(caller, _, callee) }

  /** `finite`: `s` is recursive, directly or through other subprograms. */
  predicate isRecursive(Subprogram s) { calls+(s, s) }

  /** Holds if the calls of `s` are analyzed: it has a body and is not recursive. */
  predicate isAnalyzed(Subprogram s) { exists(s.getBody()) and not isRecursive(s) }

  /** Holds if a call of `s` has depth at least `n` (bounded by `maxComputedDepth`). */
  private predicate depthAtLeast(Subprogram s, int n) {
    n = 1 and exists(Call c | c.getTarget() = s) and not isPredefinedOperator(s)
    or
    n = 1 and isAnalyzed(s)
    or
    isAnalyzed(s) and
    exists(Subprogram t, int m | calls(s, t) and depthAtLeast(t, m) and n = m + 1 and n <= maxComputedDepth())
  }

  /**
   * Gets the depth of a call of `s`: 1 plus the depth of the deepest call in its body.
   * A subprogram that is not analyzed counts 1.
   */
  int depth(Subprogram s) { result = max(int n | depthAtLeast(s, n)) }

  /** Holds if the depth of a call of `s` may be more than `depth(s)`: it reaches a subprogram that is not analyzed. */
  private predicate isMinimum(Subprogram s) {
    not isAnalyzed(s)
    or
    exists(Subprogram t | calls(s, t) and isMinimum(t))
    or
    depth(s) = maxComputedDepth()
  }

  /** Holds if `depth(s)` is exact, not a minimum. */
  predicate isExact(Subprogram s) { exists(depth(s)) and not isMinimum(s) }

  /** Gets the depth of call `c`: the depth of a call of its target. No result for a predefined operator. */
  int callDepth(Call c) { result = depth(c.getTarget()) }

  /** Holds if `depth` of call `c` is exact, not a minimum. */
  predicate isExactCall(Call c) { isExact(c.getTarget()) }

  /**
   * `<allowed depth>`: call `c` has a depth over `limit`, or calls a recursive
   * subprogram (whose depth is not finite).
   */
  bindingset[limit]
  predicate tooDeep(Call c, int limit) {
    callDepth(c) > limit
    or
    isRecursive(c.getTarget())
  }
}

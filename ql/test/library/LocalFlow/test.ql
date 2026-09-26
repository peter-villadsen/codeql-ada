/**
 * Local data flow (Task 9.3): every `Source` call that reaches a `Sink` argument,
 * and whether the sink is a barrier under an `Is_Safe (X)` guard.
 */

import ada
import codeql.ada.dataflow.internal.LocalFlow

/** Holds if `g` is `Is_Safe (e)`, which validates `e` when it is true. */
predicate isSafeCheck(Raw::Expr g, Raw::Expr e, boolean branch) {
  exists(Raw::CallExpr call | call = g |
    call.getName().(Name).getText() = "Is_Safe" and
    e = call.getSuffix().(Raw::AssocList).getChild(0).(Raw::ParamAssoc).getRExpr() and
    branch = true
  )
}

from Node source, Node sink, Raw::CallExpr sinkCall, string guarded
where
  source.asExpr().(Name).getText() = "Source" and
  sinkCall.getName().(Name).getText() = "Sink" and
  sink.asExpr() = sinkCall.getSuffix().(Raw::AssocList).getChild(0).(Raw::ParamAssoc).getRExpr() and
  localFlow(source, sink) and
  if sink = BarrierGuard<isSafeCheck/3>::getABarrierNode() then guarded = "guarded" else guarded = ""
select source, sink, guarded

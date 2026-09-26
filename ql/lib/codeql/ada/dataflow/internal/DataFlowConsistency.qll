/**
 * The shared data-flow library's consistency checks, instantiated over the Ada
 * `InputSig` (Task 9.4). Every result of an imported query predicate is a violation.
 * Used by `ql/test/library/DataFlow/Consistency.ql` and `ql/debug/DataFlowConsistency.ql`.
 *
 * `argHasPostUpdate` is excluded wholesale: v1 has no post-update nodes by design
 * (no content flow, see `docs/dataflow-design.md`). The taint input is empty, since
 * taint tracking is Task 9.5.
 */

private import codeql.dataflow.internal.DataFlowImplConsistency
private import codeql.dataflow.TaintTracking as TT
private import codeql.ada.ast.internal.Raw
private import codeql.ada.dataflow.internal.DataFlowImpl

private module NoTaint implements TT::InputSig<Raw::Location, AdaDataFlowInput> {
  predicate defaultTaintSanitizer(AdaDataFlowInput::Node node) { none() }

  predicate defaultAdditionalTaintStep(
    AdaDataFlowInput::Node src, AdaDataFlowInput::Node sink, string model
  ) {
    none()
  }

  bindingset[node]
  predicate defaultImplicitTaintRead(AdaDataFlowInput::Node node, AdaDataFlowInput::ContentSet c) {
    none()
  }

  predicate speculativeTaintStep(AdaDataFlowInput::Node src, AdaDataFlowInput::Node sink) { none() }
}

private module Input implements InputSig<Raw::Location, AdaDataFlowInput> {
  predicate argHasPostUpdateExclude(AdaDataFlowInput::ArgumentNode n) { any() }
}

import MakeConsistency<Raw::Location, AdaDataFlowInput, NoTaint, Input>

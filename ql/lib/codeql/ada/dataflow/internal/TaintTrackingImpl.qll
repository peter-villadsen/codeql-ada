/**
 * Taint tracking for Ada: Task 9.5, see `docs/dataflow-design.md`.
 *
 * Implements `codeql/dataflow`'s taint-tracking `InputSig` over the data-flow model
 * of Task 9.4 (`DataFlowImpl.qll`). Taint adds, to value-preserving flow, steps
 * where the result is *derived from* an operand without being equal to it:
 *
 * - string concatenation (`A & B`);
 * - aggregates (`(1 => X)`, `(X, Y)`), allocators (`new String'(X)`) and
 *   dereferences (`P.all`) -- standing in for the content flow v1 lacks (D-023),
 *   so that building a `GNAT.OS_Lib.Argument_List` keeps the taint of its elements;
 * - type conversions (`String (X)`), and indexing and slicing (`S (1 .. 3)`);
 * - a few runtime subprograms that only reshape a string, summarised as "argument
 *   to result" because the runtime has no bodies to flow through (D-026).
 *
 * No default sanitizers: a query adds its own barriers.
 */

private import codeql.dataflow.TaintTracking as TT
private import codeql.ada.ast.internal.Raw
private import codeql.ada.dataflow.internal.SsaImpl
private import codeql.ada.dataflow.internal.DataFlowImpl
private import ada

/** Holds if `op` is a concatenation operator node. */
private predicate isConcatOp(Raw::Op op) { op instanceof Raw::OpConcat }

/**
 * Gets the qualified names (lower-cased) of the runtime functions whose result is
 * modelled as tainted by any of their arguments.
 */
private string taintPreservingRuntimeFunction() {
  result =
    [
      "ada.strings.unbounded.to_string", "ada.strings.unbounded.to_unbounded_string",
      "ada.strings.fixed.trim", "ada.characters.handling.to_lower",
      "ada.characters.handling.to_upper", "system.os_lib.argument_string_to_list"
    ]
}

/** Holds if the referenced declaration of `n` is a type, i.e. `n (X)` is a conversion. */
private predicate denotesType(Raw::Name n) {
  n.(Name).getReferencedDecl().(BasicDecl).getUltimateDecl() instanceof Raw::BaseTypeDecl
}

/** Holds if the referenced declaration of `n` is an object or formal, i.e. `n (I)` indexes or slices it. */
private predicate denotesObject(Raw::Name n) {
  exists(Raw::BasicDecl d | d = n.(Name).getReferencedDecl() |
    d instanceof Raw::ObjectDecl or d instanceof Raw::ParamSpec
  )
}

/** Holds if `e2`'s value is derived from `e1`'s (see the module comment). */
private predicate exprTaintStep(Raw::Expr e1, Raw::Expr e2) {
  isConcatOp(e2.(Raw::BinOp).getOp()) and
  e1 = [e2.(Raw::BinOp).getLeft(), e2.(Raw::BinOp).getRight()]
  or
  e1 = e2.(Raw::ConcatOp).getFirstOperand()
  or
  e1 = e2.(Raw::ConcatOp).getOtherOperands().getChild(_).(Raw::ConcatOperand).getOperand()
  or
  e1 = e2.(Raw::BaseAggregate).getAssocs().getChild(_).(Raw::AggregateAssoc).getRExpr()
  or
  e1 = e2.(Raw::Allocator).getTypeOrExpr()
  or
  e1 = e2.(Raw::ExplicitDeref).getPrefix()
  or
  exists(Raw::CallExpr c | c = e2 and not exists(getCallTarget(c)) |
    denotesType(c.getName()) and
    e1 = c.getSuffix().(Raw::AssocList).getChild(0).(Raw::ParamAssoc).getRExpr()
    or
    denotesObject(c.getName()) and e1 = c.getName()
  )
  or
  exists(Raw::BasicDecl target |
    target = resolveSubpRenaming(getCallTarget(e2)).(BasicDecl).getUltimateDecl() and
    target.(BasicDecl).getQualifiedName().toLowerCase() = taintPreservingRuntimeFunction() and
    callActual(e2, e1, _)
  )
}

/** The `codeql/dataflow` taint-tracking input for Ada. */
module AdaTaintTrackingInput implements TT::InputSig<Raw::Location, AdaDataFlowInput> {
  predicate defaultTaintSanitizer(AdaDataFlowInput::Node node) { none() }

  predicate defaultAdditionalTaintStep(
    AdaDataFlowInput::Node src, AdaDataFlowInput::Node sink, string model
  ) {
    exprTaintStep(src.asExpr(), sink.asExpr()) and model = ""
  }

  bindingset[node]
  predicate defaultImplicitTaintRead(AdaDataFlowInput::Node node, AdaDataFlowInput::ContentSet c) {
    none()
  }

  predicate speculativeTaintStep(AdaDataFlowInput::Node src, AdaDataFlowInput::Node sink) { none() }
}

/** The Ada instantiation of the shared taint-tracking library. */
module AdaTaintTracking =
  TT::TaintFlowMake<Raw::Location, AdaDataFlowInput, AdaTaintTrackingInput>;

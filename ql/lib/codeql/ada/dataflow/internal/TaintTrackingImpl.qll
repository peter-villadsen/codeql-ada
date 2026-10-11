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
 * - type conversions (`String (X)`), conversion attributes (`X'Image`,
 *   `T'Value (S)`, `Character'Val (N)`), and indexing and slicing (`S (1 .. 3)`);
 * - a few runtime subprograms that only reshape a string or build a path from its
 *   parts (`Ada.Directories.Compose`), summarised as "argument to result" because the
 *   runtime has no bodies to flow through (D-026).
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
      "ada.characters.handling.to_upper", "system.os_lib.argument_string_to_list",
      "interfaces.c.to_c", "interfaces.c.strings.new_string",
      // paths built from a part
      "ada.directories.compose", "ada.directories.full_name",
      "ada.directories.containing_directory", "ada.directories.simple_name",
      "ada.directories.base_name", "ada.directories.extension"
    ]
}

/**
 * Holds if `n` names a type, so `n (X)` is a conversion. Only a simple or dotted
 * name counts: a qualified expression `T'(...)` also references `T`, but
 * `T'(...) (I)` indexes it.
 */
private predicate denotesType(Raw::Name n) {
  (n instanceof Raw::Identifier or n instanceof Raw::DottedName) and
  n.(Name).getReferencedDecl().(BasicDecl).getUltimateDecl() instanceof Raw::BaseTypeDecl
}

/**
 * Holds if `a` is an attribute that converts its argument to or from text, or between
 * types: `T'Image (X)`, `X'Image`, `X'Img`, `T'Value (S)`, `T'Val (N)`, `T'Pos (X)`.
 */
private predicate isConversionAttribute(Raw::AttributeRef a) {
  a.getAttribute().getValue().toLowerCase() =
    [
      "image", "img", "wide_image", "wide_wide_image", "value", "wide_value",
      "wide_wide_value", "val", "pos"
    ]
}

/** Holds if `e2`'s value is derived from `e1`'s (see the module comment). */
private predicate exprTaintStep(Raw::Expr e1, Raw::Expr e2) {
  // a conversion attribute: from its argument, or from its prefix when that is an
  // object (`X'Image`) rather than a type
  exists(Raw::AttributeRef a | isConversionAttribute(a) |
    a = e2 and e1 = a.getArgs().getChild(_).(Raw::ParamAssoc).getRExpr()
    or
    // `T'Image (X)` parses as a call whose name is the attribute
    exists(Raw::CallExpr c | c = e2 and c.getName() = a |
      e1 = c.getSuffix().(Raw::AssocList).getChild(_).(Raw::ParamAssoc).getRExpr()
    )
    or
    a = e2 and e1 = a.getPrefix() and not denotesType(a.getPrefix())
  )
  or
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
  // A call-shaped name with no subprogram target: a type conversion, or else
  // indexing or slicing, whose prefix may be any name (`List'(...) (1)`). The
  // latter also covers unresolved calls (an access-to-subprogram value flows to
  // the result), which is harmless: such values are rarely tainted.
  exists(Raw::CallExpr c | c = e2 and not exists(getCallTarget(c)) |
    denotesType(c.getName()) and
    e1 = c.getSuffix().(Raw::AssocList).getChild(0).(Raw::ParamAssoc).getRExpr()
    or
    not denotesType(c.getName()) and e1 = c.getName()
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

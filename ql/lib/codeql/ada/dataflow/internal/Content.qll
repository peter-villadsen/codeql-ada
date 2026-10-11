/**
 * Content flow for Ada: values stored in record components and array elements
 * (`docs/dataflow-design.md`, "Content").
 *
 * A store puts a value into a component or an element of an object, a read takes it
 * back out, and in between the object itself carries the content as it is copied,
 * passed and returned. The content of a component is that component; all elements of
 * an array share one content, so indices are not told apart (`V (1) := X` reaches
 * `V (2)`).
 *
 * The syntactic shapes:
 *
 * - **Component access** `R.F`: a dotted name whose suffix is a record component. The
 *   prefix may be an access value (`Ptr.F`, an implicit dereference); an explicit one is
 *   skipped (`Ptr.all.F` is `Ptr.F`).
 * - **Indexing** `V (I)`: a call-shaped name with no subprogram target, not naming a
 *   type, whose single actual is not a range (`V (1 .. 3)` is a slice, which is a
 *   whole array).
 * - **Aggregates**: a named component association (`(F => X)`) stores `F`; any other
 *   association of an array aggregate (`(1 => X)`, `(others => X)`, positional) stores
 *   an element. A positional record aggregate stores nothing: which component each
 *   value goes to is not worked out (taint tracking still marks the whole aggregate).
 * - **Loops**: `for E of V` reads an element of `V` into `E`.
 * - **Standard containers** (`Ada.Containers.*` instances, whose bodies are not
 *   extracted): `Append`, `Prepend`, `Insert`, `Include`, `Replace` and
 *   `Replace_Element` store `New_Item` as an element of `Container`; `Element`,
 *   `First_Element`, `Last_Element`, `Constant_Reference` and `Reference` read one from
 *   `Container` or `Position`; indexing (`V (I)`, `M (K)`) is a read as for an array.
 *   A cursor stands for its container: `First`, `Last`, `Find`, `To_Cursor`, `Next`,
 *   `Previous`, `Floor`, `Ceiling` and `Iterate` pass the container's (or cursor's)
 *   value on, so `Element (C)` reads from the container `C` came from. Map keys are
 *   not tracked.
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.dataflow.internal.SsaImpl
private import ada

private newtype TContent =
  TComponentContent(Component c) or
  TElementContent()

/** A component of a record, or the elements of an array. */
class Content extends TContent {
  /** Gets the record component this content is, if any. */
  Component asComponent() { this = TComponentContent(result) }

  /** Holds if this is the content of an array's elements. */
  predicate isElement() { this = TElementContent() }

  /** Gets a textual representation of this content. */
  string toString() {
    result = "component " + this.asComponent().getName()
    or
    this.isElement() and result = "element"
  }
}

/**
 * Gets `e` with any explicit dereference removed: `Ptr.all.F` is the same component as
 * `Ptr.F`, the object an access value designates.
 */
private Raw::Expr skipDeref(Raw::Expr e) {
  result = skipDeref(e.(Raw::ExplicitDeref).getPrefix())
  or
  not e instanceof Raw::ExplicitDeref and result = e
}

/** Holds if `n` names a type, so `n (X)` is a conversion. */
private predicate denotesType(Raw::Name n) {
  (n instanceof Raw::Identifier or n instanceof Raw::DottedName) and
  n.(Name).getReferencedDecl().(BasicDecl).getUltimateDecl() instanceof Raw::BaseTypeDecl
}

/** Holds if `e` is a range `L .. H`. */
private predicate isRange(Raw::Expr e) { e.(Raw::BinOp).getOp() instanceof Raw::OpDoubleDot }

/**
 * Holds if `e` accesses content `c` of the object `prefix` denotes: `prefix.F` for a
 * component `F`, or `prefix (I)` for an element.
 */
predicate contentAccess(Raw::Expr e, Raw::Expr prefix, Content c) {
  exists(Raw::DottedName d | d = e |
    prefix = skipDeref(d.getPrefix()) and
    d.getSuffix() = c.asComponent().getAnAccess()
  )
  or
  exists(Raw::CallExpr call, Raw::AssocList args | call = e |
    not exists(getCallTarget(call)) and
    not isAccessCall(call, _) and
    not denotesType(call.getName()) and
    args = call.getSuffix() and
    not isRange(args.getChild(0).(Raw::ParamAssoc).getRExpr()) and
    prefix = call.getName() and
    c.isElement()
  )
}

/**
 * Holds if `t` is written by a store: the target of an assignment, or the prefix of
 * such a target that is itself a content access (`R.P` in `R.P.A := X`).
 */
predicate isStoreTarget(Raw::Expr t) {
  contentAccess(t, _, _) and
  (
    t = any(Raw::AssignStmt s).getDest()
    or
    exists(Raw::Expr outer | isStoreTarget(outer) and contentAccess(outer, t, _))
  )
}

/** Holds if `prefix` is the object a store into one of its components or elements updates. */
predicate isUpdatedPrefix(Raw::Expr prefix) {
  exists(Raw::Expr t | isStoreTarget(t) and contentAccess(t, prefix, _))
}

/** Holds if aggregate `agg` stores `value` as content `c`. */
predicate aggregateStore(Raw::BaseAggregate agg, Raw::Expr value, Content c) {
  exists(Raw::AggregateAssoc assoc |
    assoc = agg.getAssocs().getChild(_) and
    value = assoc.getRExpr()
  |
    c.asComponent().getAnAccess() = assoc.getDesignators().getChild(_)
    or
    // an array aggregate: no association names a component
    not exists(Raw::AggregateAssoc a, Component comp |
      a = agg.getAssocs().getChild(_) and comp.getAnAccess() = a.getDesignators().getChild(_)
    ) and
    (
      exists(assoc.getDesignators().getChild(_))
      or
      isArrayAggregate(agg)
    ) and
    c.isElement()
  )
}

/**
 * Holds if positional aggregate `agg` is of an array type: its type is an array type
 * definition, or one derived from or a subtype of it.
 */
private predicate isArrayAggregate(Raw::BaseAggregate agg) {
  exists(Raw::BaseTypeDecl t | ada_expr_type(agg, t) |
    t.(BasicDecl).getUltimateDecl().(Raw::TypeDecl).getTypeDef() instanceof Raw::ArrayTypeDef
  )
}

/** Gets the lower-cased simple name of the `Ada.Containers` subprogram `call` invokes. */
private string containerOperation(Raw::Expr call) {
  exists(string q |
    q = resolveSubpRenaming(getCallTarget(call)).(BasicDecl).getQualifiedName().toLowerCase() and
    q.matches("ada.containers.%") and
    result = q.regexpCapture(".*[.]([a-z_0-9]+)", 1)
  )
}

/** Gets the actual `call` passes for the formal named `formal` (lower case). */
private Raw::Expr actualFor(Raw::Expr call, string formal) {
  exists(int idx |
    callActual(call, result, idx) and
    formalNameAt(resolveSubpRenaming(getCallTarget(call)), idx) = formal
  )
}

/**
 * Holds if container operation `call` stores `value` as an element of the container
 * passed for its `idx`th formal (an `in out` one).
 */
predicate containerStore(Raw::Expr call, Raw::Expr value, int idx) {
  containerOperation(call) =
    ["append", "prepend", "insert", "include", "replace", "replace_element"] and
  value = actualFor(call, "new_item") and
  callActual(call, actualFor(call, "container"), idx)
}

/** Holds if container operation `call` reads an element of `container`, a container or a cursor. */
predicate containerRead(Raw::Expr call, Raw::Expr container) {
  containerOperation(call) =
    ["element", "first_element", "last_element", "constant_reference", "reference"] and
  container = actualFor(call, ["container", "position"])
}

/** Holds if container operation `call` returns a cursor into `container`, a container or a cursor. */
predicate containerCursorStep(Raw::Expr container, Raw::Expr call) {
  containerOperation(call) =
    ["first", "last", "find", "to_cursor", "next", "previous", "floor", "ceiling", "iterate"] and
  container = actualFor(call, ["container", "position"])
}

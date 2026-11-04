/**
 * AdaControl rule `Assignments`: assignments to objects of given types, sliding,
 * duplicated access values, repeated and groupable assignments in a group of
 * consecutive assignments, and right-hand sides that could use the target name `@`
 * (`docs/adacontrol.md`).
 *
 * A *group* is a run of assignment statements of one statement list with nothing but
 * `null` statements between them. As in AdaControl, only targets that are known
 * statically count for `repeated` and `groupable`: a variable, a component of one, or
 * an element at static indices. A dereference or a slice never is.
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Calls
private import codeql.ada.Declarations
private import codeql.ada.adacontrol.TypeCategories
private import codeql.ada.adacontrol.LocalAccess
private import codeql.ada.adacontrol.SimplifiableStatements

module Assignments {
  /* --- groups ---------------------------------------------------------------- */

  /** Holds if `s` is the `i`th child of statement list `list`. */
  private predicate stmtAt(Raw::StmtList list, int i, Raw::AdaNode s) { s = list.getChild(i) }

  /** Gets the next child of `s`'s statement list after `s` that is not a `null` statement. */
  private Raw::AdaNode nextNonNull(Raw::AssignStmt s) {
    exists(Raw::StmtList list, int i, int j |
      stmtAt(list, i, s) and
      stmtAt(list, j, result) and
      j > i and
      not result instanceof Raw::NullStmt and
      forall(int k, Raw::AdaNode between | k in [i + 1 .. j - 1] and stmtAt(list, k, between) |
        between instanceof Raw::NullStmt
      )
    )
  }

  /** Holds if `b` follows `a` in the same group, with only `null` statements between them. */
  private predicate nextInGroup(Raw::AssignStmt a, Raw::AssignStmt b) { b = nextNonNull(a) }

  /** Holds if `s` is the first assignment of its group. */
  predicate isGroupStart(Raw::AssignStmt s) { not nextInGroup(_, s) }

  /** Gets the first assignment of the group `s` is in. */
  Raw::AssignStmt groupStart(Raw::AssignStmt s) { isGroupStart(result) and nextInGroup*(result, s) }

  /** Holds if `a` comes before `b` (`a != b`) in the same group. */
  predicate before(Raw::AssignStmt a, Raw::AssignStmt b) { nextInGroup+(a, b) }

  /* --- targets --------------------------------------------------------------- */

  /** Holds if `n` names an object of an access type, so that a part of it is a dereference. */
  private predicate isAccessValue(Raw::Name n) {
    TypeCategories::category(n.getType(), true) = "access"
  }

  /** Holds if `n`, a prefix of a call-like name, is an array object (so `n (...)` is indexing). */
  private predicate isArray(Raw::Name n) { TypeCategories::category(n.getType(), true) = "array" }

  /** Gets the `i`th index (0-based) of indexing `c`. */
  Raw::Expr index(Raw::CallExpr c, int i) {
    result = c.getSuffix().(Raw::AssocList).getChild(i).(Raw::ParamAssoc).getRExpr()
  }

  /**
   * Holds if `c` is an indexing, not a slice: each part of its suffix is an index
   * expression, none a range.
   */
  predicate isIndexing(Raw::CallExpr c) {
    exists(Raw::AssocList l | l = c.getSuffix() |
      exists(l.getChild(_)) and
      forall(Raw::AdaNode a | a = l.getChild(_) |
        not a.(Raw::ParamAssoc).getRExpr().(Raw::BinOp).getOp() instanceof Raw::OpDoubleDot and
        exists(a.(Raw::ParamAssoc).getRExpr())
      )
    )
  }

  /**
   * Holds if `e` is static as an index: a literal, an enumeration literal, a named
   * number or a constant, or an operator applied to such. A range (a slice) is not.
   */
  predicate isStaticIndex(Raw::Expr e) {
    e instanceof Raw::IntLiteral
    or
    e instanceof Raw::CharLiteral
    or
    exists(Raw::BasicDecl d | d = e.(Raw::Identifier).getReferencedDecl() |
      d instanceof Raw::EnumLiteralDecl or
      d instanceof Raw::NumberDecl or
      d.(Raw::ObjectDecl).getHasConstant() instanceof Raw::ConstantPresent
    )
    or
    isStaticIndex(e.(Raw::ParenExpr).getExpr())
    or
    isStaticIndex(e.(Raw::UnOp).getExpr())
    or
    exists(Raw::BinOp b | b = e and not b.getOp() instanceof Raw::OpDoubleDot |
      isStaticIndex(b.getLeft()) and isStaticIndex(b.getRight())
    )
  }

  /**
   * Holds if `n` is a target known statically: an object, a component of a target, or
   * an element of an array target at static indices. Not through a dereference, and
   * not a slice.
   */
  predicate isStaticTarget(Raw::Name n) {
    exists(targetObject(n)) and
    (
      n instanceof Raw::Identifier
      or
      exists(Raw::DottedName d | d = n |
        d.getReferencedDecl() instanceof Raw::ComponentDecl and
        not isAccessValue(d.getPrefix()) and
        isStaticTarget(d.getPrefix())
      )
      or
      exists(Raw::CallExpr c | c = n |
        isArray(c.getName()) and
        isIndexing(c) and
        not isAccessValue(c.getName()) and
        isStaticTarget(c.getName()) and
        forall(Raw::Expr i | i = index(c, _) | isStaticIndex(i))
      )
    )
  }

  /**
   * Holds if names `a` and `b` (`a != b`) denote the same object or part of an object:
   * the same object, the same component of the same thing, or the same element at
   * equal indices. Index expressions are compared as written (`sameExpr`).
   */
  predicate sameName(Raw::Name a, Raw::Name b) {
    a != b and
    (
      definingName(a) = definingName(b)
      or
      exists(Raw::DottedName d, Raw::DottedName e | d = a and e = b |
        d.getReferencedDecl() instanceof Raw::ComponentDecl and
        d.getReferencedDecl() = e.getReferencedDecl() and
        d.getSuffix().getText().toLowerCase() = e.getSuffix().getText().toLowerCase() and
        sameName(d.getPrefix(), e.getPrefix())
      )
      or
      exists(Raw::CallExpr c, Raw::CallExpr d | c = a and d = b |
        isArray(c.getName()) and
        isIndexing(c) and
        isIndexing(d) and
        sameName(c.getName(), d.getName()) and
        count(index(c, _)) = count(index(d, _)) and
        forall(int i | exists(index(c, i)) |
          SimplifiableStatements::sameExpr(index(c, i), index(d, i))
        )
      )
      or
      sameName(a.(Raw::ExplicitDeref).getPrefix(), b.(Raw::ExplicitDeref).getPrefix())
    )
  }

  /**
   * Gets the defining name that identifier `id` denotes: of the declaration it refers
   * to, the name spelled like it (one of `A, B : T`). Renamings are not followed.
   */
  Raw::DefiningName definingName(Raw::Identifier id) {
    result = id.getReferencedDecl().getADefiningName() and
    result.getName().getText().toLowerCase() = id.getText().toLowerCase()
  }

  /**
   * Gets the defining name of the object `target` is, or is part of: `R` for `R.F`,
   * `A` for `A (I)`. No result through a dereference.
   */
  Raw::DefiningName targetObject(Raw::Name target) {
    result = definingName(root(target)) and
    not exists(Raw::Name n | n.getParent*() = target and n != root(target) |
      n instanceof Raw::ExplicitDeref or
      isAccessValue(n.(Raw::DottedName).getPrefix()) or
      isAccessValue(n.(Raw::CallExpr).getName())
    )
  }

  /** Holds if expression `e` names `object` (a defining name) anywhere in it. */
  private predicate reads(Raw::Expr e, Raw::DefiningName object) {
    exists(Raw::Identifier i | i.getParent*() = e | definingName(i) = object)
  }

  /* --- repeated -------------------------------------------------------------- */

  /**
   * Holds if `second` assigns to the same statically known target as `first`, the
   * latest assignment before it in the same group to do so (subrule `repeated`).
   */
  predicate repeated(Raw::AssignStmt first, Raw::AssignStmt second) {
    before(first, second) and
    isStaticTarget(first.getDest()) and
    sameName(first.getDest(), second.getDest()) and
    not exists(Raw::AssignStmt mid |
      before(first, mid) and before(mid, second) and sameName(mid.getDest(), second.getDest())
    )
  }

  /** Gets the innermost subprogram body, entry body, task body or `accept` statement around `n`. */
  private Raw::AdaNode scopeOf(Raw::AdaNode n) {
    result = n.getParent+() and
    isScope(result) and
    not exists(Raw::AdaNode inner | inner = n.getParent+() and isScope(inner) and inner.getParent+() = result)
  }

  private predicate isScope(Raw::AdaNode n) {
    n instanceof Raw::BaseSubpBody or
    n instanceof Raw::EntryBody or
    n instanceof Raw::TaskBody or
    n instanceof Raw::AcceptStmt
  }

  /**
   * Holds if `object` is a variable local to the subprogram (or other body) that holds
   * assignment `a`, and no subprogram nested in it names it: then no call can read it.
   * Not a parameter, a global, or a variable of an enclosing body.
   */
  private predicate isLocalTo(Raw::DefiningName object, Raw::AssignStmt a) {
    object.getParent+() instanceof Raw::ObjectDecl and
    scopeOf(object) = scopeOf(a) and
    not exists(Raw::Identifier i | definingName(i) = object and scopeOf(i) != scopeOf(object))
  }

  /** Holds if `e` calls a subprogram or allocates: it can read anything visible, or raise. */
  private predicate mayReadOrRaise(Raw::Expr e) {
    exists(Raw::AdaNode n | n.getParent*() = e | n instanceof Call or n instanceof Raw::Allocator)
  }

  /**
   * Holds if the target of `first` may be read after `first`, up to and including the
   * right-hand side of `second`, by an assignment of the group: then `first` is not
   * dead, whatever `repeated` says. A right-hand side reads it when it names its
   * object, and, for an object that is not a local variable, when it calls or
   * allocates: the callee may read the object, and an exception would leave the first
   * value in it.
   */
  predicate readBetween(Raw::AssignStmt first, Raw::AssignStmt second) {
    exists(Raw::AssignStmt mid, Raw::DefiningName object |
      object = targetObject(first.getDest()) and
      before(first, mid) and
      (before(mid, second) or mid = second) and
      (
        reads(mid.getExpr(), object)
        or
        not isLocalTo(object, first) and mayReadOrRaise(mid.getExpr())
      )
    )
  }

  /* --- groupable ------------------------------------------------------------- */

  /**
   * Gets the record type whose components `t` has: the full view of a private type,
   * through untagged derivations and subtypes. No result for a type extension, whose
   * components are spread over its ancestors.
   */
  Type recordBase(Type t) {
    result = recordBase(TypeCategories::fullView(t))
    or
    not exists(TypeCategories::fullView(t)) and
    (
      t.isSubtype() and result = recordBase(t.getParentType())
      or
      exists(Raw::DerivedTypeDef d | d = t.getDefinition() |
        not exists(d.getRecordExtension()) and result = recordBase(t.getParentType())
      )
      or
      t.getDefinition() instanceof Raw::RecordTypeDef and result = t
    )
  }

  /**
   * Gets a component of record type `t`, including those of its ancestors for a type
   * extension, through private views and subtypes.
   */
  Component aComponent(Type t) {
    result = aComponent(TypeCategories::fullView(t))
    or
    not exists(TypeCategories::fullView(t)) and
    (
      result = t.getAComponent()
      or
      result = aComponent(t.getParentType())
    )
  }

  /** Holds if `t` is limited: declared `limited`, a task or protected type, or with a limited component. */
  predicate isLimited(Type t) {
    exists(Type u | u = TypeCategories::ultimateType(t) |
      u.getDefinition().(Raw::RecordTypeDef).getHasLimited() instanceof Raw::LimitedPresent or
      u.getDefinition().(Raw::PrivateTypeDef).getHasLimited() instanceof Raw::LimitedPresent or
      u.getDefinition().(Raw::DerivedTypeDef).getHasLimited() instanceof Raw::LimitedPresent or
      TypeCategories::declaredCategory(u) = ["task", "protected", "interface"]
    )
    or
    isLimited(aComponent(t).getType())
  }

  /** Holds if component `c` is of a class-wide type (`T'Class`). */
  private predicate isClassWide(Component c) {
    c.getComponentDecl()
        .getComponentDef()
        .getTypeExpr()
        .(Raw::SubtypeIndication)
        .getName()
        .(Raw::AttributeRef)
        .getAttribute()
        .getValue()
        .toLowerCase() = "class"
  }

  /**
   * Gets the number of components of record type `t`, when it is known statically: a
   * record (or an untagged derivation of one) without discriminants or a variant part.
   */
  int componentCount(Type t) {
    exists(Type r | r = recordBase(t) |
      not exists(r.(Raw::TypeDecl).getDiscriminants()) and
      not exists(Raw::VariantPart v | v.getParent+() = r) and
      result = count(r.getAComponent())
    )
  }

  /**
   * Holds if the group starting at `start` assigns, one by one, `given` distinct
   * components of record variable `object`, of type `t`; `total` is the number of
   * components of `t`, or -1 when that is not known statically (subrule `groupable`).
   * Only direct components of a variable count (`R.F := ...`), each assigned in full.
   * Not reported for a limited type or one with a class-wide component, which cannot
   * be assigned as a whole.
   */
  predicate groupable(Raw::AssignStmt start, Raw::DefiningName object, Type t, int given, int total) {
    isGroupStart(start) and
    exists(Raw::Identifier root |
      root = componentTarget(start, object, _) and
      t = root.getType()
    ) and
    exists(recordBase(t)) and
    not isLimited(t) and
    not isClassWide(aComponent(t)) and
    given = count(Component c | exists(componentTarget(start, object, c))) and
    (if exists(componentCount(t)) then total = componentCount(t) else total = -1)
  }

  /**
   * Gets the prefix (a variable) of an assignment in the group starting at `start`
   * whose target is `object.C`, with `c` the component `C`.
   */
  private Raw::Identifier componentTarget(
    Raw::AssignStmt start, Raw::DefiningName object, Component c
  ) {
    exists(Raw::AssignStmt s, Raw::DottedName d |
      start = groupStart(s) and
      d = s.getDest() and
      d.getSuffix() = c.getAnAccess() and
      result = d.getPrefix() and
      object = definingName(result) and
      not isAccessValue(result)
    )
  }

  /** Holds if the group starting at `start` reads `object` in a right-hand side. */
  predicate groupReads(Raw::AssignStmt start, Raw::DefiningName object) {
    exists(Raw::AssignStmt s | start = groupStart(s) and reads(s.getExpr(), object))
  }

  /**
   * Holds if a group of `given` assigned components out of `total` (-1: unknown)
   * passes AdaControl's filters `given`, `missing`, `ratio` and `total`, combined by
   * "and"; a filter is left out by passing -1 for it.
   */
  bindingset[given, total, minGiven, maxMissing, minRatio, maxTotal]
  predicate passes(int given, int total, int minGiven, int maxMissing, int minRatio, int maxTotal) {
    (minGiven = -1 or given >= minGiven) and
    (maxMissing = -1 or total >= 0 and total - given <= maxMissing) and
    (minRatio = -1 or total > 0 and 100 * given >= minRatio * total) and
    (maxTotal = -1 or total >= 0 and total <= maxTotal)
  }

  /* --- sliding --------------------------------------------------------------- */

  /** Gets the static lower bound of the first index of the range `r` (`L .. H`). */
  private int rangeFirst(Raw::AdaNode r) {
    exists(Raw::BinOp b | b = r and b.getOp() instanceof Raw::OpDoubleDot |
      result = b.getLeft().(Raw::IntLiteral).getValue().replaceAll("_", "").toInt()
    )
  }

  /** Gets the static lower bound of the first index of constrained array type `t`. */
  private int typeFirst(Type t) {
    result =
      rangeFirst(t.getDefinition()
            .(Raw::ArrayTypeDef)
            .getIndices()
            .(Raw::ConstrainedArrayIndices)
            .getList()
            .getChild(0))
    or
    result = subtypeFirst(t.(Raw::SubtypeDecl).getSubtype())
  }

  /** Gets the static lower bound of the first index of subtype indication `si`. */
  private int subtypeFirst(Raw::SubtypeIndication si) {
    result =
      rangeFirst(si.getConstraint()
            .(Raw::CompositeConstraint)
            .getConstraints()
            .getChild(0)
            .(Raw::CompositeConstraintAssoc)
            .getConstraintExpr())
    or
    not exists(si.getConstraint()) and result = typeFirst(namedType(si))
  }

  /** Gets the static lower bound of the first index of the array that `e` denotes, if known. */
  int firstIndex(Raw::Expr e) {
    exists(Variable v |
      e.(Raw::Identifier).getReferencedDecl() = v.getDeclaration() and
      e.(Raw::Identifier).getText().toLowerCase() = v.getName().toLowerCase() and
      not v.isRenaming() and
      result = subtypeFirst(v.getTypeExpr())
    )
    or
    // a string literal in a context with no applicable index constraint starts at
    // the first value of the index subtype, `Positive'First` for `String`
    e instanceof Raw::StringLiteral and result = 1
  }

  /**
   * Holds if assignment `a` slides: its target, a whole array variable, starts at
   * `targetFirst`, and the value assigned at `valueFirst`, a different static lower
   * bound (subrule `sliding`). Only whole variables with static bounds and string
   * literals are checked; a slice is dynamic.
   */
  predicate sliding(Raw::AssignStmt a, int targetFirst, int valueFirst) {
    targetFirst = firstIndex(a.getDest()) and
    valueFirst = firstIndex(SimplifiableStatements::unparen(a.getExpr())) and
    targetFirst != valueFirst
  }

  /* --- access_duplication ---------------------------------------------------- */

  /** Gets `e` without parentheses, conversions and qualifications around it. */
  private Raw::Expr strip(Raw::Expr e) {
    exists(Raw::Expr u | u = SimplifiableStatements::unparen(e) |
      if u instanceof Raw::QualExpr
      then result = strip(u.(Raw::QualExpr).getSuffix())
      else
        if u.(Raw::CallExpr).getName().getReferencedDecl() instanceof Type
        then result = strip(index(u.(Raw::CallExpr), 0))
        else result = u
    )
  }

  /** Holds if `t` is derived, directly or not, from `Ada.Finalization.Controlled` or `Limited_Controlled`. */
  predicate isControlled(Type t) {
    TypeCategories::ultimateType(t)
        .hasQualifiedName([
            "Ada.Finalization.Controlled", "Ada.Finalization.Limited_Controlled"
          ])
    or
    exists(Type p | p = t.getParentType() or p = TypeCategories::fullView(t) | isControlled(p))
  }

  /** Holds if objects of type `t` hold an access value: `t` is an access type or has an access subcomponent. */
  predicate holdsAccess(Type t) {
    TypeCategories::category(t, true) = "access"
    or
    holdsAccess(aComponent(t).getType())
    or
    holdsAccess(namedType(TypeCategories::ultimateType(t)
            .getDefinition()
            .(Raw::ArrayTypeDef)
            .getComponentType()
            .getTypeExpr()))
  }

  /**
   * Holds if `site` (an assignment or an object declaration) stores `value`, the
   * content of an object that holds an access value, into another object (subrule
   * `access_duplication`). `controlled` is whether the access value is part of a
   * controlled type. `null`, allocators and function results are not duplications.
   */
  predicate accessDuplication(Raw::AdaNode site, Raw::Name value, boolean controlled) {
    exists(Raw::Expr e |
      e = site.(Raw::AssignStmt).getExpr() or e = site.(Raw::ObjectDecl).getDefaultExpr()
    |
      value = strip(e)
    ) and
    exists(LocalAccess::entity(value)) and
    not LocalAccess::entity(value) instanceof Raw::BasicSubpDecl and
    not LocalAccess::entity(value) instanceof Raw::BaseSubpBody and
    not value instanceof Call and
    holdsAccess(value.getType()) and
    if isControlled(value.getType()) then controlled = true else controlled = false
  }

  /** Gets the type of the object an access duplication stores its value in, for a `<target>` filter. */
  Type designatedTypeOf(Raw::Name value) {
    result =
      namedType(TypeCategories::ultimateType(value.getType())
            .getDefinition()
            .(Raw::TypeAccessDef)
            .getSubtypeIndication())
  }

  /* --- type ------------------------------------------------------------------ */

  /** Gets the leftmost name of `n`: `R` for `R.F (I).G`. */
  Raw::Name root(Raw::Name n) {
    if n instanceof Raw::DottedName and n.(Raw::DottedName).getReferencedDecl() instanceof Raw::ComponentDecl
    then result = root(n.(Raw::DottedName).getPrefix())
    else
      if n instanceof Raw::CallExpr and isArray(n.(Raw::CallExpr).getName())
      then result = root(n.(Raw::CallExpr).getName())
      else result = n
  }

  /**
   * Holds if `site` (an assignment, or an object declaration with an initial value)
   * assigns to an object of type `t`: as a whole when `component` is false, or a
   * component or element of it when `component` is true (subrule `type`).
   */
  predicate assignsType(Raw::AdaNode site, Type t, boolean component) {
    exists(Raw::Name dest | dest = site.(Raw::AssignStmt).getDest() |
      t = root(dest).getType() and
      if root(dest) = dest then component = false else component = true
    )
    or
    exists(Variable v |
      site = v.getDeclaration() and
      exists(v.getInitializer()) and
      t = v.getType() and
      component = false
    )
  }

  /** Holds if `t` is `wanted`, or, when `ancestor` is true, a type derived from it. */
  bindingset[ancestor]
  predicate isOfType(Type t, Type wanted, boolean ancestor) {
    TypeCategories::sameType(t, wanted)
    or
    ancestor = true and
    exists(Type p | p = t.getParentType() or p = TypeCategories::fullView(t) |
      isOfType(p, wanted, ancestor)
    )
  }

  /* --- possible_target_name -------------------------------------------------- */

  /**
   * Holds if `sub`, a part of the right-hand side of assignment `a`, is its target
   * again, and could be the target name `@` (subrule `possible_target_name`). `trivial`
   * is whether the target is a plain identifier.
   */
  predicate possibleTargetName(Raw::AssignStmt a, Raw::Name sub, boolean trivial) {
    sub.getParent*() = a.getExpr() and
    sameName(a.getDest(), sub) and
    if a.getDest() instanceof Raw::Identifier then trivial = true else trivial = false
  }

  /** Gets the number of components (selections, indexings, dereferences) of name `n`, for a `<max length>`. */
  int nameComponents(Raw::Name n) {
    n instanceof Raw::Identifier and result = 0
    or
    result = 1 + nameComponents(n.(Raw::DottedName).getPrefix())
    or
    result = 1 + nameComponents(n.(Raw::CallExpr).getName())
    or
    result = 1 + nameComponents(n.(Raw::ExplicitDeref).getPrefix())
  }
}

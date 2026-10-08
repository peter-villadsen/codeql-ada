/**
 * Call resolution: which declaration a call invokes, and which actual it passes for
 * each formal. Shared by `codeql.ada.Calls` (the `Call` class) and the data-flow
 * library, which differ only in where they count a call as evaluated: data flow
 * where the CFG has a node for it, `Call` by a syntactic rule, so that the AST
 * library does not depend on the CFG (`Make`).
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.internal.Formals

/**
 * Holds if `n` is a named association's designator (`X` in `Foo (X => Y)`): a label
 * naming the formal an actual binds to, not a reference to evaluate, even though
 * `ada_xref` resolves it.
 */
predicate isDesignator(Raw::Name n) { n = any(Raw::ParamAssoc pa).getDesignator() }

/** Gets the 0-based formal index of `spec`'s formal whose name, lower-cased, is `lname` (Ada ignores case). */
private int formalIndexNamed(Raw::SubpSpec spec, string lname) {
  exists(Raw::DefiningName dn |
    dn = formalAt(spec, result) and
    dn.getName().(Raw::Name).getText().toLowerCase() = lname
  )
}

/**
 * Holds if `p`, the prefix of a dotted name, is an expanded name's prefix -- it
 * names the unit the suffix is declared in (`Pkg.Foo`, or `Outer.Foo` for a
 * subprogram declared inside `Outer`) -- rather than an object whose type the
 * suffix is an operation of (a prefixed view, `Obj.Op`). Any package-like prefix
 * counts, since a renamed package does not contain its own declarations; any other
 * prefix counts only if the suffix is declared inside it or its body.
 */
private predicate isExpandedNamePrefix(Raw::Name p) {
  exists(Raw::DottedName dn, Raw::BasicDecl pd | p = dn.getPrefix() and pd = p.(Raw::Name).getReferencedDecl() |
    pd instanceof Raw::BasePackageDecl or
    pd instanceof Raw::PackageBody or
    pd instanceof Raw::PackageRenamingDecl or
    pd instanceof Raw::GenericPackageDecl or
    pd instanceof Raw::GenericPackageInstantiation or
    pd instanceof Raw::GenericPackageRenamingDecl or
    dn.getSuffix().(Raw::Name).getReferencedDecl().getParent+() = [pd, pd.(Raw::BasicDecl).getCompletion()]
  )
}

/** Holds if `d` is declared in a protected type or object (`protected Box is ...`). */
private predicate isProtectedOperation(Raw::BasicDecl d) {
  d.getParent+() instanceof Raw::ProtectedDef
}

/** Gets the operator node of operator application `call`. */
private Raw::Op operatorOf(Raw::Expr call) {
  result = call.(Raw::UnOp).getOp() or result = call.(Raw::BinOp).getOp()
}

/**
 * Gets the subprogram that `d` denotes once subprogram renamings are followed: `d`
 * itself if it is not a renaming. A renaming conforms to what it renames in the
 * number, order and modes of its formals, so an actual bound through the renaming's
 * own spec binds the same position in the target. No result for a renaming of a
 * prefixed view (`renames Obj.Op`, whose target has one formal more) or of anything
 * that does not resolve to a subprogram (an attribute, an entry, an instantiation).
 */
Raw::BasicDecl resolveSubpRenaming(Raw::BasicDecl d) {
  not d instanceof Raw::SubpRenamingDecl and result = d
  or
  exists(Raw::Name n | n = d.(Raw::SubpRenamingDecl).getRenames().getRenamedObject() |
    (not n instanceof Raw::DottedName or isExpandedNamePrefix(n.(Raw::DottedName).getPrefix())) and
    result = resolveSubpRenaming(n.(Raw::Name).getReferencedDecl()) and
    exists(subpSpecOf(result))
  )
}

/** Holds if `n` is evaluated where it stands, so that, if it names a subprogram, it is a call. */
signature predicate isEvaluatedSig(Raw::AdaNode n);

/** Call resolution for calls evaluated where `isEvaluated` says. */
module Make<isEvaluatedSig/1 isEvaluated> {
  /**
   * Gets the name that `call` invokes its subprogram through: a `CallExpr`'s name,
   * or `call` itself for a call written without parentheses (`X := Get;`,
   * `Obj.Op;`). A bare name is a call only where it is evaluated (`isEvaluated`), and
   * not where it is the callee part of a larger name: a `CallExpr`'s name, a dotted
   * name's suffix, an expanded name's prefix, an attribute's prefix (`F'Access`) or
   * a named association's designator.
   */
  Raw::Name calleeName(Raw::Expr call) {
    result = call.(Raw::CallExpr).getName() and isEvaluated(call)
    or
    result = call and
    not call instanceof Raw::CallExpr and
    not call = any(Raw::CallExpr c).getName() and
    not call = any(Raw::DottedName d).getSuffix() and
    not isExpandedNamePrefix(call) and
    not call = any(Raw::AttributeRef a).getPrefix() and
    not isDesignator(call) and
    isEvaluated(call)
  }

  /**
   * Holds if `call` is written in prefixed-view (dot) notation, `Obj.Op (Args)`:
   * `Obj` is then its first actual. Recognised by a dotted callee whose prefix is not
   * an expanded name's and has a type, i.e. denotes a value.
   */
  predicate isPrefixedViewCall(Raw::Expr call) {
    exists(Raw::DottedName dn | dn = calleeName(call) |
      not isExpandedNamePrefix(dn.getPrefix()) and
      exists(dn.getPrefix().(Raw::Expr).getType()) and
      // a protected operation's prefix is the protected object, never a formal
      not isProtectedOperation(dn.getSuffix().(Raw::Name).getReferencedDecl())
    )
  }

  /**
   * Gets the declaration `call` invokes: a subprogram with a `SubpSpec` of its own,
   * resolved through `ada_xref` (`Name.getReferencedDecl()`, D-021), never by name
   * text. Libadalang parses indexing, slicing and type conversion as a `CallExpr`
   * too; those resolve to an object or a type, so they have no result here, and
   * neither do calls to generic instantiations, entries and access values
   * (docs/dataflow-design.md, D-023). A subprogram renaming is a result -- it is a
   * `BaseSubpBody` with a `SubpSpec` of its own, whose formals bind the actuals --
   * and `resolveSubpRenaming` takes it on to the subprogram it renames. A protected
   * operation (`PO.Op (X)`) is a call whose prefix is the protected object, not a
   * formal, so its actuals bind as written. A dotted callee that is neither an
   * expanded name, a recognisable prefixed view nor a protected operation is left out,
   * since its actuals cannot be matched to formals.
   *
   * An operator application (`UnOp`, `BinOp`) is a call when its operator resolves to a
   * user-written subprogram (`function "+" (L, R : T) return T`, or a renaming of one).
   * Predefined operators do not resolve (D-026) and stay plain expressions.
   * Like a named call, it counts only where it is evaluated (`isEvaluated`).
   */
  Raw::BasicDecl getCallTarget(Raw::Expr call) {
    exists(Raw::Name callee | callee = calleeName(call) |
      result = callee.(Raw::Name).getReferencedDecl() and
      exists(subpSpecOf(result)) and
      (
        not callee instanceof Raw::DottedName
        or
        isExpandedNamePrefix(callee.(Raw::DottedName).getPrefix())
        or
        isPrefixedViewCall(call)
        or
        // `PO.Op (X)`: the prefix is the protected object, the actuals bind as written
        isProtectedOperation(result)
      )
    )
    or
    // only where the operator is evaluated, as for named calls
    isEvaluated(call) and
    result = operatorOf(call).(Raw::Name).getReferencedDecl() and
    exists(subpSpecOf(result))
  }

  /** Gets the `SubpSpec` of the subprogram `call` invokes (see `getCallTarget`). */
  Raw::SubpSpec getCalleeSpec(Raw::Expr call) { result = subpSpecOf(getCallTarget(call)) }

  /**
   * Holds if `actual` is the actual that `call` passes for its callee's `idx`th formal
   * (0-based, flattened, see `formalAt`). A named association (`X => Y`) binds by
   * designator. A positional one binds by its own source position, since Ada requires
   * every positional association to precede every named one -- shifted by one in a
   * prefixed-view call, whose prefix is the first actual. Formals left to their
   * default have no actual.
   */
  predicate callActual(Raw::Expr call, Raw::Expr actual, int idx) {
    exists(Raw::SubpSpec spec | spec = getCalleeSpec(call) |
      exists(Raw::ParamAssoc assoc |
        assoc = call.(Raw::CallExpr).getSuffix().(Raw::AssocList).getChild(_) and
        actual = assoc.getRExpr()
      |
        not exists(assoc.getDesignator()) and
        (if isPrefixedViewCall(call) then idx = assoc.getParentIndex() + 1 else idx = assoc.getParentIndex())
        or
        idx = formalIndexNamed(spec, assoc.getDesignator().(Raw::Name).getText().toLowerCase())
      )
      or
      isPrefixedViewCall(call) and
      actual = calleeName(call).(Raw::DottedName).getPrefix() and
      idx = 0
    )
    or
    // an operator application: the operands, by position (operators take no named actuals)
    exists(getCalleeSpec(call)) and
    (
      actual = call.(Raw::UnOp).getExpr() and idx = 0
      or
      actual = call.(Raw::BinOp).getLeft() and idx = 0
      or
      actual = call.(Raw::BinOp).getRight() and idx = 1
    )
  }
}

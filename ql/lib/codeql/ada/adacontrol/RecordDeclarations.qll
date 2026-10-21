/**
 * AdaControl rule `Record_Declarations`: record components of given types or categories,
 * by representation: in a variant, aligned, initialized, packed, sized
 * (`docs/adacontrol.md`).
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Declarations
private import codeql.ada.adacontrol.TypeCategories

module RecordDeclarations {
  /** Holds if component `c` is of type `t`, or of a subtype of it (`exact` if `t` itself). */
  predicate isOfType(Component c, Type t, boolean exact) {
    c.getType() = t and exact = true
    or
    c.getType() != t and c.getType().isSubtype() and c.getType().getParentType+() = t and exact = false
  }

  /** Holds if component `c` is of a type of `category`, derivations traversed but not privacy. */
  bindingset[category]
  predicate isOfCategory(Component c, string category) {
    exists(Type u | u = ultimateNoPrivacy(c.getType()) |
      TypeCategories::declaredCategory(u) = category
    )
  }

  private Type ultimateNoPrivacy(Type t) {
    if exists(t.getParentType()) then result = ultimateNoPrivacy(t.getParentType()) else result = t
  }

  /** `in_variant`: `c` is in the variant part of its record. */
  predicate inVariant(Component c) { c.getComponentDecl().getParent+() instanceof Raw::Variant }

  /** `initialized`: `c` has a default expression. */
  predicate isInitialized(Component c) { exists(c.getDefaultExpr()) }

  /** Gets the component clause (`X at 0 range 0 .. 7;`) for `c`, if any. */
  Raw::ComponentClause componentClause(Component c) {
    exists(Raw::RecordRepClause rep |
      rep.getName().getReferencedDecl() = c.getDeclaringType() and
      result = rep.getComponents().getChild(_) and
      result.getId().getText().toLowerCase() = c.getName().toLowerCase()
    )
  }

  /** `sized`: a component clause applies to `c`. */
  predicate isSized(Component c) { exists(componentClause(c)) }

  /** Gets the value of `e`, if it is an integer literal. */
  private int literal(Raw::Expr e) { result = e.(Raw::IntLiteral).getValue().replaceAll("_", "").toInt() }

  /**
   * Holds if `c` has a component clause starting at a known bit: `position * 8 + first`,
   * with literal position and first bit (a storage unit of 8 bits).
   */
  int firstBit(Component c) {
    exists(Raw::ComponentClause cc, Raw::BinOp range | cc = componentClause(c) |
      range = cc.getRange().getRange() and
      result = literal(cc.getPosition()) * 8 + literal(range.getLeft())
    )
  }

  /**
   * `aligned`: no component clause applies to `c`, or its first bit is a multiple of
   * the storage unit (8). Not known where the clause's values are not literals.
   */
  predicate isAligned(Component c) {
    not isSized(c)
    or
    firstBit(c) % 8 = 0
  }

  /** `packed`: `Pack` applies to the type of `c`, by aspect or pragma. */
  predicate isPacked(Component c) {
    exists(Type t | t = c.getType() |
      exists(Raw::AspectAssoc a | a = t.getAspects().getAspectAssocs().getChild(_) |
        a.getId().(Raw::Name).getText().toLowerCase() = "pack"
      )
      or
      exists(Raw::PragmaNode p |
        p.getId().getValue().toLowerCase() = "pack" and
        p.getArgs().getChild(_).(Raw::PragmaArgumentAssoc).getExpr().(Raw::Name).getReferencedDecl() = t
      )
    )
  }
}

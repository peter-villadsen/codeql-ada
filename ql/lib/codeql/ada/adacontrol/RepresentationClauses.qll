/**
 * AdaControl rule `Representation_Clauses`: representation clauses and aspects, by kind,
 * and specifications of given attributes (`docs/adacontrol.md`).
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Declarations

module RepresentationClauses {
  /** Gets the value of `e`, if it is an integer literal. */
  private int literal(Raw::Expr e) {
    result = e.(Raw::IntLiteral).getValue().replaceAll("_", "").toInt()
  }

  /** Gets the attribute `c` specifies, lower-cased (`size`, `address`, `class'input`), and its prefix. */
  string specifiedAttribute(Raw::AttributeDefClause c, Raw::Name prefix) {
    exists(Raw::AttributeRef a | a = c.getAttributeExpr() |
      result = a.getAttribute().getValue().toLowerCase() and
      prefix = a.getPrefix() and
      not prefix instanceof Raw::AttributeRef
      or
      result =
        a.getPrefix().(Raw::AttributeRef).getAttribute().getValue().toLowerCase() + "'" +
          a.getAttribute().getValue().toLowerCase() and
      prefix = a.getPrefix().(Raw::AttributeRef).getPrefix()
    )
  }

  /** Gets the declaration of the entity the representation item `c` applies to. */
  Raw::BasicDecl target(Raw::AdaNode c) {
    exists(Raw::Name prefix | exists(specifiedAttribute(c, prefix)) | result = prefix.getReferencedDecl())
    or
    result = c.(Raw::AtClause).getName().getReferencedDecl()
    or
    result = c.(Raw::EnumRepClause).getTypeName().getReferencedDecl()
    or
    result = c.(Raw::RecordRepClause).getName().getReferencedDecl()
  }

  /** Holds if the type `t` has a `Bit_Order` specification, by clause or aspect. */
  private predicate hasBitOrder(Type t) {
    exists(Raw::AttributeDefClause c | specifiedAttribute(c, _) = "bit_order" and target(c) = t)
    or
    exists(Raw::AspectAssoc a | a = t.getAspects().getAspectAssocs().getChild(_) |
      a.getId().(Raw::Name).getText().toLowerCase() = "bit_order"
    )
  }

  /**
   * Holds if representation item `c` is of the kind `kw`: `at`, `at_mod`, `enumeration`,
   * `layout`, `no_bit_order_layout`, `incomplete_layout`, `overlay`, `fractional_size`,
   * `non_power2_size`, or `'<attribute>` for an attribute definition clause.
   */
  predicate representation(Raw::AdaNode c, string kw) {
    c instanceof Raw::AtClause and kw = "at"
    or
    exists(c.(Raw::RecordRepClause).getAtExpr()) and kw = "at_mod"
    or
    c instanceof Raw::EnumRepClause and kw = "enumeration"
    or
    c instanceof Raw::RecordRepClause and kw = "layout"
    or
    c instanceof Raw::RecordRepClause and not hasBitOrder(target(c)) and kw = "no_bit_order_layout"
    or
    exists(Raw::RecordRepClause rep, Type t | rep = c and t = target(rep) |
      exists(Component comp |
        comp.getDeclaringType() = t and
        not exists(Raw::ComponentClause cc |
          cc = rep.getComponents().getChild(_) and
          cc.getId().getText().toLowerCase() = comp.getName().toLowerCase()
        )
      ) and
      kw = "incomplete_layout"
    )
    or
    // an address that is the 'Address of another object
    exists(Raw::Expr addr |
      addr = c.(Raw::AtClause).getExpr()
      or
      specifiedAttribute(c, _) = "address" and addr = c.(Raw::AttributeDefClause).getExpr()
    |
      addr.(Raw::AttributeRef).getAttribute().getValue().toLowerCase() = "address" and
      kw = "overlay"
    )
    or
    exists(int size |
      specifiedAttribute(c, _) = ["size", "object_size", "value_size"] and
      size = literal(c.(Raw::AttributeDefClause).getExpr())
    |
      size % 8 != 0 and kw = "fractional_size"
      or
      size % 8 = 0 and not size / 8 = [1, 2, 4, 8, 16, 32, 64, 128] and kw = "non_power2_size"
    )
    or
    kw = "'" + specifiedAttribute(c, _)
  }

  /** `global`: the entity of representation item `c` is declared in a package, not locally. */
  predicate isGlobal(Raw::AdaNode c) {
    not exists(Raw::AdaNode scope |
      scope = target(c).getParent+() and
      (scope instanceof Raw::BaseSubpBody or scope instanceof Raw::TaskBody or scope instanceof Raw::BlockStmt)
    )
  }

  /** `object`: the entity of representation item `c` is an object, not a type. */
  predicate isForObject(Raw::AdaNode c) { target(c) instanceof Raw::ObjectDecl }
}

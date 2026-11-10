/**
 * AdaControl rule `Type_Usage`: uses of types, given by name or by category, as the
 * prefix of an attribute or as the index type of an array type, optionally only for
 * types that have (or lack) representation aspects (`docs/adacontrol.md`).
 *
 * A type matches a name when it is the named type or derives from it, through
 * subtypes and derivations (`Type.getParentType()`); it matches a category
 * (`TypeCategories::category`) by what it ultimately is. The aspects are those of the
 * matched type: `representation` (an enumeration or record representation clause),
 * `pack` (`pragma Pack` or the aspect), `size` and `component_size` (an attribute
 * definition clause or the aspect).
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Declarations
private import codeql.ada.adacontrol.RepresentationClauses
private import codeql.ada.adacontrol.TypeCategories

module TypeUsage {
  /**
   * Holds if type `t` matches `type`: an AdaControl category (`()`, `range`, `mod`,
   * `access`, ...), or the qualified name of `t` or of a type it derives from.
   */
  bindingset[type]
  predicate matches(Type t, string type) {
    TypeCategories::category(t, true) = type
    or
    t.getParentType*().hasQualifiedName(type)
  }

  /** Gets the type the name `n` denotes, if it denotes one. */
  private Type denotedType(Raw::AdaNode n) {
    result = n.(Raw::Name).getReferencedDecl()
    or
    result = n.(Raw::SubtypeIndication).getName().getReferencedDecl()
  }

  /** `'<attribute>`: attribute reference `a`, of `attribute` (lower case), has the type `t` as prefix. */
  predicate attributeUse(Raw::AttributeRef a, Type t, string attribute) {
    t = denotedType(a.getPrefix()) and attribute = a.getAttribute().getValue().toLowerCase()
  }

  /** `index`: `index` is an index of array type `array`, of type `t`. */
  predicate indexUse(Type array, Raw::AdaNode index, Type t) {
    exists(Raw::ArrayIndices indices | indices = array.getDefinition().(Raw::ArrayTypeDef).getIndices() |
      index = indices.(Raw::ConstrainedArrayIndices).getList().getChild(_) and
      (
        t = denotedType(index)
        or
        not exists(denotedType(index)) and t = index.(Raw::Expr).getType()
      )
      or
      index = indices.(Raw::UnconstrainedArrayIndices).getTypes().getChild(_) and
      t = denotedType(index.(Raw::UnconstrainedArrayIndex).getSubtypeName())
    )
  }

  /** Holds if `t` has a representation item of `aspect`: `representation`, `pack`, `size` or `component_size`. */
  predicate hasAspect(Type t, string aspect) {
    aspect = "representation" and
    exists(Raw::AdaNode c | RepresentationClauses::target(c) = t |
      c instanceof Raw::EnumRepClause or c instanceof Raw::RecordRepClause
    )
    or
    aspect = ["pack", "size", "component_size"] and
    (
      exists(Raw::AspectAssoc a | a = t.getAspects().getAspectAssocs().getChild(_) |
        a.getId().(Raw::Name).getText().toLowerCase() = aspect and
        not a.getExpr().(Raw::Name).getText().toLowerCase() = "false"
      )
      or
      aspect = "pack" and
      exists(Raw::PragmaNode p |
        p.getId().getValue().toLowerCase() = "pack" and
        p.getArgs().getChild(_).(Raw::PragmaArgumentAssoc).getExpr().(Raw::Name).getReferencedDecl() = t
      )
      or
      exists(Raw::AttributeDefClause c |
        RepresentationClauses::specifiedAttribute(c, _) = aspect and RepresentationClauses::target(c) = t
      )
    )
  }

  /**
   * Holds if `t` satisfies the aspect condition `condition`: empty, an aspect, or
   * `not` and an aspect.
   */
  bindingset[condition]
  predicate satisfies(Type t, string condition) {
    condition = ""
    or
    hasAspect(t, condition.toLowerCase())
    or
    condition.toLowerCase().matches("not %") and
    not hasAspect(t, condition.toLowerCase().suffix(4).trim())
  }
}

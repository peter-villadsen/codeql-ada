/**
 * AdaControl rule `Allocators`: dynamic allocation (`new`), by allocated type or
 * category, of an anonymous access type, or inconsistent with the access type
 * (`docs/adacontrol.md`).
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Declarations
private import codeql.ada.adacontrol.TypeCategories

module Allocators {
  /** Gets the subtype mark of allocator `a`: `T` in `new T` and `new T'(...)`. */
  Raw::Name allocatedSubtypeMark(Raw::Allocator a) {
    result = a.getTypeOrExpr().(Raw::SubtypeIndication).getName()
    or
    result = a.getTypeOrExpr().(Raw::QualExpr).getPrefix()
  }

  /** Gets the type allocator `a` allocates, if its subtype mark resolves. */
  Type allocatedType(Raw::Allocator a) { result = allocatedSubtypeMark(a).getReferencedDecl() }

  /**
   * Holds if allocator `a` allocates type `t` or a subtype of it, as AdaControl's
   * `<entity>` does: `t` is a first named subtype.
   */
  predicate allocates(Raw::Allocator a, Type t) { subtypeOf*(allocatedType(a), t) }

  /** Holds if `s` is declared as a subtype of `t` (`subtype S is T range ...`). */
  private predicate subtypeOf(Type s, Type t) { s.isSubtype() and t = s.getParentType() }

  /** Holds if allocator `a` allocates a type of `category`, derivations and privacy traversed. */
  bindingset[category]
  predicate allocatesCategory(Raw::Allocator a, string category) {
    TypeCategories::category(allocatedType(a), false) = category
  }

  /** Gets the access type allocator `a` creates a value of: its expected type. */
  Type accessType(Raw::Allocator a) { result = a.getType() }

  /** `anonymous`: the expected type of allocator `a` is an anonymous access type. */
  predicate isAnonymous(Raw::Allocator a) { accessType(a) instanceof Raw::AnonymousTypeDecl }

  /** Gets the designated subtype mark of access type `acc` (`T` in `access all T`). */
  private Raw::Name designatedSubtypeMark(Type acc) {
    result = acc.getDefinition().(Raw::TypeAccessDef).getSubtypeIndication().getName()
  }

  /**
   * `inconsistent`: allocator `a` names a different subtype than its access type
   * designates (`new Natural` for `access Positive`). Not when the designated subtype
   * constrains nothing more: a class-wide type (`T'Class`), a base type (`T'Base`), an
   * unconstrained array type. A partial view (`type T;`, `type T is private;`) and the
   * full declaration are the same subtype.
   */
  predicate isInconsistent(Raw::Allocator a) {
    exists(Raw::Name designated, Raw::BasicDecl d |
      designated = designatedSubtypeMark(accessType(a)) and
      d = designated.getReferencedDecl() and
      not designated instanceof Raw::AttributeRef and
      not d.(Type).getDefinition().(Raw::ArrayTypeDef).getIndices() instanceof
        Raw::UnconstrainedArrayIndices and
      exists(allocatedSubtypeMark(a).getReferencedDecl()) and
      not TypeCategories::sameType(allocatedSubtypeMark(a).getReferencedDecl(), d)
    )
  }
}

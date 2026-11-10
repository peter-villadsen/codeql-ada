/**
 * AdaControl rule `Not_Elaboration_Calls`: calls of given subprograms, and
 * allocators, that may happen other than while library packages are elaborated
 * (`docs/adacontrol.md`).
 *
 * A node is *elaboration code* when it is in the declarations or statements of a
 * package and not in a body of any kind (subprogram, entry, task, protected), nor in a
 * place evaluated later: a parameter's default, a type's component default, an aspect
 * (`Pre`, `Post`, ...). A subprogram *may run outside elaboration* unless every call of
 * it is in elaboration code or in a subprogram that runs only during elaboration; one
 * with no call in the database, or whose `'Access` or `'Address` is taken, may be
 * called from anywhere.
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Calls
private import codeql.ada.Subprograms
private import codeql.ada.adacontrol.GlobalReferences

module NotElaborationCalls {
  /** Holds if `n` is in a place evaluated after elaboration, when it is used. */
  private predicate isDeferred(Raw::AdaNode n) {
    n.getParent+() instanceof Raw::ParamSpec or
    n.getParent+() instanceof Raw::ComponentDecl or
    n.getParent+() instanceof Raw::AspectSpec or
    n.getParent+() instanceof Raw::GenericFormalPart
  }

  /** Holds if `n` is elaboration code: in a package, outside any body and deferred place. */
  predicate isElaborationCode(Raw::AdaNode n) {
    not exists(GlobalReferences::bodyOf(n)) and
    not n.getParent+() instanceof Raw::ProtectedBody and
    not isDeferred(n)
  }

  /** Holds if the `'Access`, `'Unchecked_Access`, `'Unrestricted_Access` or `'Address` of `s` is taken. */
  private predicate isReferenced(Subprogram s) {
    exists(Raw::AttributeRef a |
      a.getPrefix().getReferencedDecl() = s.getADeclaration() and
      a.getAttribute().getText().toLowerCase() =
        ["access", "unchecked_access", "unrestricted_access", "address"]
    )
  }

  /**
   * Holds if subprogram `s` may run outside elaboration: it has no call, its
   * `'Access` or `'Address` is taken, or some call of it may run outside.
   */
  predicate mayRunOutside(Subprogram s) {
    not exists(Call c | c.getTarget() = s)
    or
    isReferenced(s)
    or
    exists(Call c | c.getTarget() = s | runsOutside(c))
  }

  /**
   * Holds if `n` may run outside elaboration: it is not elaboration code, and it is
   * in a body other than a subprogram's, or in a subprogram that may.
   */
  predicate runsOutside(Raw::AdaNode n) {
    not isElaborationCode(n) and
    (
      not exists(Subprogram s | s.getBody() = GlobalReferences::bodyOf(n))
      or
      exists(Subprogram s | s.getBody() = GlobalReferences::bodyOf(n) | mayRunOutside(s))
    )
  }

  /** `<entity>`: call `c` of `s` may happen outside elaboration. */
  predicate callOutside(Call c, Subprogram s) { s = c.getTarget() and runsOutside(c) }

  /** `new`: allocator `a` may run outside elaboration. */
  predicate allocatorOutside(Raw::Allocator a) { runsOutside(a) }
}

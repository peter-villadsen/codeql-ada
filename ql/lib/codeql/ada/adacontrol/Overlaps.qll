/**
 * Whether two names may denote overlapping objects, for the AdaControl rules
 * `Generic_Aliasing` and `Parameter_Aliasing` (`docs/adacontrol.md`): the same object,
 * one a part of the other, elements of one array at indices that may be equal, or the
 * objects two access values of one type designate.
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.adacontrol.Assignments
private import codeql.ada.adacontrol.SimplifiableStatements
private import codeql.ada.adacontrol.TypeCategories

/** A predicate choosing the names to compare (actuals of one call or instantiation). */
signature predicate nameSig(Raw::Name n);

/** Overlap of the names `isCandidate` holds for. */
module Overlaps<nameSig/1 isCandidate> {
  private predicate isAccessValue(Raw::Name n) {
    TypeCategories::category(n.getType(), true) = "access"
  }

  private predicate isArray(Raw::Name n) { TypeCategories::category(n.getType(), true) = "array" }

  /** Gets the defining name of the object that name `n` denotes as a whole: `X`, `Pkg.X`. */
  private Raw::DefiningName objectName(Raw::Name n) {
    result = Assignments::definingName(n)
    or
    exists(Raw::DottedName d | d = n |
      not d.getReferencedDecl() instanceof Raw::ComponentDecl and
      result = Assignments::definingName(d.getSuffix())
    )
  }

  /**
   * Holds if `n` is a part of the object `prefix` names: a component, an element or a
   * slice of it. Not through an access value: a part of `P.all` is one of `P.all`.
   */
  private predicate partOf(Raw::Name n, Raw::Name prefix) {
    exists(Raw::DottedName d | d = n |
      d.getReferencedDecl() instanceof Raw::ComponentDecl and
      prefix = d.getPrefix() and
      not isAccessValue(prefix)
    )
    or
    exists(Raw::CallExpr c | c = n |
      prefix = c.getName() and isArray(prefix) and not isAccessValue(prefix)
    )
  }

  /** Holds if `n` is a candidate, or the object a candidate is a part of. */
  private predicate inCandidate(Raw::Name n) {
    isCandidate(n)
    or
    exists(Raw::Name part | inCandidate(part) and partOf(part, n))
    or
    exists(Raw::ExplicitDeref d | inCandidate(d) and n = d.getPrefix())
  }

  /** Holds if the indices of `c` and `d` are the same, as written. */
  private predicate sameIndices(Raw::CallExpr c, Raw::CallExpr d) {
    Assignments::isIndexing(c) and
    Assignments::isIndexing(d) and
    count(Assignments::index(c, _)) = count(Assignments::index(d, _)) and
    forall(int i | exists(Assignments::index(c, i)) |
      SimplifiableStatements::sameExpr(Assignments::index(c, i), Assignments::index(d, i))
    )
  }

  /** Holds if `c` is a slice, or has an index that is not static. */
  private predicate isDynamic(Raw::CallExpr c) {
    not Assignments::isIndexing(c)
    or
    exists(Raw::Expr i | i = Assignments::index(c, _) | not Assignments::isStaticIndex(i))
  }

  /**
   * Holds if names `a` and `b`, candidates or objects they are parts of, may denote
   * overlapping objects, with `strength` 3 (certain), 2 (possible) or 1 (unlikely).
   */
  private predicate overlap(Raw::Name a, Raw::Name b, int strength) {
    inCandidate(a) and
    inCandidate(b) and
    (
      objectName(a) = objectName(b) and strength = 3
      or
      // the same component of overlapping objects
      exists(Raw::DottedName d, Raw::DottedName e | d = a and e = b |
        d.getReferencedDecl() instanceof Raw::ComponentDecl and
        d.getReferencedDecl() = e.getReferencedDecl() and
        d.getSuffix().getText().toLowerCase() = e.getSuffix().getText().toLowerCase() and
        overlap(d.getPrefix(), e.getPrefix(), strength)
      )
      or
      // elements or slices of overlapping arrays
      exists(Raw::CallExpr c, Raw::CallExpr d, int s | c = a and d = b |
        partOf(c, c.getName()) and
        partOf(d, d.getName()) and
        overlap(c.getName(), d.getName(), s) and
        (
          sameIndices(c, d) and strength = s
          or
          not sameIndices(c, d) and
          (isDynamic(c) or isDynamic(d)) and
          strength = s.minimum(2)
        )
      )
      or
      // a part of an object that overlaps the other
      exists(Raw::Name p | partOf(a, p) and not partOf(b, _) | overlap(p, b, strength))
      or
      exists(Raw::Name p | partOf(b, p) and not partOf(a, _) | overlap(a, p, strength))
      or
      // dereferences
      exists(Raw::ExplicitDeref d, Raw::ExplicitDeref e | d = a and e = b |
        overlap(d.getPrefix(), e.getPrefix(), strength)
        or
        // any two access values of one type may designate the same object; the
        // strongest condition is kept (`condition`)
        d.getPrefix().getType() = e.getPrefix().getType() and
        strength = 1
      )
    )
  }

  /**
   * Gets how sure it is that candidates `a` and `b` overlap, the strongest that
   * applies: `certain`, `possible` (an element at an index that is not static, or a
   * slice) or `unlikely` (dereferences of access values of one type).
   */
  string condition(Raw::Name a, Raw::Name b) {
    isCandidate(a) and
    isCandidate(b) and
    exists(int s | s = max(int t | overlap(a, b, t)) |
      s = 3 and result = "certain"
      or
      s = 2 and result = "possible"
      or
      s = 1 and result = "unlikely"
    )
  }
}

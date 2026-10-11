/**
 * `Subprogram.isPrimitiveOf` and `Subprogram.overrides`: which subprograms are
 * primitive operations of a tagged type, and which override which.
 */

import ada

query predicate primitives(Subprogram s, string type, int i) {
  s.fromSource() and
  exists(Type t | s.isPrimitiveOf(t, i) | type = t.getName())
}

query predicate overrides(Subprogram s, string sType, Subprogram other, string otherType) {
  s.fromSource() and
  s.overrides(other) and
  sType = concat(Type t | s.isPrimitiveOf(t, _) | t.getName()) and
  otherType = concat(Type t | other.isPrimitiveOf(t, _) | t.getName())
}

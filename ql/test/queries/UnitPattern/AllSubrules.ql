/**
 * Every subrule of `codeql.ada.adacontrol.UnitPattern`, for the shipped query's test
 * sources: `single_tagged_type`, `tagged_type_hierarchy`, `context_clauses_order` (with,
 * then use clauses, then pragmas) and `declarations_order` (numbers and constants, then
 * types, then subprogram specs).
 */

import ada
import codeql.ada.adacontrol.UnitPattern

int clauseGroup(string kind) {
  kind = "with" and result = 0
  or
  kind = ["use", "use_type", "use_all_type"] and result = 1
  or
  kind = "pragma" and result = 2
}

int declGroup(string kind) {
  kind = ["number", "constant"] and result = 0
  or
  kind = ["full_type", "private_type", "subtype"] and result = 1
  or
  kind = "subprogram_spec" and result = 2
}

module Clauses = UnitPattern::Order<clauseGroup/1>;

module Decls = UnitPattern::Order<declGroup/1>;

from AdaNode n, string what
where
  n.fromSource() and
  (
    exists(Type first | UnitPattern::secondTaggedType(_, n, first) | what = "second tagged type after " + first.getName())
    or
    exists(Type parent | UnitPattern::breaksHierarchy(n, parent) | what = "hierarchy: " + parent.getQualifiedName())
    or
    exists(CompilationUnit cu | Clauses::outOfOrder(UnitPattern::contextClauses(cu), n) | what = "context clause out of order")
    or
    exists(AdaNode part | Decls::outOfOrder(UnitPattern::declarations(part, "package_public"), n) | what = "declaration out of order")
  )
select n, what

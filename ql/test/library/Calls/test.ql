/**
 * The `Call` class (Phase 12, Task 12.2): each call with its target, caller and
 * whether it is a statement; each argument with the parameter it is for; and the
 * call-like expressions that are not calls.
 */

import ada

query predicate calls(Call c, string target, string caller, string kind) {
  c.fromSource() and
  target = c.getTarget().getQualifiedName() and
  (if exists(c.getCaller()) then caller = c.getCaller().getName() else caller = "-") and
  if c.isStatement() then kind = "statement" else kind = "expression"
}

query predicate arguments(Call c, int i, Expr arg, string param) {
  c.fromSource() and
  arg = c.getArgument(i) and
  param = concat(Parameter p | c.getArgumentFor(p) = arg | p.getName(), ",")
}

query predicate byName(Call c, string name, Expr arg) {
  c.fromSource() and name = ["a", "B", "V", "self"] and arg = c.getArgumentByName(name)
}

query predicate callsOf(Subprogram s, int n) {
  s.fromSource() and n = count(s.getACall()) and n > 0
}

query predicate notCalls(CallExpr e) { e.fromSource() and not e instanceof Call }

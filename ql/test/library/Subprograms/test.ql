/**
 * The `Subprogram` and `Parameter` classes (Phase 12, Task 12.1): one row per
 * subprogram, then one per parameter, then one per access to a parameter.
 */

import ada

query predicate subprograms(
  Subprogram s, string kind, string fn, int params, string body, string decls
) {
  s.fromSource() and
  kind = s.getAPrimaryQlClass() and
  (if s.isFunction() then fn = "function" else if s.isProcedure() then fn = "procedure" else fn = "?") and
  params = s.getNumberOfParameters() and
  (
    if exists(s.getBody())
    then body = concat(Raw::BasicDecl b | b = s.getBody() | b.getAPrimaryQlClass() + "@" + b.getLocation().getStartLine(), ", ")
    else body = "none"
  ) and
  decls = concat(Raw::BasicDecl d | d = s.getADeclaration() | d.getAPrimaryQlClass() + "@" + d.getLocation().getStartLine(), ", " order by d.getLocation().toString())
}

query predicate parameters(
  Subprogram s, int i, Parameter p, string mode, string type, string default, string declarations
) {
  s.fromSource() and
  p = s.getParameter(i) and
  mode = p.getMode() and
  (if exists(p.getType()) then type = p.getType().(BasicDecl).getQualifiedName() else type = "-") and
  (if exists(p.getDefaultExpr()) then default = p.getDefaultExpr().toString() else default = "-") and
  declarations = count(p.getADeclaration()).toString()
}

query predicate accesses(Parameter p, Name access) {
  p.getSubprogram().fromSource() and access = p.getAnAccess()
}

query predicate returnTypes(Subprogram s, string type) {
  s.fromSource() and s.isFunction() and type = s.getReturnType().(BasicDecl).getQualifiedName()
}

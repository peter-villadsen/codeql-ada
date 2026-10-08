/**
 * Type, Component, Variable and Package (Phase 12, Task 12.3).
 */

import ada

query predicate types(Type t, string name, string kinds, string parent) {
  t.fromSource() and
  name = t.getName() and
  kinds =
    concat(string k |
      t.isRecord() and k = "record"
      or
      t.isTagged() and k = "tagged"
      or
      t.isEnumeration() and k = "enumeration"
      or
      t.isArray() and k = "array"
      or
      t.isAccess() and k = "access"
      or
      t.isPrivate() and k = "private"
      or
      t.isSubtype() and k = "subtype"
    |
      k, ","
    ) and
  (if exists(t.getParentType()) then parent = t.getParentType().getQualifiedName() else parent = "-")
}

query predicate literals(Type t, Raw::EnumLiteralDecl lit) {
  t.fromSource() and lit = t.getAnEnumerationLiteral()
}

query predicate components(Component c, string name, string owner, string type, string default) {
  c.fromSource() and
  name = c.getName() and
  owner = c.getDeclaringType().getName() and
  (if exists(c.getType()) then type = c.getType().getQualifiedName() else type = "-") and
  (if exists(c.getDefaultExpr()) then default = c.getDefaultExpr().toString() else default = "-")
}

query predicate componentAccesses(Component c, Name access) {
  c.fromSource() and access = c.getAnAccess()
}

query predicate variables(Variable v, string name, string type, string flags, string subprogram) {
  v.fromSource() and
  name = v.getName() and
  (if exists(v.getType()) then type = v.getType().getQualifiedName() else type = "-") and
  flags =
    concat(string f |
      v.isConstant() and f = "constant"
      or
      v.isRenaming() and f = "renaming"
      or
      v.isLoopVariable() and f = "loop"
      or
      v.isLocal() and f = "local"
    |
      f, ","
    ) and
  (if v.isLocal() then subprogram = v.getDeclaringSubprogram().getName() else subprogram = "-")
}

query predicate variableAccesses(Variable v, Name access) {
  v.fromSource() and access = v.getAnAccess()
}

query predicate packages(Package p, string name, string kind, string body, string generic) {
  p.fromSource() and
  name = p.getName() and
  (
    if p.isGeneric()
    then kind = "generic"
    else
      if p.isGenericInstance()
      then kind = "instance"
      else kind = "package"
  ) and
  (if exists(p.getBody()) then body = p.getBody().getLocation().toString() else body = "-") and
  (if exists(p.getGeneric()) then generic = p.getGeneric().getName() else generic = "-")
}

query predicate members(Package p, string member, string part) {
  p.fromSource() and
  exists(BasicDecl m | m = p.getAMember() |
    member = m.toString() + " (" + m.getAPrimaryQlClass() + ")" and
    if m = p.getAPublicMember() then part = "public" else part = "private or body"
  )
}

query predicate packageContents(Package p, string subprograms, string types, string variables) {
  p.fromSource() and
  subprograms = concat(p.getASubprogram().getName(), ",") and
  types = concat(p.getAType().getName(), ",") and
  variables = concat(p.getAVariable().getName(), ",")
}

query predicate exprTypes(Expr e, string type) {
  e.fromSource() and
  e.getEnclosingSubprogram().(BasicDecl).getAName() = "Area" and
  e instanceof Identifier and
  type = e.getType().getQualifiedName()
}

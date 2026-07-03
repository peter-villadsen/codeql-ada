/**
 * @name Hardcoded credential
 * @description A constant or variable whose name suggests a password, API key,
 *              secret, or token is initialized with a non-empty string literal,
 *              embedding the credential directly in source where it can leak via
 *              version control, decompilation, or logs.
 * @id ada/hardcoded-credential
 * @kind problem
 * @problem.severity error
 * @tags security
 */

import ada

from Raw::ObjectDecl d, Raw::StringLiteral lit
where
  d.getDefaultExpr() = lit and
  lit.getValue().length() > 2 and
  d.(BasicDecl)
      .getAName()
      .toLowerCase()
      .regexpMatch(".*(password|passwd|secret|api_key|apikey|token|credential).*")
select d,
  "Object " + d.(BasicDecl).getAName() + " is initialized with a hardcoded credential-like string."

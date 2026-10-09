/**
 * @name Hardcoded credential
 * @description A constant or variable whose name suggests a password, API key, secret,
 *              or authentication token is initialized with a non-empty string
 *              literal, embedding the credential directly in source where it can
 *              leak via version control, decompilation, or logs.
 * @id ada/hardcoded-credential
 * @kind problem
 * @problem.severity error
 * @tags security
 */

import ada

/**
 * Gets the pattern a credential-like name matches (lower case). "token" alone is too
 * broad (a lexer's `Token_Kind_Name`, `Protected_Token`), so it counts only on its own
 * or with an authentication qualifier (`Auth_Token`, `Access_Token`, `Bearer_Token`, ...).
 */
private string credentialName() {
  result =
    ".*(password|passwd|secret|api_key|apikey|credential).*" + "|" +
      "(.*_)?(auth|access|bearer|session|refresh|api|oauth|csrf|secret|private|id)_?token(_.*)?" +
      "|token"
}

from ObjectDecl d, StringLiteral lit
where
  d.getDefaultExpr() = lit and
  lit.getValue().length() > 2 and
  d.getAName().toLowerCase().regexpMatch(credentialName()) and
  // a lexer's keyword token, `Access_Token := "access"`, spells its own name
  not lit.getValue().toLowerCase() =
    "\"" + d.getAName().toLowerCase().regexpCapture("(.*)_token", 1) + "\"" and
  d.fromSource()
select d, "Object " + d.getAName() + " is initialized with a hardcoded credential-like string."

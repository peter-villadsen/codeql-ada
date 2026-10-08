/**
 * Ada QL library: user-facing entry point.
 *
 * Every AST class is available without a prefix (`IfStmt`, `CallExpr`, `BasicDecl`),
 * with the hand-written predicates of `codeql/ada/ast/internal/Extensions.qll` on the
 * same classes (D-027). `Raw::X` names the same class as `X`.
 */

import codeql.ada.ast.internal.Raw
import codeql.ada.ast.internal.Raw::Raw

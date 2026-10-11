/**
 * Metrics of subprograms, as `MetricCallable` gives them in CodeQL for Java. Reached
 * through `Subprogram.getMetrics()`.
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Subprograms

/**
 * Holds if `d` is a decision: a point where control takes one of two or more ways.
 * `if` and `elsif` (statements and expressions), `while` and `for` loops, `exit when`,
 * `and then` and `or else`, quantified expressions, each alternative of a `case`
 * after the first, each exception handler, and each alternative of a `select` after
 * the first.
 */
predicate isDecision(Raw::AdaNode d) {
  d instanceof Raw::IfStmt or
  d instanceof Raw::ElsifStmtPart or
  d instanceof Raw::IfExpr or
  d instanceof Raw::ElsifExprPart or
  d instanceof Raw::WhileLoopStmt or
  d instanceof Raw::ForLoopStmt or
  d instanceof Raw::QuantifiedExpr or
  d instanceof Raw::ExceptionHandler or
  exists(d.(Raw::ExitStmt).getCondExpr()) or
  d.(Raw::BinOp).getOp() instanceof Raw::OpAndThen or
  d.(Raw::BinOp).getOp() instanceof Raw::OpOrElse or
  (
    d instanceof Raw::CaseStmtAlternative or
    d instanceof Raw::CaseExprAlternative or
    d instanceof Raw::SelectWhenPart
  ) and
  not d = d.getParent().getChild(0)
}

/** A subprogram, with its metrics. */
class MetricSubprogram extends Subprogram {
  /**
   * Gets the number of statements in this subprogram's body, not counting those of
   * subprograms nested in it. A compound statement (`if`, a loop) counts once, as do
   * the statements inside it.
   */
  int getNumberOfStatements() { result = count(Raw::Stmt s | s.getEnclosingSubprogram() = this) }

  /**
   * Gets McCabe's cyclomatic complexity of this subprogram: one more than the number
   * of decisions (`isDecision`) in its body, not counting those of subprograms nested
   * in it. A subprogram without a body has complexity 1.
   */
  int getCyclomaticComplexity() {
    result = 1 + count(Raw::AdaNode d | isDecision(d) and d.getEnclosingSubprogram() = this)
  }
}

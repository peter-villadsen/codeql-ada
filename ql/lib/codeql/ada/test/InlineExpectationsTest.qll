/**
 * Ada binding for the shared inline-expectations test framework
 * (`codeql.util.test.InlineExpectationsTest`, from `codeql/util`, pulled in
 * transitively by `codeql/controlflow`).
 *
 * Inline expectations let a test state its expected results as comments in the
 * Ada source under test, rather than in a learned `.expected` file:
 *
 * ```ada
 * Total := Total + 1;  -- $ edge=AssignStmt@25:7|successor|IntLiteral@26:9
 * ```
 *
 * The `.expected` file of such a test is empty; any mismatch is reported by the
 * `testFailures` query predicate. See `docs/cfg-design.md` for the CFG
 * conformance tests built on this, and the shared framework's own file
 * documentation for the full annotation syntax (`MISSING:`, `SPURIOUS:`, …).
 *
 * Note that an expectation matches a result when the comment's **start** line
 * equals the result location's **end** line, so an annotation for a multi-line
 * element goes on the line where that element ends.
 */

private import codeql.util.test.InlineExpectationsTest
private import codeql.ada.ast.internal.Raw

private module Impl implements InlineExpectationsTestSig {
  class Location = Raw::Location;

  /**
   * An Ada comment, with the `--` indicator stripped. Comments are extracted as
   * trivia (`ada_comments`) and carry their leading `--`, which the framework
   * requires us to remove.
   */
  class ExpectationComment extends Raw::Comment {
    string getContents() { result = this.getText().regexpReplaceAll("^--", "") }
  }
}

/**
 * The location type used by `TestSig.hasActualResult`. Exported so that a test
 * module implementing `TestSig` need not reach into the internal AST layer for
 * it.
 */
class Location = Raw::Location;

import Make<Impl>

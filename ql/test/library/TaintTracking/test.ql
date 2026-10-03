/**
 * Taint tracking (Task 9.5): every `Source (N)` call whose value reaches an
 * argument of `Test.Sink` -- written with the `DataFlow::isCallTo` /
 * `getAnArgument` helpers a query author would use -- is reported as `taint=N`
 * on the sink's line. Formals of `Test.Handle` are also sources, through
 * `DataFlow::isParameterOf`, reported as `taint=param`. A call to `Test.Sanitize` is a
 * barrier.
 */

import ada
import codeql.ada.dataflow.DataFlow
import codeql.ada.dataflow.TaintTracking
import codeql.ada.test.InlineExpectationsTest

/** Gets the literal `N` of source call `Source (N)`, or `param` for a formal of `Test.Handle`. */
string sourceId(DataFlow::Node n) {
  exists(Raw::CallExpr c | c = n.asExpr() |
    DataFlow::isCallTo(c, "Test.Source") and
    exists(Raw::IntLiteral lit | DataFlow::isArgumentAt(c, lit, 0) and result = lit.getValue())
  )
  or
  DataFlow::isParameterOf(n, "Test.Handle") and result = "param"
}

module TestConfig implements DataFlow::ConfigSig {
  predicate isSource(DataFlow::Node n) { exists(sourceId(n)) }

  predicate isSink(DataFlow::Node n) {
    exists(Raw::Expr call | DataFlow::isCallTo(call, "Test.Sink") |
      n.asExpr() = DataFlow::getAnArgument(call)
    )
  }

  predicate isBarrier(DataFlow::Node n) {
    exists(Raw::Expr call | DataFlow::isCallTo(call, "Test.Sanitize") | n.asExpr() = call)
  }
}

module TestFlow = TaintTracking::Global<TestConfig>;

module FlowTest implements TestSig {
  string getARelevantTag() { result = "taint" }

  predicate hasActualResult(Location location, string element, string tag, string value) {
    exists(DataFlow::Node source, DataFlow::Node sink |
      TestFlow::flow(source, sink) and
      location = sink.getLocation() and
      element = sink.toString() and
      tag = "taint" and
      value = sourceId(source)
    )
  }
}

import MakeTest<FlowTest>

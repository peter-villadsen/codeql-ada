/**
 * Cross-procedure data flow (Task 9.4): every `Source (N)` call whose value reaches
 * the argument of a `Sink` call, reported as `flow=N` on the sink's line.
 */

import ada
import codeql.ada.dataflow.internal.DataFlowImpl
import codeql.ada.test.InlineExpectationsTest

/** Gets the literal `N` of source call `Source (N)`. */
string sourceId(AdaDataFlowInput::Node n) {
  exists(Raw::CallExpr c | c = n.asExpr() |
    c.getName().(Name).getText() = "Source" and
    result = c.getSuffix().(Raw::AssocList).getChild(0).(Raw::ParamAssoc).getRExpr().(Raw::IntLiteral).getValue()
  )
}

module TestConfig implements AdaDataFlow::ConfigSig {
  predicate isSource(AdaDataFlowInput::Node n) { exists(sourceId(n)) }

  predicate isSink(AdaDataFlowInput::Node n) {
    exists(Raw::CallExpr c | c.getName().(Name).getText() = "Sink" |
      n.asExpr() = c.getSuffix().(Raw::AssocList).getChild(0).(Raw::ParamAssoc).getRExpr()
    )
  }
}

module TestFlow = AdaDataFlow::Global<TestConfig>;

module FlowTest implements TestSig {
  string getARelevantTag() { result = "flow" }

  predicate hasActualResult(Location location, string element, string tag, string value) {
    exists(AdaDataFlowInput::Node source, AdaDataFlowInput::Node sink |
      TestFlow::flow(source, sink) and
      location = sink.getLocation() and
      element = sink.toString() and
      tag = "flow" and
      value = sourceId(source)
    )
  }
}

import MakeTest<FlowTest>

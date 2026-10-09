/**
 * @name Untrusted data reaches My_App.Db.Execute
 * @description A value from the command line or from a request reaches the query
 *              that My_App.Db.Execute runs without passing My_App.Validate.Sanitize.
 * @kind path-problem
 * @id my-app/untrusted-to-execute
 * @problem.severity error
 */

import ada
import codeql.ada.dataflow.DataFlow
import codeql.ada.dataflow.TaintTracking
import codeql.ada.security.CommandInjection

module Config implements DataFlow::ConfigSig {
  // What counts as untrusted: the command line (the library's built-in source) and
  // the parameters of the request handler.
  predicate isSource(DataFlow::Node n) {
    n instanceof CommandInjection::Source
    or
    exists(Parameter p | p.getSubprogram().hasQualifiedName("My_App.Server.Handle_Request") |
      n.asParameter() = p.getADeclaration()
    )
  }

  // Every argument of every call to My_App.Db.Execute.
  predicate isSink(DataFlow::Node n) {
    exists(Call c | c.getTarget().hasQualifiedName("My_App.Db.Execute") |
      n.asExpr() = c.getAnArgument()
    )
  }

  // What Sanitize returns is clean.
  predicate isBarrier(DataFlow::Node n) {
    exists(Call c | c.getTarget().hasQualifiedName("My_App.Validate.Sanitize") | n.asExpr() = c)
  }
}

module Flow = TaintTracking::Global<Config>;

import Flow::PathGraph

from Flow::PathNode source, Flow::PathNode sink
where Flow::flowPath(source, sink) and sink.getNode().asExpr().fromSource()
select sink.getNode(), source, sink, "This query depends on $@.", source.getNode(), "untrusted data"

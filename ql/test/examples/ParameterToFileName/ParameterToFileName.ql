/**
 * @name Public parameter names a file
 * @description A parameter of a subprogram in a package's visible part reaches the
 *              name of a file that is opened or created, so every caller of the
 *              package decides which file it touches.
 * @kind path-problem
 * @id my-app/parameter-to-file-name
 * @problem.severity recommendation
 */

import ada
import codeql.ada.dataflow.DataFlow
import codeql.ada.dataflow.TaintTracking

module Config implements DataFlow::ConfigSig {
  // The parameters of every subprogram declared in the visible part of a package.
  predicate isSource(DataFlow::Node n) {
    exists(Package pkg, Parameter p |
      pkg.fromSource() and
      p.getSubprogram() = pkg.getAPublicMember() and
      n.asParameter() = p.getADeclaration()
    )
  }

  // The `Name` argument of Ada.Text_IO.Open and Create, positional or named.
  predicate isSink(DataFlow::Node n) {
    exists(Call c |
      c.getTarget().hasQualifiedName(["Ada.Text_IO.Open", "Ada.Text_IO.Create"]) and
      n.asExpr() = c.getArgumentByName("Name")
    )
  }
}

module Flow = TaintTracking::Global<Config>;

import Flow::PathGraph

from Flow::PathNode source, Flow::PathNode sink
where Flow::flowPath(source, sink) and sink.getNode().asExpr().fromSource()
select sink.getNode(), source, sink, "This file name comes from $@.", source.getNode(),
  "a public parameter"

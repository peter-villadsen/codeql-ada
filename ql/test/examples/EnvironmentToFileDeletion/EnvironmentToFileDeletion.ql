/**
 * @name Environment variable decides which file is deleted
 * @description The value of an environment variable reaches the name of a file or
 *              directory that is deleted. Whoever sets the environment chooses what
 *              is removed.
 * @kind path-problem
 * @id my-app/environment-to-file-deletion
 * @problem.severity warning
 */

import ada
import codeql.ada.dataflow.DataFlow
import codeql.ada.dataflow.TaintTracking

module Config implements DataFlow::ConfigSig {
  predicate isSource(DataFlow::Node n) {
    exists(Call c | c.getTarget().hasQualifiedName("Ada.Environment_Variables.Value") |
      n.asExpr() = c
    )
  }

  predicate isSink(DataFlow::Node n) {
    exists(Call c |
      c.getTarget()
          .hasQualifiedName([
              "Ada.Directories.Delete_File", "Ada.Directories.Delete_Directory",
              "Ada.Directories.Delete_Tree"
            ])
    |
      n.asExpr() = c.getArgument(0)
    )
  }
}

module Flow = TaintTracking::Global<Config>;

import Flow::PathGraph

from Flow::PathNode source, Flow::PathNode sink
where Flow::flowPath(source, sink) and sink.getNode().asExpr().fromSource()
select sink.getNode(), source, sink, "The file deleted here is named by $@.", source.getNode(),
  "an environment variable"

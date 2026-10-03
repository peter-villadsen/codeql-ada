/**
 * @name Command built from a command-line argument
 * @description A value read with `Ada.Command_Line.Argument` reaches the program name
 *              or the argument list of `GNAT.OS_Lib.Spawn` or `Non_Blocking_Spawn`,
 *              possibly through other subprograms. Whoever starts the program then
 *              chooses what it runs.
 *
 *              The source and the sinks are recognised by what they resolve to
 *              (D-026), so `use` clauses and renamings are covered, and both the
 *              `GNAT.OS_Lib` and `System.OS_Lib` spellings (`GNAT.OS_Lib` is a
 *              renaming) are sinks. Every overload is a sink, but only at its
 *              `Program_Name` and `Args` parameters; `Output_File` names a file, not
 *              a command. Without a GNAT runtime at extraction neither end resolves
 *              and the query finds nothing. v1 limitations are those of the data-flow
 *              library (`docs/dataflow-design.md`, "Named v1 limitations"): no
 *              dispatching or access-to-subprogram calls, no package-level variables,
 *              record components tracked only as a whole.
 * @id ada/command-line-injection
 * @kind path-problem
 * @problem.severity error
 * @security-severity 9.8
 * @precision medium
 * @tags security external/cwe/cwe-078
 */

import ada
import codeql.ada.dataflow.DataFlow
import codeql.ada.dataflow.TaintTracking

/** Holds if `call` is a call to `Ada.Command_Line.Argument`. */
private predicate isCommandLineArgument(Raw::CallExpr call) {
  call.getName()
      .(Name)
      .getReferencedDecl()
      .(BasicDecl)
      .getUltimateDecl()
      .(BasicDecl)
      .hasQualifiedName("Ada.Command_Line.Argument")
}

/**
 * Holds if `e` is the program name or argument list passed to `System.OS_Lib.Spawn`
 * or `Non_Blocking_Spawn`.
 */
private predicate isSpawnCommand(Raw::Expr e) {
  exists(Raw::Expr call |
    DataFlow::getCallTarget(call)
        .(BasicDecl)
        .hasQualifiedName(["System.OS_Lib.Spawn", "System.OS_Lib.Non_Blocking_Spawn"]) and
    DataFlow::isArgumentFor(call, e, ["Program_Name", "Args"])
  )
}

module CommandLineInjectionConfig implements DataFlow::ConfigSig {
  predicate isSource(DataFlow::Node n) { isCommandLineArgument(n.asExpr()) }

  predicate isSink(DataFlow::Node n) { isSpawnCommand(n.asExpr()) }
}

module CommandLineInjectionFlow = TaintTracking::Global<CommandLineInjectionConfig>;

import CommandLineInjectionFlow::PathGraph

from CommandLineInjectionFlow::PathNode source, CommandLineInjectionFlow::PathNode sink
where
  CommandLineInjectionFlow::flowPath(source, sink) and
  sink.getNode().asExpr().(AdaNode).fromSource()
select sink.getNode(), source, sink, "This command depends on a $@.", source.getNode(),
  "command-line argument"

/**
 * @name Command built from a command-line argument
 * @description A value read with `Ada.Command_Line.Argument` reaches a command that the
 *              program runs, possibly through other subprograms. Whoever starts the
 *              program then chooses what it runs.
 *
 *              Sinks (`codeql/ada/security/CommandInjection.qll`): the program name
 *              and argument list of every overload of `GNAT.OS_Lib.Spawn` and
 *              `Non_Blocking_Spawn` (either spelling; `GNAT.OS_Lib` renames
 *              `System.OS_Lib`), the command and arguments of
 *              `GNAT.Expect.Non_Blocking_Spawn` and `Get_Command_Output`, and the
 *              command of an imported C `system` or `popen` or any argument of the
 *              `exec` family. Formals that name files (`Output_File`) or carry stdin
 *              data are not sinks. Runtime entities are recognised by what they
 *              resolve to (D-026), so `use` clauses and renamings are covered;
 *              without a GNAT runtime at extraction the query finds nothing. v1
 *              limitations are those of the data-flow library
 *              (`docs/dataflow-design.md`, "Named v1 limitations"): no dispatching or
 *              access-to-subprogram calls, no package-level variables, record
 *              components tracked only as a whole.
 * @id ada/command-line-injection
 * @kind path-problem
 * @problem.severity error
 * @security-severity 9.8
 * @precision medium
 * @tags security external/cwe/cwe-078
 */

import ada
import codeql.ada.security.CommandInjection
import CommandInjection::Flow::PathGraph

from CommandInjection::Flow::PathNode source, CommandInjection::Flow::PathNode sink
where
  CommandInjection::Flow::flowPath(source, sink) and
  sink.getNode().asExpr().fromSource()
select sink.getNode(), source, sink, "This command depends on a $@.", source.getNode(),
  "command-line argument"

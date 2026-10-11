/**
 * @name Uncontrolled data used in path expression
 * @description Data received from the network names a file or directory that the
 *              program opens, creates, deletes, renames or copies, possibly through
 *              other subprograms. A remote party can then reach files outside the
 *              ones the program means to use (`../../etc/passwd`).
 *
 *              Sources (`codeql/ada/security/FlowSources.qll`, `RemoteFlowSource`):
 *              data received with `GNAT.Sockets` and AWS request data. Sinks
 *              (`codeql/ada/security/PathInjection.qll`): the file name of `Open` and
 *              `Create` in `Ada.Text_IO`, `Ada.Streams.Stream_IO` and instances of
 *              `Ada.Sequential_IO` and `Ada.Direct_IO`; the paths of
 *              `Ada.Directories` (`Delete_File`, `Rename`, `Copy_File`, ...) and of
 *              the `GNAT.OS_Lib` file operations. The result of
 *              `Ada.Directories.Simple_Name` is a barrier. Command-line arguments and
 *              environment variables are not sources: a tool that opens the file it
 *              is given is doing its job.
 * @id ada/path-injection
 * @kind path-problem
 * @problem.severity error
 * @security-severity 7.5
 * @precision high
 * @tags security external/cwe/cwe-022 external/cwe/cwe-023 external/cwe/cwe-036
 *       external/cwe/cwe-073
 */

import ada
import codeql.ada.security.PathInjection
import PathInjection::Flow::PathGraph

from PathInjection::Flow::PathNode source, PathInjection::Flow::PathNode sink
where
  PathInjection::Flow::flowPath(source, sink) and
  sink.getNode().asExpr().fromSource()
select sink.getNode(), source, sink, "This path depends on $@.", source.getNode(),
  source.getNode().(PathInjection::Source).getSourceType()

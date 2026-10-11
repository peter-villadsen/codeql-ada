/**
 * @name SQL query built from user-controlled sources
 * @description Data received from the network becomes part of the text of an SQL
 *              statement, possibly through other subprograms. A remote party can then
 *              change what the statement does.
 *
 *              Sources (`codeql/ada/security/FlowSources.qll`, `RemoteFlowSource`):
 *              data received with `GNAT.Sockets` and AWS request data. Sinks
 *              (`codeql/ada/security/SqlInjection.qll`): the `Query` string of
 *              `GNATCOLL.SQL.Exec.Execute`, `Fetch`, `Insert_And_Get_PK` and `Prepare`.
 *              Pass values as parameters (`Params`) instead, or build the query with
 *              GNATCOLL's typed query API.
 * @id ada/sql-injection
 * @kind path-problem
 * @problem.severity error
 * @security-severity 8.8
 * @precision high
 * @tags security external/cwe/cwe-089
 */

import ada
import codeql.ada.security.SqlInjection
import SqlInjection::Flow::PathGraph

from SqlInjection::Flow::PathNode source, SqlInjection::Flow::PathNode sink
where
  SqlInjection::Flow::flowPath(source, sink) and
  sink.getNode().asExpr().fromSource()
select sink.getNode(), source, sink, "This query depends on $@.", source.getNode(),
  source.getNode().(SqlInjection::Source).getSourceType()

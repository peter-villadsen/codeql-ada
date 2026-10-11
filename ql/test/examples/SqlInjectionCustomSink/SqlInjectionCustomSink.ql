/**
 * @name SQL statement built from network data
 * @description Data received from the network becomes part of the text of an SQL
 *              statement run by the in-house database layer `Db`.
 * @kind path-problem
 * @id my-app/sql-injection
 * @problem.severity error
 * @tags security
 */

import ada
import codeql.ada.security.SqlInjection
import SqlInjection::Flow::PathGraph

/** The text of a statement run by `Db.Run`: a sink. */
class DbRunSql extends SqlInjection::Sink {
  DbRunSql() {
    exists(Call c | c.getTarget().hasQualifiedName("Db.Run") |
      this.asExpr() = c.getArgumentByName("Sql")
    )
  }
}

/** A value quoted by `Db.Quote`, safe inside a statement: a barrier. */
class DbQuoted extends SqlInjection::Barrier {
  DbQuoted() {
    exists(Call c | c.getTarget().hasQualifiedName("Db.Quote") | this.asExpr() = c)
  }
}

from SqlInjection::Flow::PathNode source, SqlInjection::Flow::PathNode sink
where
  SqlInjection::Flow::flowPath(source, sink) and
  sink.getNode().asExpr().fromSource()
select sink.getNode(), source, sink, "This SQL statement depends on $@.", source.getNode(),
  source.getNode().(SqlInjection::Source).getSourceType()

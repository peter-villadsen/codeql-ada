/**
 * Sources, sinks and barriers for SQL injection, used by `ada/sql-injection`
 * (`SqlInjection.ql`): untrusted data in the text of an SQL statement run through
 * `GNATCOLL.SQL.Exec`.
 *
 * `Source`, `Sink` and `Barrier` are extension points, as in `CommandInjection`.
 */

private import ada
private import codeql.ada.dataflow.DataFlow
private import codeql.ada.dataflow.TaintTracking
private import codeql.ada.security.FlowSources

module SqlInjection {
  /** A value an attacker may control. */
  abstract class Source extends DataFlow::Node {
    /** Gets a description of this source, used in the query message. */
    abstract string getSourceType();
  }

  /** A value run as, or as part of, the text of an SQL statement. */
  abstract class Sink extends DataFlow::Node { }

  /** A node past which a value is no longer considered attacker-controlled. */
  abstract class Barrier extends DataFlow::Node { }

  /** Data received from the network (`RemoteFlowSource`). */
  private class RemoteSource extends Source instanceof RemoteFlowSource {
    override string getSourceType() { result = RemoteFlowSource.super.getSourceType() }
  }

  /**
   * The query text of `GNATCOLL.SQL.Exec.Execute`, `Fetch`, `Insert_And_Get_PK` and
   * `Prepare`, in the overloads that take it as a `String`. The overloads that take a
   * `GNATCOLL.SQL.SQL_Query` are built with the typed query API, and values bound as
   * parameters (`Params`) are not part of the statement's text.
   */
  private class GnatcollExecSink extends Sink {
    GnatcollExecSink() {
      exists(Call c, Parameter query |
        c.getTarget()
            .hasQualifiedName([
                "GNATCOLL.SQL.Exec.Execute", "GNATCOLL.SQL.Exec.Fetch",
                "GNATCOLL.SQL.Exec.Insert_And_Get_PK", "GNATCOLL.SQL.Exec.Prepare"
              ]) and
        query = c.getTarget().getAParameter() and
        query.hasName("Query") and
        query.getType().(BasicDecl).hasQualifiedName("Standard.String") and
        this.asExpr() = c.getArgumentFor(query)
      )
    }
  }

  /** Taint flow from a `Source` to a `Sink`, stopped at a `Barrier`. */
  module Config implements DataFlow::ConfigSig {
    predicate isSource(DataFlow::Node n) { n instanceof Source }

    predicate isSink(DataFlow::Node n) { n instanceof Sink }

    predicate isBarrier(DataFlow::Node n) { n instanceof Barrier }
  }

  /** SQL injection flow. */
  module Flow = TaintTracking::Global<Config>;
}

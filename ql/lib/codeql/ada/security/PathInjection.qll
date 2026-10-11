/**
 * Sources, sinks and barriers for path injection, used by `ada/path-injection`
 * (`PathInjection.ql`): untrusted data that names a file or directory to open, create,
 * delete, rename or copy.
 *
 * `Source`, `Sink` and `Barrier` are extension points, as in `CommandInjection`.
 */

private import ada
private import codeql.ada.dataflow.DataFlow
private import codeql.ada.dataflow.TaintTracking
private import codeql.ada.security.FlowSources

module PathInjection {
  /** A value an attacker may control. */
  abstract class Source extends DataFlow::Node {
    /** Gets a description of this source, used in the query message. */
    abstract string getSourceType();
  }

  /** A value used as the name of a file or directory. */
  abstract class Sink extends DataFlow::Node { }

  /** A node past which a value can no longer name an arbitrary path. */
  abstract class Barrier extends DataFlow::Node { }

  /** Data received from the network (`RemoteFlowSource`). */
  private class RemoteSource extends Source instanceof RemoteFlowSource {
    override string getSourceType() { result = RemoteFlowSource.super.getSourceType() }
  }

  /**
   * Holds if parameter `formal` of the runtime subprogram `name` names a file or
   * directory. Generic I/O packages (`Ada.Sequential_IO`, `Ada.Direct_IO`) are matched
   * by the generic's name: a call to a subprogram of an instance resolves to it.
   */
  private predicate pathFormal(string name, string formal) {
    name =
      [
        "Ada.Text_IO.Open", "Ada.Text_IO.Create", "Ada.Wide_Text_IO.Open",
        "Ada.Wide_Text_IO.Create", "Ada.Streams.Stream_IO.Open", "Ada.Streams.Stream_IO.Create",
        "Ada.Sequential_IO.Open", "Ada.Sequential_IO.Create", "Ada.Direct_IO.Open",
        "Ada.Direct_IO.Create"
      ] and
    formal = "Name"
    or
    name =
      [
        "Ada.Directories.Delete_File", "Ada.Directories.Delete_Directory",
        "Ada.Directories.Delete_Tree"
      ] and
    formal = ["Name", "Directory"]
    or
    name = ["Ada.Directories.Create_Directory", "Ada.Directories.Create_Path"] and
    formal = "New_Directory"
    or
    name = "Ada.Directories.Rename" and formal = ["Old_Name", "New_Name"]
    or
    name = "Ada.Directories.Copy_File" and formal = ["Source_Name", "Target_Name"]
    or
    name = "Ada.Directories.Set_Directory" and formal = "Directory"
    or
    name =
      [
        "System.OS_Lib.Open_Read", "System.OS_Lib.Open_Read_Write", "System.OS_Lib.Open_Append",
        "System.OS_Lib.Create_File", "System.OS_Lib.Create_New_File",
        "System.OS_Lib.Create_Output_Text_File", "System.OS_Lib.Delete_File"
      ] and
    formal = "Name"
    or
    name = ["System.OS_Lib.Rename_File", "System.OS_Lib.Copy_File"] and
    formal = ["Old_Name", "New_Name", "Name", "Pathname"]
  }

  /** The file or directory name passed to a runtime subprogram that opens, creates, deletes, renames or copies it. */
  private class RuntimePathSink extends Sink {
    RuntimePathSink() {
      exists(Call c, string name, string formal |
        pathFormal(name, formal) and
        c.getTarget().hasQualifiedName(name) and
        this.asExpr() = c.getArgumentByName(formal)
      )
    }
  }

  /**
   * The result of `Ada.Directories.Simple_Name`: the last component of a path, with no
   * directory part, so it cannot climb out of the directory it is used in.
   */
  private class SimpleNameBarrier extends Barrier {
    SimpleNameBarrier() {
      exists(Call c | c.getTarget().hasQualifiedName("Ada.Directories.Simple_Name") |
        this.asExpr() = c
      )
    }
  }

  /** Taint flow from a `Source` to a `Sink`, stopped at a `Barrier`. */
  module Config implements DataFlow::ConfigSig {
    predicate isSource(DataFlow::Node n) { n instanceof Source }

    predicate isSink(DataFlow::Node n) { n instanceof Sink }

    predicate isBarrier(DataFlow::Node n) { n instanceof Barrier }
  }

  /** Path injection flow. */
  module Flow = TaintTracking::Global<Config>;
}

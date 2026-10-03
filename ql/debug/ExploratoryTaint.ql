/**
 * @name Exploratory taint: untrusted input to commands and file names
 * @description Developer tool for Task 9.6, not a shipped query. Broader sources than
 *              `ada/command-line-injection` (environment variables, standard input,
 *              GNAT.Command_Line), into its command sinks plus file-name parameters of
 *              the file and directory APIs. Meant to exercise data flow on real code so
 *              its results can be triaged by hand; see docs/dataflow-design.md.
 * @kind path-problem
 * @id ada/debug/exploratory-taint
 * @problem.severity warning
 */

import ada
import codeql.ada.dataflow.DataFlow
import codeql.ada.dataflow.TaintTracking
import codeql.ada.security.CommandInjection

/** Gets the kind of untrusted input `n` is, if any. */
string sourceKind(DataFlow::Node n) {
  n instanceof CommandInjection::Source and result = "command-line argument"
  or
  exists(Raw::Expr call | n.asExpr() = call |
    DataFlow::isCallTo(call, ["Ada.Environment_Variables.Value", "System.OS_Lib.Getenv"]) and
    result = "environment variable"
    or
    DataFlow::isCallTo(call, "Ada.Text_IO.Get_Line") and result = "standard input"
    or
    DataFlow::isCallTo(call,
      [
        "GNAT.Command_Line.Get_Argument", "GNAT.Command_Line.Parameter",
        "GNAT.Command_Line.Full_Switch"
      ]) and
    result = "command-line argument (GNAT.Command_Line)"
  )
}

/** Holds if `formal` of `name` takes a file or directory name. */
private predicate fileNameFormal(string name, string formal) {
  name =
    [
      "Ada.Text_IO.Open", "Ada.Text_IO.Create", "Ada.Streams.Stream_IO.Open",
      "Ada.Streams.Stream_IO.Create", "Ada.Directories.Delete_File",
      "System.OS_Lib.Delete_File"
    ] and
  formal = "Name"
  or
  name = ["Ada.Directories.Delete_Tree", "Ada.Directories.Delete_Directory"] and
  formal = "Directory"
  or
  name = "Ada.Directories.Copy_File" and formal = ["Source_Name", "Target_Name"]
  or
  name = "Ada.Directories.Rename" and formal = ["Old_Name", "New_Name"]
}

/** Gets the kind of sink `n` is, if any. */
string sinkKind(DataFlow::Node n) {
  n instanceof CommandInjection::Sink and result = "command"
  or
  exists(Raw::Expr call, string name, string formal |
    fileNameFormal(name, formal) and
    DataFlow::isCallTo(call, name) and
    DataFlow::isArgumentFor(call, n.asExpr(), formal) and
    result = "file name (" + name + ")"
  )
}

module Config implements DataFlow::ConfigSig {
  predicate isSource(DataFlow::Node n) { exists(sourceKind(n)) }

  predicate isSink(DataFlow::Node n) { exists(sinkKind(n)) }
}

module Flow = TaintTracking::Global<Config>;

import Flow::PathGraph

from Flow::PathNode source, Flow::PathNode sink
where Flow::flowPath(source, sink) and sink.getNode().asExpr().(AdaNode).fromSource()
select sink.getNode(), source, sink, "This " + sinkKind(sink.getNode()) + " depends on $@.",
  source.getNode(), sourceKind(source.getNode())

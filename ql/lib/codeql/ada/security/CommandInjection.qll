/**
 * Sources, sinks and barriers for command injection, used by
 * `ada/command-line-injection` (`CommandLineInjection.ql`).
 *
 * Each of `Source`, `Sink` and `Barrier` is an extension point: a query that
 * imports this module and declares a subclass of one of them adds to it, e.g.
 *
 * ```ql
 * class MyShellSink extends CommandInjection::Sink {
 *   MyShellSink() {
 *     exists(Raw::Expr call |
 *       DataFlow::isCallTo(call, "My_App.Shell.Run") and
 *       DataFlow::isArgumentFor(call, this.asExpr(), "Command")
 *     )
 *   }
 * }
 * ```
 *
 * All runtime entities are matched by what names resolve to (D-026); without a GNAT
 * runtime at extraction they do not resolve and nothing here matches.
 */

private import ada
private import codeql.ada.dataflow.DataFlow
private import codeql.ada.dataflow.TaintTracking

module CommandInjection {
  /** A value an attacker may control. */
  abstract class Source extends DataFlow::Node { }

  /** A value that is run as, or as part of, an operating-system command. */
  abstract class Sink extends DataFlow::Node { }

  /** A node past which a value is no longer considered attacker-controlled. */
  abstract class Barrier extends DataFlow::Node { }

  /** The result of `Ada.Command_Line.Argument`. */
  private class CommandLineArgument extends Source {
    CommandLineArgument() {
      this.asExpr()
          .(Raw::CallExpr)
          .getName()
          .(Name)
          .getReferencedDecl()
          .(BasicDecl)
          .getUltimateDecl()
          .(BasicDecl)
          .hasQualifiedName("Ada.Command_Line.Argument")
    }
  }

  /**
   * Holds if formal `formal` of runtime subprogram `name` is a command or its
   * arguments. Every overload of `name` is covered; formals that name files
   * (`Output_File`), carry stdin data (`Input`) or return results are not sinks.
   */
  private predicate runtimeCommandFormal(string name, string formal) {
    name = ["System.OS_Lib.Spawn", "System.OS_Lib.Non_Blocking_Spawn"] and
    formal = ["Program_Name", "Args"]
    or
    name = "GNAT.Expect.Non_Blocking_Spawn" and formal = ["Command", "Args"]
    or
    name = "GNAT.Expect.Get_Command_Output" and formal = ["Command", "Arguments"]
  }

  /** The command or argument list of a GNAT runtime subprogram that runs a program. */
  private class RuntimeCommandSink extends Sink {
    RuntimeCommandSink() {
      exists(Raw::Expr call, string name, string formal |
        runtimeCommandFormal(name, formal) and
        DataFlow::isCallTo(call, name) and
        DataFlow::isArgumentFor(call, this.asExpr(), formal)
      )
    }
  }

  /** Gets the text of string literal `e` without its quotes. */
  private string literalText(Raw::Expr e) {
    result = e.(Raw::StringLiteral).getValue().regexpCapture("\"(.*)\"", 1)
  }

  /** Holds if pragma `p` (`Import` or `Interface`) names `d` as its entity. */
  private predicate importPragmaFor(Raw::PragmaNode p, Raw::BasicDecl d) {
    p.getId().getValue().toLowerCase() = ["import", "interface"] and
    exists(Raw::PragmaArgumentAssoc entity |
      entity = p.getArgs().getChild(1) and not exists(entity.getName())
      or
      entity = p.getArgs().getChild(_) and
      entity.getName().(Name).getText().toLowerCase() = "entity"
    |
      entity.getExpr().(Name).getReferencedDecl() = d
      or
      // An entity name that does not resolve: pair by name within the same list.
      not exists(entity.getExpr().(Name).getReferencedDecl()) and
      p.getParent() = d.getParent() and
      entity.getExpr().(Name).getText().toLowerCase() = d.(BasicDecl).getAName().toLowerCase()
    )
  }

  /** Holds if `d` is imported from a foreign language, by pragma or by aspect. */
  private predicate isImported(Raw::BasicDecl d) {
    importPragmaFor(_, d)
    or
    exists(Raw::AspectAssoc a | a = d.getAspects().getAspectAssocs().getChild(_) |
      a.getId().(Name).getText().toLowerCase() = "import" and
      not a.getExpr().(Name).getText().toLowerCase() = "false"
    )
  }

  /**
   * Gets the explicit external (link) name of imported subprogram `d`: an
   * `External_Name` or `Link_Name` aspect, or a pragma's third argument or named
   * `External_Name` / `Link_Name`.
   */
  private string explicitExternalName(Raw::BasicDecl d) {
    exists(Raw::AspectAssoc a | a = d.getAspects().getAspectAssocs().getChild(_) |
      a.getId().(Name).getText().toLowerCase() = ["external_name", "link_name"] and
      result = literalText(a.getExpr())
    )
    or
    exists(Raw::PragmaNode p, Raw::PragmaArgumentAssoc arg |
      importPragmaFor(p, d) and arg = p.getArgs().getChild(_)
    |
      arg.getParentIndex() = 2 and not exists(arg.getName()) and result = literalText(arg.getExpr())
      or
      arg.getName().(Name).getText().toLowerCase() = ["external_name", "link_name"] and
      result = literalText(arg.getExpr())
    )
  }

  /**
   * Gets the external name of imported subprogram `d`: the explicit one if given,
   * else its Ada name lower-cased, GNAT's default for convention C.
   */
  private string externalName(Raw::BasicDecl d) {
    isImported(d) and
    (
      result = explicitExternalName(d)
      or
      not exists(explicitExternalName(d)) and result = d.(BasicDecl).getAName().toLowerCase()
    )
  }

  /**
   * An argument to an imported C function that runs a command: the command string
   * of `system` and `popen`, and every argument of the `exec` family (the program
   * and its argument vector).
   */
  private class ImportedCCommandSink extends Sink {
    ImportedCCommandSink() {
      exists(Raw::Expr call, string ext | ext = externalName(DataFlow::getCallTarget(call)) |
        ext = ["system", "popen"] and
        DataFlow::isArgumentAt(call, this.asExpr(), 0)
        or
        ext = ["execl", "execlp", "execle", "execv", "execvp", "execve", "execvpe"] and
        this.asExpr() = DataFlow::getAnArgument(call)
      )
    }
  }

  /** The flow configuration of `ada/command-line-injection`. */
  module Config implements DataFlow::ConfigSig {
    predicate isSource(DataFlow::Node n) { n instanceof Source }

    predicate isSink(DataFlow::Node n) { n instanceof Sink }

    predicate isBarrier(DataFlow::Node n) { n instanceof Barrier }
  }

  /** Taint flow from a `Source` to a `Sink`. */
  module Flow = TaintTracking::Global<Config>;
}

/**
 * Sources of untrusted data, shared by the security queries: data received from the
 * network (`RemoteFlowSource`), and data from the local user, the command line and the
 * environment (`LocalUserInput`).
 *
 * As in CodeQL for other languages, the injection queries use remote sources: a
 * command-line tool that opens the file named by its argument is doing its job, not
 * being attacked. `LocalUserInput` is for queries of your own that treat the local user
 * as untrusted (a setuid program, say).
 *
 * Both classes are extension points: subclass them to add a source, e.g. the request
 * parameters of a web framework not modelled here.
 *
 * All runtime entities are matched by what names resolve to (D-026); without a GNAT
 * runtime at extraction they do not resolve and nothing here matches.
 */

private import ada
private import codeql.ada.dataflow.DataFlow

/** Data received from a remote party: a network peer or an HTTP client. */
abstract class RemoteFlowSource extends DataFlow::Node {
  /** Gets a description of this source, used in query messages ("network data"). */
  abstract string getSourceType();
}

/** Data from the local user: the command line, the environment, standard input. */
abstract class LocalUserInput extends DataFlow::Node {
  /** Gets a description of this source, used in query messages. */
  abstract string getSourceType();
}

/** Holds if `c` calls a subprogram whose qualified name is `name`, ignoring case. */
bindingset[name]
private predicate callsTo(Call c, string name) { c.getTarget().hasQualifiedName(name) }

/**
 * The data a socket receive fills in: the `Item` of `GNAT.Sockets.Receive_Socket`, and
 * the vector of `Receive_Vector`.
 */
private class SocketReceive extends RemoteFlowSource {
  SocketReceive() {
    exists(Call c, Parameter p |
      callsTo(c, "GNAT.Sockets.Receive_Socket") and p.hasName("Item")
      or
      callsTo(c, "GNAT.Sockets.Receive_Vector") and p.hasName("Vector")
    |
      p = c.getTarget().getAParameter() and
      DataFlow::isOutArgument(this, c, p.getIndex())
    )
  }

  override string getSourceType() { result = "network data" }
}

/**
 * A value read from a socket's stream with a stream attribute:
 * `String'Input (Stream (Sock))`.
 */
private class SocketStreamInput extends RemoteFlowSource {
  SocketStreamInput() {
    exists(AttributeRef a, Call stream |
      a.getAttribute().getValue().toLowerCase() = "input" and
      callsTo(stream, "GNAT.Sockets.Stream")
    |
      // `T'Input (S)` parses as a call whose name is the attribute
      exists(CallExpr c | c.getName() = a |
        stream = c.getSuffix().(AssocList).getChild(0).(ParamAssoc).getRExpr() and
        this.asExpr() = c
      )
      or
      stream = a.getArgs().getChild(0).(ParamAssoc).getRExpr() and
      this.asExpr() = a
    )
  }

  override string getSourceType() { result = "network data" }
}

/**
 * Request data in an AWS (Ada Web Server) callback: parameters, headers, the URI and
 * the payload of `AWS.Status.Data`, and `AWS.Parameters.Get`.
 */
private class AwsRequestData extends RemoteFlowSource {
  AwsRequestData() {
    exists(Call c |
      callsTo(c,
        [
          "AWS.Status.Parameter", "AWS.Status.URI", "AWS.Status.Payload",
          "AWS.Status.Binary_Payload", "AWS.Status.Host", "AWS.Status.Referer",
          "AWS.Status.User_Agent", "AWS.Status.Cookie", "AWS.Parameters.Get"
        ])
    |
      this.asExpr() = c
    )
  }

  override string getSourceType() { result = "HTTP request data" }
}

/** A command-line argument: `Ada.Command_Line.Argument`, `GNAT.Command_Line` values. */
private class CommandLineArgument extends LocalUserInput {
  CommandLineArgument() {
    exists(Call c |
      callsTo(c,
        [
          "Ada.Command_Line.Argument", "GNAT.Command_Line.Get_Argument",
          "GNAT.Command_Line.Parameter", "GNAT.Command_Line.Full_Switch"
        ])
    |
      this.asExpr() = c
    )
  }

  override string getSourceType() { result = "a command-line argument" }
}

/** The value of an environment variable. */
private class EnvironmentVariable extends LocalUserInput {
  EnvironmentVariable() {
    exists(Call c | callsTo(c, ["Ada.Environment_Variables.Value", "System.OS_Lib.Getenv"]) |
      this.asExpr() = c
    )
  }

  override string getSourceType() { result = "an environment variable" }
}

/**
 * A line read from standard input: the result of `Ada.Text_IO.Get_Line` without a file
 * argument, or the `Item` it fills in.
 */
private class StandardInputLine extends LocalUserInput {
  StandardInputLine() {
    exists(Call c |
      callsTo(c, ["Ada.Text_IO.Get_Line", "Ada.Strings.Unbounded.Text_IO.Get_Line"]) and
      not exists(Parameter f | f = c.getTarget().getAParameter() and f.hasName("File"))
    |
      this.asExpr() = c and c.getTarget().isFunction()
      or
      exists(Parameter item |
        item = c.getTarget().getAParameter() and
        item.hasName("Item") and
        DataFlow::isOutArgument(this, c, item.getIndex())
      )
    )
  }

  override string getSourceType() { result = "standard input" }
}

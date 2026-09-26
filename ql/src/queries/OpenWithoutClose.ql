/**
 * @name Open without Close
 * @description A call to `Ada.Text_IO.Open`/`Create` after which some control-flow path
 *              can reach the end of the enclosing scope without a matching call to
 *              `Ada.Text_IO.Close`/`Delete` -- a resource (file handle) leak on that path.
 *
 *              This is the worked example for `MissingPairedCall` (see
 *              `docs/query-writing.md` for how to instantiate it for your own
 *              open/close-shaped pair). v1 limitations, documented rather than fixed
 *              here: (1) pairing is by call *kind*, not by which `File_Type` object is
 *              involved -- an unrelated `Close` elsewhere in the same body can suppress
 *              a genuine leak; (2) matching is by fully-qualified dotted name
 *              (`Ada.Text_IO.Open(...)`) -- a call shortened by a `use Ada.Text_IO;`
 *              clause (bare `Open(...)`) is not recognised, since without xref
 *              resolution (the GNAT runtime is normally not part of the analyzed
 *              source set -- see `UnusedWithClause.ql`) there is no way to distinguish
 *              it from an unrelated user-defined `Open`. Uses the `normalPathsOnly`
 *              variant of `MissingPairedCall`: a path that only reaches the exit by
 *              first raising an exception is not reported (see `PairedCalls.qll` for
 *              the `strict` variant, which does report it).
 * @id ada/open-without-close
 * @kind problem
 * @problem.severity warning
 * @tags correctness resource-leak
 */

import ada
import codeql.ada.controlflow.Cfg
import codeql.ada.controlflow.PairedCalls

/**
 * Holds if `call` is a call to `Ada.Text_IO.<op>` (case-insensitively), resolved either
 * via xref (fires only when the GNAT runtime is part of the analyzed source set) or,
 * failing that, by matching the fully-qualified dotted callee name textually.
 */
bindingset[op]
private predicate isTextIoOp(Raw::AdaNode call, string op) {
  exists(Name callee | callee = call.(Raw::CallStmt).getCall().(Raw::CallExpr).getName() |
    exists(Raw::BasicDecl decl, Raw::BasePackageDecl pkg |
      decl = callee.getReferencedDecl() and
      decl.(BasicDecl).getAName().toLowerCase() = op and
      pkg = decl.getParent+() and
      pkg.getPackageName().getName().(Name).getText().toLowerCase() = "text_io"
    )
    or
    exists(string full | full = callee.getText().toLowerCase() |
      full = "text_io." + op or full.matches("%.text_io." + op)
    )
  )
}

private predicate isOpenOrCreate(Raw::AdaNode call) {
  isTextIoOp(call, "open") or isTextIoOp(call, "create")
}

private predicate isCloseOrDelete(Raw::AdaNode call) {
  isTextIoOp(call, "close") or isTextIoOp(call, "delete")
}

module OpenClose = MissingPairedCall<isOpenOrCreate/1, isCloseOrDelete/1>;

from Raw::AdaNode call
where OpenClose::missingPairedCallNormalPathsOnly(call) and
  call.(AdaNode).fromSource()
select call,
  "This file may not be closed on every path: no call to Ada.Text_IO.Close/Delete follows on all non-exceptional paths from here."

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
 *              a genuine leak; (2) calls are recognised by what they resolve to
 *              (D-026), so `use` clauses, package renamings and subprogram renamings
 *              are covered; only when a callee does not resolve (no GNAT runtime at
 *              extraction) is its dotted text matched instead, which misses a bare
 *              `Open(...)` under `use Ada.Text_IO;`. Uses the `normalPathsOnly`
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
 * Holds if `call` is a call to `Ada.Text_IO.<op>` (case-insensitively): semantically,
 * the callee resolves, through any subprogram renamings, to that declaration in the
 * runtime (D-026). Only if the callee does not resolve (no GNAT runtime at
 * extraction) is its dotted text matched instead.
 */
bindingset[op]
private predicate isTextIoOp(AdaNode call, string op) {
  exists(Name callee | callee = call.(CallStmt).getCall().(CallExpr).getName() |
    callee.getReferencedDecl().getUltimateDecl().hasQualifiedName("Ada.Text_IO." + op)
    or
    not exists(callee.getReferencedDecl()) and
    exists(string full | full = callee.getText().toLowerCase() |
      full = "text_io." + op or full.matches("%.text_io." + op)
    )
  )
}

private predicate isOpenOrCreate(AdaNode call) {
  isTextIoOp(call, "open") or isTextIoOp(call, "create")
}

private predicate isCloseOrDelete(AdaNode call) {
  isTextIoOp(call, "close") or isTextIoOp(call, "delete")
}

module OpenClose = MissingPairedCall<isOpenOrCreate/1, isCloseOrDelete/1>;

/** Gets the subprogram body that most closely encloses `n`. */
private BaseSubpBody innermostBody(AdaNode n) {
  result = n.getParent+() and
  not exists(BaseSubpBody inner | inner = n.getParent+() and inner.getParent+() = result)
}

/**
 * Holds if the file `call` opens is held by a parameter (`File : out File_Type`) or
 * by an object declared outside the subprogram the call is in. The file is then
 * opened for someone else, who is responsible for closing it.
 */
private predicate opensNonLocalFile(AdaNode call) {
  exists(Name file, BasicDecl d |
    file =
      call.(CallStmt).getCall().(CallExpr).getSuffix().(AssocList).getChild(0).(ParamAssoc).getRExpr() and
    d = file.getReferencedDecl()
  |
    d instanceof ParamSpec or not d.getParent+() = innermostBody(call)
  )
}

from AdaNode call
where
  OpenClose::missingPairedCallNormalPathsOnly(call) and
  not opensNonLocalFile(call) and
  call.fromSource()
select call,
  "This file may not be closed on every path: no call to Ada.Text_IO.Close/Delete follows on all non-exceptional paths from here."

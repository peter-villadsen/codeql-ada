/**
 * Support for rendering a source file with SSA names made explicit -- a
 * debugging aid for the SSA calculation itself (`SsaImpl.qll`), not a
 * conformance check: each write and each read of a tracked variable is
 * shown with a subscripted version number (`X_1`, `X_2`, ...), unique per
 * `(scope, variable)` in program order, and each phi node is rendered as an
 * inserted comment at the position `SsaAnnotations.qll` already anchors its
 * edges at.
 *
 * Consumed by `ql/debug/PrintSsaRenamed.ql`, which turns this into a flat
 * edit list, and `scripts/render_ssa.py`, which applies that list to a copy
 * of the source. See `docs/ssa-design.md`, "Renamed-source rendering", for
 * the worked example and the two anchoring traps this design avoids by
 * reusing `getWriteNameOccurrence` rather than re-deriving it.
 */

import codeql.ada.controlflow.Cfg
import codeql.ada.controlflow.BasicBlocks
private import codeql.ada.ast.internal.Raw
private import ada
private import codeql.ada.dataflow.internal.SsaImpl

/**
 * Gets `(bb, i)` for `astNode`'s control-flow node, reconstructed from the
 * public `Cfg`/`BasicBlocks` API alone (the same relationship `SsaImpl.qll`'s
 * own private `cfgPos` expresses, but that predicate cannot be reused from
 * outside its file).
 */
private predicate cfgPos(Raw::AdaNode astNode, BasicBlock bb, int i) {
  exists(CfgNode n | n.getAstNode() = astNode | bb.getNode(i) = n)
}

/**
 * Gets the position to sort `d` by, for numbering purposes: a write's own
 * name position (`getWriteNameOccurrence` -- always a genuine single-token
 * reference or declaration, never a multi-line span); a phi's own *end*
 * position, matching where its comment is rendered (`phiCommentLine`) --
 * genuinely where it happens in program order, after every branch it merges.
 */
private predicate sortPos(SsaImpl::Definition d, int line, int col) {
  exists(Raw::AdaNode n |
    n = getWriteNameOccurrence(d.(SsaImpl::WriteDefinition)) and
    n.getLocation().hasLocationInfo(_, line, col, _, _)
  )
  or
  d instanceof SsaImpl::PhiNode and d.getLocation().hasLocationInfo(_, _, _, line, col)
}

/**
 * Gets the 1-based SSA version number to print for `d`, counting how many
 * other definitions of the same `(scope, variable)` sort earlier (`count`,
 * not `strictcount` -- Task 9.2.3's own lesson: the first definition's count
 * of predecessors is legitimately zero, an empty range).
 */
int ssaVersion(SsaImpl::Definition d) {
  exists(SsaSourceVariable v, int line, int col |
    v = d.getSourceVariable() and
    sortPos(d, line, col) and
    result =
      1 +
        count(SsaImpl::Definition other, int l2, int c2 |
          other.getBasicBlock().getScope() = d.getBasicBlock().getScope() and
          other.getSourceVariable() = v and
          sortPos(other, l2, c2) and
          (l2 < line or l2 = line and c2 < col)
        )
  )
}

/** Gets the rendered SSA name for `d`: its variable's own text plus its version, e.g. `X_2`. */
string ssaName(SsaImpl::Definition d) { result = d.getSourceVariable().toString() + "_" + ssaVersion(d) }

/**
 * Gets the substitution that prints `wd`'s SSA name at its own write
 * occurrence (`getWriteNameOccurrence`, not `wd`'s CFG anchor -- see that
 * predicate's doc for why the two differ).
 *
 * Excludes an `UncertainWriteDefinition` (an `out`/`in out` actual, D-022):
 * its name occurrence *is* the actual argument reference, which is also a
 * genuine read of the pre-call value at the exact same span -- the two
 * cannot both be shown by substitution at one position, so the read wins
 * there and the write-back is described as a comment instead
 * (`writeBackComment`).
 */
predicate writeEdit(string file, int line, int startCol, int endCol, string replacement) {
  exists(Raw::AdaNode n, SsaImpl::WriteDefinition wd |
    n = getWriteNameOccurrence(wd) and
    not wd instanceof SsaImpl::UncertainWriteDefinition and
    n.getLocation().hasLocationInfo(file, line, startCol, line, endCol) and
    replacement = ssaName(wd)
  )
}

/**
 * Holds if `n` is a named association's designator (`X` in `Foo (X => Y)`),
 * mirroring `SsaImpl.qll`'s own `isDesignator` (private to that file, so
 * re-derived here rather than reused) -- see that predicate's doc for why a
 * designator is excluded from reads despite `ada_xref` resolving it.
 */
private predicate isDesignator(Name n) { n = any(Raw::ParamAssoc pa).getDesignator() }

/**
 * Gets the substitution that prints the reaching definition's SSA name at
 * read `n` -- or `<var>_UNDEF` if no definition reaches it (reading a
 * variable before any write; a real bug in the analysed Ada, or a sign SSA
 * missed a write -- worth rendering distinctly either way, not silently). A
 * write's own target (`Y` in `Y := ...`) and a named association's
 * designator are excluded, matching `variableRead`'s own rules exactly (see
 * `isDesignator`'s doc for why the latter is not simply "any reference").
 */
predicate readEdit(string file, int line, int startCol, int endCol, string replacement) {
  exists(Name n, SsaSourceVariable v, BasicBlock bb, int i |
    v = getSourceVariable(n) and
    not n = any(Raw::AssignStmt s).getDest() and
    not isDesignator(n) and
    cfgPos(n, bb, i) and
    n.getLocation().hasLocationInfo(file, line, startCol, line, endCol)
  |
    exists(SsaImpl::Definition def | SsaImpl::ssaDefReachesRead(v, def, bb, i) | replacement = ssaName(def))
    or
    not exists(SsaImpl::Definition def | SsaImpl::ssaDefReachesRead(v, def, bb, i)) and
    replacement = v.toString() + "_UNDEF"
  )
}

/**
 * Gets the file/line to anchor a phi's comment on: the enclosing construct's
 * *end* position -- the same anchor `SsaAnnotations.qll`'s conformance tests
 * use for a phi's `reads` edges (Task 9.2.4's anchoring trap: a phi's
 * location is the whole branching construct's span, because it comes from
 * `bb.getLocation()`).
 */
private predicate phiCommentLine(SsaImpl::PhiNode phi, string file, int line) {
  phi.getLocation().hasLocationInfo(file, _, _, line, _)
}

/** Gets the comment text for phi `phi`: `X_3 = phi(X_1, X_2)`, inputs in version order. */
private string phiComment(SsaImpl::PhiNode phi) {
  result =
    ssaName(phi) + " = phi(" +
      strictconcat(SsaImpl::Definition inp |
        SsaImpl::phiHasInputFromBlock(phi, inp, _)
      |
        ssaName(inp), ", " order by ssaVersion(inp)
      ) + ")"
}

/**
 * Gets the file/line to anchor an uncertain write-back's comment on: its own
 * CFG anchor (the call's effect node -- see `writeEdit`'s doc for why this
 * one, alone among write kinds, is a comment rather than a substitution).
 */
private predicate writeBackCommentLine(SsaImpl::UncertainWriteDefinition wd, string file, int line) {
  wd.getLocation().hasLocationInfo(file, _, _, line, _)
}

/** Gets the comment text for uncertain write-back `wd`: `write-back: X_2`. */
private string writeBackComment(SsaImpl::UncertainWriteDefinition wd) {
  result = "write-back: " + ssaName(wd)
}

/** Gets the (possibly several phis'/write-backs') comment to append at `file`:`line`. */
predicate commentEdit(string file, int line, string text) {
  text =
    strictconcat(string one |
      one = any(SsaImpl::PhiNode phi | phiCommentLine(phi, file, line) | phiComment(phi))
      or
      one =
        any(SsaImpl::UncertainWriteDefinition wd |
          writeBackCommentLine(wd, file, line)
        |
          writeBackComment(wd)
        )
    |
      one, "; " order by one
    )
}

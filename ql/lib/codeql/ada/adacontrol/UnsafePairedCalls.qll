/**
 * AdaControl rule `Unsafe_Paired_Calls`: calls of paired procedures (a lock and its
 * unlock, `P` and `V` on a semaphore) that are not in the safe pattern
 * (`docs/adacontrol.md`).
 *
 * The pairs are named with the data extension `pairedCalls(opening, closing,
 * lockType)`. In the safe pattern:
 * - the opening call is the first statement of a handled sequence of statements (of a
 *   body, a block or an `accept`);
 * - the closing call is its last statement, but for trailing `exit`, `return` and
 *   `null` statements;
 * - a `return`, `exit` or `goto` that leaves the sequence follows a closing call;
 * - the sequence has a `when others` handler, and every handler has a closing call;
 * - the sequence calls neither procedure elsewhere, outside nested sequences.
 *
 * With a lock type, each procedure has a parameter of that type, and the calls match
 * when they pass the same variable or the same value. Calls wrapped in an `if` on a
 * constant (AdaControl's `Conditionals_Allowed`) are not recognised: the opening call
 * must be a call statement. Renamings are followed (`Name_As_Given` off).
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Calls
private import codeql.ada.Subprograms
private import codeql.ada.Declarations
private import codeql.ada.adacontrol.Settings

module UnsafePairedCalls {
  /** Holds if `opening` and `closing` are paired, with lock type `lockType` (empty for none). */
  predicate isPair(Subprogram opening, Subprogram closing, string lockType) {
    exists(string o, string c |
      pairedCalls(o, c, lockType) and opening.hasQualifiedName(o) and closing.hasQualifiedName(c)
    )
  }

  /** Holds if call statement `s` calls `p`. */
  private predicate calls(Raw::CallStmt s, Subprogram p) { s.getCall().(Call).getTarget() = p }

  /** Holds if `s` calls the opening procedure of the pair (`opening`, `closing`, `lockType`). */
  predicate isOpening(Raw::CallStmt s, Subprogram opening, Subprogram closing, string lockType) {
    isPair(opening, closing, lockType) and calls(s, opening)
  }

  /** Holds if `s` calls the closing procedure of the pair (`opening`, `closing`, `lockType`). */
  predicate isClosing(Raw::CallStmt s, Subprogram opening, Subprogram closing, string lockType) {
    isPair(opening, closing, lockType) and calls(s, closing)
  }

  /** Gets the lock call statement `s` passes: its actual for a parameter of type `lockType`. */
  bindingset[lockType]
  Raw::Expr lock(Raw::CallStmt s, string lockType) {
    exists(Call c, Parameter p | c = s.getCall() and result = c.getArgumentFor(p) |
      p.getType().getParentType*().hasQualifiedName(lockType)
    )
  }

  /**
   * Gets a key for lock `e`: its text, with the declaration it names (one declaration
   * may declare several objects, `A, B : Semaphore`, so the text tells them apart).
   */
  private string lockKey(Raw::Expr e) {
    exists(string text | text = e.(Raw::Name).getText().toLowerCase() |
      result = e.(Raw::Name).getReferencedDecl().getQualifiedName().toLowerCase() + "/" + text
      or
      not exists(e.(Raw::Name).getReferencedDecl()) and result = text
    )
  }

  /** Holds if opening call `o` and closing call `c` match: same pair, and the same lock if there is a lock type. */
  predicate matching(Raw::CallStmt o, Raw::CallStmt c) {
    exists(Subprogram op, Subprogram cl, string lockType |
      isOpening(o, op, cl, lockType) and
      isClosing(c, op, cl, lockType) and
      (lockType = "" or lockKey(lock(o, lockType)) = lockKey(lock(c, lockType)))
    )
  }

  /** Gets the `i`th statement of handled sequence `hs`. */
  private Raw::AdaNode stmt(Raw::HandledStmts hs, int i) { result = hs.getStmts().getChild(i) }

  /** Holds if `s` may end a sequence after its closing call: `exit`, `return` or `null`. */
  private predicate isTrailing(Raw::AdaNode s) {
    s instanceof Raw::ExitStmt or s instanceof Raw::ReturnStmt or s instanceof Raw::NullStmt
  }

  /** Gets the last statement of `hs` that is not trailing. */
  Raw::AdaNode lastStatement(Raw::HandledStmts hs) {
    exists(int i | result = stmt(hs, i) and not isTrailing(result) |
      not exists(int j, Raw::AdaNode later | later = stmt(hs, j) and j > i and not isTrailing(later))
    )
  }

  /** Gets a handler of `hs`. */
  private Raw::ExceptionHandler handler(Raw::HandledStmts hs) { result = hs.getExceptions().getChild(_) }

  /** Holds if `n` is in the statements of `hs`, not in a sequence nested in them. */
  private predicate directlyIn(Raw::AdaNode n, Raw::HandledStmts hs) {
    n.getParent+() = hs.getStmts() and
    not exists(Raw::HandledStmts inner | n.getParent+() = inner and inner.getParent+() = hs)
  }

  /** Holds if `r`, in `hs`, leaves it: a `return`, a `goto`, or an `exit` of a loop around `hs`. */
  private predicate leaves(Raw::AdaNode r, Raw::HandledStmts hs) {
    directlyIn(r, hs) and
    (
      r instanceof Raw::ReturnStmt or
      r instanceof Raw::GotoStmt or
      r instanceof Raw::ExitStmt and
      not exists(Raw::BaseLoopStmt l | r.getParent+() = l and l.getParent+() = hs)
    )
  }

  /** Gets the statement before `s` in its list. */
  private Raw::AdaNode previous(Raw::AdaNode s) {
    exists(Raw::AdaNode list, int i | s = list.getChild(i) and result = list.getChild(i - 1))
  }

  /** Holds if closing call `c` closes for opening call `o`, first statement of `hs`, in the safe pattern. */
  predicate closesSafely(Raw::CallStmt o, Raw::HandledStmts hs, Raw::CallStmt c) {
    o = stmt(hs, 0) and
    matching(o, c) and
    (
      c = lastStatement(hs)
      or
      c = handler(hs).getStmts().getChild(_)
      or
      exists(Raw::AdaNode r | leaves(r, hs) and c = previous(r))
    )
  }

  /** Holds if opening call `o` is not in the safe pattern, for `reason`. */
  predicate unsafeOpening(Raw::CallStmt o, string reason) {
    isOpening(o, _, _, _) and
    (
      not o = stmt(_, 0) and reason = "is not the first statement of a sequence"
      or
      exists(Raw::HandledStmts hs | o = stmt(hs, 0) |
        not matching(o, lastStatement(hs)) and
        reason = "is not closed by the last statement of its sequence"
        or
        not exists(Raw::ExceptionHandler h | h = handler(hs) |
          h.getHandledExceptions().getChild(_) instanceof Raw::OthersDesignator
        ) and
        reason = "has no 'when others' handler in its sequence"
        or
        exists(Raw::ExceptionHandler h | h = handler(hs) |
          not matching(o, h.getStmts().getChild(_))
        ) and
        reason = "has a handler that does not close"
        or
        exists(Raw::AdaNode r | leaves(r, hs) and not matching(o, previous(r))) and
        reason = "has a return, exit or goto that leaves without closing"
        or
        exists(Raw::CallStmt other |
          directlyIn(other, hs) and
          other != o and
          (
            exists(Subprogram op, Subprogram cl, string lt | isOpening(o, op, cl, lt) |
              isOpening(other, op, cl, lt) or isClosing(other, op, cl, lt)
            )
          ) and
          not closesSafely(o, hs, other)
        ) and
        reason = "has another call of the pair in its sequence"
      )
    )
  }

  /** Holds if closing call `c` is not in the safe pattern of any opening call. */
  predicate unsafeClosing(Raw::CallStmt c) {
    isClosing(c, _, _, _) and
    not closesSafely(_, _, c)
  }
}

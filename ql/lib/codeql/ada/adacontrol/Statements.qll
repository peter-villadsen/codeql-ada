/**
 * AdaControl rule `Statements`: uses of given kinds of statements. `statement(s, kw)`
 * holds for each AdaControl `<subrule>` that applies to `s` (`docs/adacontrol.md` lists
 * the keywords implemented).
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Calls

module Statements {
  /** Holds if `s` has a name (`Outer : loop`, `Work : declare`). */
  private predicate isNamed(Raw::Stmt s) { s.getParent() instanceof Raw::NamedStmt }

  /** Gets the loop exit statement `e` leaves: the named loop, or the innermost one. */
  Raw::BaseLoopStmt exitedLoop(Raw::ExitStmt e) {
    exists(Raw::NamedStmtDecl d | d = e.getLoopName().getReferencedDecl() |
      result = d.getParent().(Raw::NamedStmt).getStmt()
    )
    or
    not exists(e.getLoopName()) and
    result = e.getParent+() and
    not exists(Raw::BaseLoopStmt inner | inner = e.getParent+() and inner.getParent+() = result)
  }

  /** Gets the innermost loop around `s`. */
  private Raw::BaseLoopStmt innermostLoop(Raw::AdaNode s) {
    result = s.getParent+() and
    not exists(Raw::BaseLoopStmt inner | inner = s.getParent+() and inner.getParent+() = result)
  }

  /** Holds if `list` holds only `null` statements (pragmas and labels aside). */
  private predicate onlyNull(Raw::StmtList list) {
    exists(Raw::NullStmt n | n = list.getChild(_)) and
    not exists(Raw::AdaNode s | s = list.getChild(_) |
      not s instanceof Raw::NullStmt and
      not s instanceof Raw::Label and
      not s instanceof Raw::PragmaNode
    )
  }

  /** Gets the label statement goto `g` jumps to. */
  Raw::Label target(Raw::GotoStmt g) {
    result.getDecl() = g.getLabelName().getReferencedDecl()
  }

  /** Gets the body (subprogram, entry, accept) a return statement `r` returns from. */
  private Raw::AdaNode returnedFrom(Raw::Stmt r) {
    result = r.getParent+() and
    (result instanceof Raw::SubpBody or result instanceof Raw::EntryBody or result instanceof Raw::AcceptStmtWithStmts) and
    not exists(Raw::AdaNode inner |
      inner = r.getParent+() and
      (inner instanceof Raw::SubpBody or inner instanceof Raw::EntryBody or inner instanceof Raw::AcceptStmtWithStmts) and
      inner.getParent+() = result
    )
  }

  /** Gets the exception `raise` statement or `Raise_Exception` call `s` raises, if it resolves. */
  Raw::BasicDecl raised(Raw::Stmt s) {
    result = s.(Raw::RaiseStmt).getExceptionName().(Raw::Name).getReferencedDecl().getUltimateDecl()
    or
    exists(Call c | c = s.(Raw::CallStmt).getCall() and c.getTarget().hasQualifiedName("Ada.Exceptions.Raise_Exception") |
      result = c.getArgument(0).(Raw::AttributeRef).getPrefix().getReferencedDecl().getUltimateDecl()
    )
  }

  /** Holds if `s` is of a kind AdaControl's `Statements` names `kw`. */
  predicate statement(Raw::Stmt s, string kw) {
    kw = "any_statement" and not s instanceof Raw::NamedStmt and not s instanceof Raw::Label
    or
    s instanceof Raw::AbortStmt and kw = "abort"
    or
    s instanceof Raw::AcceptStmt and kw = "accept"
    or
    s instanceof Raw::AssignStmt and kw = "assignment"
    or
    s instanceof Raw::IfStmt and kw = "if"
    or
    exists(s.(Raw::IfStmt).getAlternatives().getChild(_)) and kw = "if_elsif"
    or
    s instanceof Raw::IfStmt and not exists(s.(Raw::IfStmt).getElsePart()) and kw = "no_else"
    or
    s instanceof Raw::CaseStmt and kw = "case"
    or
    exists(Raw::CaseStmtAlternative a |
      a = s.(Raw::CaseStmt).getAlternatives().getChild(_) and
      a.getChoices().getChild(_) instanceof Raw::OthersDesignator
    |
      kw = "case_others"
      or
      onlyNull(a.getStmts()) and kw = "case_others_null"
    )
    or
    exists(Raw::CaseStmtAlternative a | a = s.(Raw::CaseStmt).getAlternatives().getChild(_) |
      onlyNull(a.getStmts())
    ) and
    kw = "null_case_path"
    or
    exists(Raw::IfStmt i | i = s |
      onlyNull([i.getThenStmts(), i.getElsePart().getStmts(), i.getAlternatives().getChild(_).(Raw::ElsifStmtPart).getStmts()])
    ) and
    kw = "null_if_path"
    or
    s instanceof Raw::NullStmt and kw = "null"
    or
    // blocks
    s instanceof Raw::BlockStmt and kw = "block"
    or
    s instanceof Raw::BlockStmt and not isNamed(s) and kw = "unnamed_block"
    or
    s instanceof Raw::DeclBlock and kw = "declare_block"
    or
    exists(Raw::AdaNode d |
      d = s.(Raw::DeclBlock).getDecls().getDecls().getChild(_) and
      not d instanceof Raw::UseClause and
      not d instanceof Raw::PragmaNode
    ) and
    kw = "effective_declare_block"
    or
    exists(Raw::HandledStmts hs | hs = [s.(Raw::BeginBlock).getStmts(), s.(Raw::DeclBlock).getStmts()] |
      not exists(hs.getExceptions().getChild(_)) and
      not exists(Raw::AdaNode d | d = s.(Raw::DeclBlock).getDecls().getDecls().getChild(_)) and
      (
        kw = "simple_block"
        or
        not isNamed(s) and kw = "unnamed_simple_block"
      )
    )
    or
    // loops
    s instanceof Raw::LoopStmt and kw = "simple_loop"
    or
    s instanceof Raw::WhileLoopStmt and kw = "while_loop"
    or
    s instanceof Raw::ForLoopStmt and kw = "for_loop"
    or
    exists(Raw::ForLoopSpec spec | spec = s.(Raw::ForLoopStmt).getSpec() |
      spec.getLoopType() instanceof Raw::IterTypeIn and
      // a range, `X'Range` or a subtype: the traditional form; else an iterator
      if
        spec.getIterExpr().(Raw::BinOp).getOp() instanceof Raw::OpDoubleDot or
        spec.getIterExpr().(Raw::AttributeRef).getAttribute().getValue().toLowerCase() = "range" or
        spec.getIterExpr().(Raw::Name).getReferencedDecl() instanceof Raw::BaseTypeDecl or
        spec.getIterExpr() instanceof Raw::SubtypeIndication
      then kw = "for_in_loop"
      else kw = "for_iterator_loop"
      or
      spec.getLoopType() instanceof Raw::IterTypeOf and kw = "for_of_loop"
      or
      // a range without a named type: `for I in 1 .. 10`
      spec.getLoopType() instanceof Raw::IterTypeIn and
      spec.getIterExpr().(Raw::BinOp).getOp() instanceof Raw::OpDoubleDot and
      kw = ["untyped_for", "untyped_for_in"]
      or
      spec.getLoopType() instanceof Raw::IterTypeOf and
      not exists(spec.getVarDecl().getIdType()) and
      kw = ["untyped_for", "untyped_for_of"]
    )
    or
    s instanceof Raw::LoopStmt and not isNamed(s) and kw = "unnamed_simple_loop"
    or
    s instanceof Raw::WhileLoopStmt and not isNamed(s) and kw = "unnamed_while_loop"
    or
    s instanceof Raw::ForLoopStmt and not isNamed(s) and kw = "unnamed_for_loop"
    or
    s instanceof Raw::BaseLoopStmt and
    not isNamed(s) and
    (exists(innermostLoop(s)) or exists(Raw::BaseLoopStmt inner | inner.getParent+() = s)) and
    kw = "unnamed_multiple_loop"
    or
    onlyNull(s.(Raw::BaseLoopStmt).getStmts()) and kw = "null_loop_body"
    or
    count(Raw::ExitStmt e | exitedLoop(e) = s) > 1 and kw = "multiple_exits"
    or
    // exits
    exists(Raw::ExitStmt e, Raw::BaseLoopStmt l | e = s and l = exitedLoop(e) |
      kw = "exit"
      or
      l instanceof Raw::ForLoopStmt and kw = "exit_for_loop"
      or
      l instanceof Raw::WhileLoopStmt and kw = "exit_while_loop"
      or
      l instanceof Raw::LoopStmt and kw = "exit_plain_loop"
      or
      not exists(e.getCondExpr()) and kw = "unconditional_exit"
      or
      not isNamed(l) and kw = "unnamed_loop_exited"
      or
      l != innermostLoop(e) and kw = "exit_outer_loop"
      or
      exists(e.getLoopName()) and kw = "named_exit"
      or
      e.getLoopName() instanceof Raw::DottedName and kw = "exit_expanded_name"
      or
      not exists(e.getLoopName()) and isNamed(l) and kw = "unnamed_exit"
    )
    or
    // gotos and labels
    s instanceof Raw::GotoStmt and kw = "goto"
    or
    exists(Raw::GotoStmt g, Raw::Label l | g = s and l = target(g) |
      l.getLocation().getStartLine() < g.getLocation().getStartLine() and kw = "backward_goto"
      or
      // the goto of a `continue`: to a label on a `null;` that ends a loop body
      not exists(Raw::NullStmt n, Raw::StmtList body, int i |
        body = any(Raw::BaseLoopStmt loop).getStmts() and
        l = body.getChild(i) and
        n = body.getChild(i + 1) and
        not exists(body.getChild(i + 2))
      ) and
      kw = "goto_not_continue"
    )
    or
    s instanceof Raw::Label and kw = "labelled"
    or
    // returns
    s instanceof Raw::ExtendedReturnStmt and kw = "extended_return"
    or
    exists(Raw::AdaNode body | body = returnedFrom(s) and (s instanceof Raw::ReturnStmt or s instanceof Raw::ExtendedReturnStmt) |
      body instanceof Raw::AcceptStmtWithStmts and kw = "accept_return"
      or
      body instanceof Raw::EntryBody and kw = "entry_return"
      or
      body.(Raw::SubpBody).getSubpSpec().getSubpKind() instanceof Raw::SubpKindProcedure and
      kw = "procedure_return"
      or
      body.(Raw::SubpBody).getSubpSpec().getSubpKind() instanceof Raw::SubpKindFunction and
      count(Raw::Stmt r |
        returnedFrom(r) = body and
        (r instanceof Raw::ReturnStmt or r instanceof Raw::ExtendedReturnStmt) and
        not r.getParent+() instanceof Raw::ExceptionHandler
      ) > 1 and
      not s.getParent+() instanceof Raw::ExceptionHandler and
      kw = "function_return"
      or
      exists(innermostLoop(s)) and innermostLoop(s).getParent+() = body and kw = "loop_return"
    )
    or
    // raises
    s instanceof Raw::RaiseStmt and kw = "raise"
    or
    s instanceof Raw::RaiseStmt and
    not exists(s.(Raw::RaiseStmt).getExceptionName()) and
    kw = "reraise"
    or
    s.(Raw::CallStmt).getCall().(Call).getTarget().hasQualifiedName("Ada.Exceptions.Reraise_Occurrence") and
    kw = "reraise"
    or
    exists(Raw::BasicDecl e | e = raised(s) |
      e.hasQualifiedName([
          "Standard.Constraint_Error", "Standard.Program_Error", "Standard.Storage_Error",
          "Standard.Tasking_Error", "Standard.Numeric_Error"
        ]) and
      kw = "raise_standard"
      or
      not e.getQualifiedName().matches("Standard.%") and
      not e.getParent().getParent() instanceof Raw::PublicPart and
      kw = "raise_nonpublic"
      or
      // handled by a handler of the same subprogram body
      exists(Raw::ExceptionHandler h, Raw::BaseSubpBody body |
        body = s.getEnclosingSubprogram().getBody() and
        h.getParent+() = body and
        s.getParent+() = h.getParent().getParent().(Raw::HandledStmts).getStmts() and
        h.getHandledExceptions().getChild(_).(Raw::Name).getReferencedDecl().getUltimateDecl() = e
      ) and
      kw = "raise_locally_handled"
    )
    or
    s instanceof Raw::RequeueStmt and kw = "requeue"
    or
    // calls
    s.(Raw::CallStmt).getCall() instanceof Call and kw = "procedure_call"
    or
    exists(Raw::Name callee | callee = [s.(Raw::CallStmt).getCall(), s.(Raw::CallStmt).getCall().(Raw::CallExpr).getName()] |
      callee instanceof Raw::ExplicitDeref
    ) and
    kw = "dynamic_procedure_call"
    or
    exists(Raw::Name callee |
      callee = [s.(Raw::CallStmt).getCall(), s.(Raw::CallStmt).getCall().(Raw::CallExpr).getName()]
    |
      callee.getReferencedDecl() instanceof Raw::EntryDecl or
      callee.(Raw::DottedName).getSuffix().getReferencedDecl() instanceof Raw::EntryDecl
    ) and
    kw = "entry_call"
    or
    // delays and selects
    s instanceof Raw::DelayStmt and not s.(Raw::DelayStmt).getHasUntil() instanceof Raw::UntilPresent and
    kw = "delay"
    or
    s.(Raw::DelayStmt).getHasUntil() instanceof Raw::UntilPresent and kw = "delay_until"
    or
    s instanceof Raw::TerminateAlternative and kw = "terminate"
    or
    exists(Raw::SelectStmt sel | sel = s |
      exists(sel.getThenAbortPart()) and kw = "asynchronous_select"
      or
      not exists(sel.getThenAbortPart()) and
      exists(Raw::Stmt first | first = sel.getGuards().getChild(0).(Raw::SelectWhenPart).getStmts().getChild(0) |
        if first instanceof Raw::AcceptStmt
        then kw = "selective_accept"
        else
          if exists(sel.getElsePart())
          then kw = "conditional_entry_call"
          else kw = "timed_entry_call"
      )
    )
  }

  /** `exception_others` and `exception_others_null`: `when others` handlers, and those with only `null`. */
  predicate othersHandler(Raw::ExceptionHandler h, string kw) {
    h.getHandledExceptions().getChild(_) instanceof Raw::OthersDesignator and
    (
      kw = "exception_others"
      or
      onlyNull(h.getStmts()) and kw = "exception_others_null"
    )
  }
}

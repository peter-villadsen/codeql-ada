/**
 * AdaControl rule `Comments`: comments that must, or must not, appear
 * (`docs/adacontrol.md`).
 *
 * Comments are not AST nodes; they are matched with code by file and line.
 */

private import codeql.ada.ast.internal.Raw

module Comments {
  /** Gets the "useful" part of comment `c`: the text after `--` and the spaces after it. */
  string usefulText(Raw::Comment c) { result = c.getText().regexpCapture("--\\s*(.*?)\\s*", 1) }

  /** Holds if `c` is on line `line` of the file at `path`, starting at column `col`. */
  predicate commentAt(Raw::Comment c, string path, int line, int col) {
    c.getLocation().hasLocationInfo(path, line, col, _, _)
  }

  /** `pattern`: the useful part of `c` matches regular expression `pattern`, ignoring case. */
  bindingset[pattern]
  predicate matchesPattern(Raw::Comment c, string pattern) {
    exists(usefulText(c).regexpFind("(?i)" + pattern, _, _))
  }

  /** `position`: comment `c` starts at column `col`. */
  int column(Raw::Comment c) { commentAt(c, _, _, result) }

  /** Holds if a node starts or ends on line `line` of `path` before column `col`. */
  private predicate codeBefore(string path, int line, int col) {
    exists(Raw::Comment c | commentAt(c, path, line, col)) and
    exists(Raw::AdaNode n, int sl, int sc, int el, int ec |
      n.getLocation().hasLocationInfo(path, sl, sc, el, ec)
    |
      sl = line and sc < col
      or
      el = line and ec < col
    )
  }

  /**
   * Holds if `line` of `path` is where a sequence of statements begins (the `begin`
   * line: a handled sequence of statements starts just after `begin`), and no statement
   * or declaration starts on it before column `col`.
   */
  private predicate onlyBeginBefore(string path, int line, int col) {
    exists(Raw::HandledStmts hs | hs.getLocation().hasLocationInfo(path, line, _, _, _)) and
    exists(Raw::Comment c | commentAt(c, path, line, col)) and
    not exists(Raw::AdaNode n, int sc |
      (n instanceof Raw::Stmt or n instanceof Raw::BasicDecl) and
      n.getLocation().hasLocationInfo(path, line, sc, _, _) and
      sc < col
    )
  }

  /**
   * `terminating`: comment `c` is at the end of a line that holds code. With
   * `allowBegin`, not when the line holds only a `begin`.
   */
  predicate isTerminating(Raw::Comment c, boolean allowBegin) {
    exists(string path, int line, int col |
      commentAt(c, path, line, col) and
      codeBefore(path, line, col)
    |
      allowBegin = false
      or
      allowBegin = true and not onlyBeginBefore(path, line, col)
    )
  }

  /** Gets the kind of unit `body` is, as AdaControl names it, if it has a `begin`. */
  string unitKind(Raw::BodyNode body) {
    body.(Raw::SubpBody).getSubpSpec().getSubpKind() instanceof Raw::SubpKindProcedure and
    result = "procedure"
    or
    body.(Raw::SubpBody).getSubpSpec().getSubpKind() instanceof Raw::SubpKindFunction and
    result = "function"
    or
    body instanceof Raw::EntryBody and result = "entry"
    or
    body instanceof Raw::PackageBody and exists(body.(Raw::PackageBody).getStmts()) and
    result = "package"
    or
    body instanceof Raw::TaskBody and result = "task"
  }

  /** Gets the statements after the `begin` of `body`. */
  Raw::HandledStmts beginPart(Raw::BodyNode body) {
    result = [
        body.(Raw::SubpBody).getStmts(), body.(Raw::EntryBody).getStmts(),
        body.(Raw::PackageBody).getStmts(), body.(Raw::TaskBody).getStmts()
      ]
  }

  /** Gets the declarations of `body` before its `begin`. */
  private Raw::AdaNode aDeclaration(Raw::BodyNode body) {
    result =
      [
        body.(Raw::SubpBody).getDecls(), body.(Raw::EntryBody).getDecls(),
        body.(Raw::PackageBody).getDecls(), body.(Raw::TaskBody).getDecls()
      ].getDecls().getChild(_) and
    not result instanceof Raw::PragmaNode
  }

  /** Holds if `d` is the declaration of a program unit: a subprogram, package, task or protected object. */
  private predicate isProgramUnit(Raw::AdaNode d) {
    d instanceof Raw::BasicSubpDecl or
    d instanceof Raw::BaseSubpBody or
    d instanceof Raw::BasePackageDecl or
    d instanceof Raw::PackageBody or
    d instanceof Raw::GenericDecl or
    d instanceof Raw::TaskTypeDecl or
    d instanceof Raw::SingleTaskDecl or
    d instanceof Raw::TaskBody or
    d instanceof Raw::ProtectedTypeDecl or
    d instanceof Raw::SingleProtectedDecl or
    d instanceof Raw::ProtectedBody or
    d instanceof Raw::BodyStub
  }

  /**
   * Holds if the comment of `body`'s `begin` is required under `condition`: `always`;
   * `declaration`, when it declares something (pragmas aside); `program_unit`, when it
   * declares a program unit.
   */
  bindingset[condition]
  predicate beginCommentRequired(Raw::BodyNode body, string condition) {
    exists(beginPart(body)) and
    (
      condition = "always"
      or
      condition = "declaration" and exists(aDeclaration(body))
      or
      condition = "program_unit" and isProgramUnit(aDeclaration(body))
    )
  }

  /** Gets the simple name of unit `body` (`B` for `package body A.B`). */
  string unitName(Raw::BodyNode body) {
    result = body.getADefiningName().getName().getText().regexpCapture("(?:.*\\.)?([^.]+)", 1)
  }

  /** Holds if the first word of comment `c` names `name` (ignoring case). */
  bindingset[name]
  private predicate namesFirst(Raw::Comment c, string name) {
    usefulText(c).regexpCapture("([^ ,]*).*", 1).toLowerCase() = name.toLowerCase()
  }

  /** Gets the comment on the line where `hs` begins, if any. */
  private Raw::Comment beginComment(Raw::HandledStmts hs) {
    exists(string path, int line |
      hs.getLocation().hasLocationInfo(path, line, _, _, _) and
      commentAt(result, path, line, _)
    )
  }

  /**
   * `unnamed_begin`: the `begin` of `body` has no comment whose first word is the unit's
   * name, and the comment is required under `condition` with a statement part of at
   * least `minLines` lines; or it has a comment naming something else.
   */
  bindingset[condition, minLines]
  predicate isUnnamedBegin(Raw::BodyNode body, string condition, int minLines) {
    exists(Raw::HandledStmts hs | hs = beginPart(body) |
      not namesFirst(beginComment(hs), unitName(body)) and
      (
        exists(beginComment(hs))
        or
        beginCommentRequired(body, condition) and
        hs.getLocation().getEndLine() - hs.getLocation().getStartLine() + 1 >= minLines
      )
    )
  }

  /** Gets the `record ... end record` of record type `t`, unless it is `null record`. */
  Raw::RecordDef recordDef(Raw::TypeDecl t) {
    result = t.getTypeDef().(Raw::RecordTypeDef).getRecordDef()
    or
    result = t.getTypeDef().(Raw::DerivedTypeDef).getRecordExtension()
  }

  /** Gets the number of lines of the declaration of `t`. */
  int lineCount(Raw::AdaNode t) {
    result = t.getLocation().getEndLine() - t.getLocation().getStartLine() + 1
  }

  /**
   * `unnamed_end_record`: the `end record` of record type `t` has no comment whose first
   * word is the type's name, and its declaration is longer than `maxLines` lines (all of
   * them for 0); or it has a comment naming something else.
   */
  bindingset[maxLines]
  predicate isUnnamedEndRecord(Raw::TypeDecl t, int maxLines) {
    exists(Raw::RecordDef r, string path, int line, string name |
      r = recordDef(t) and
      r.getLocation().hasLocationInfo(path, _, _, line, _) and
      name = t.getName().getName().getText()
    |
      exists(Raw::Comment c | commentAt(c, path, line, _) and not namesFirst(c, name))
      or
      not exists(Raw::Comment c | commentAt(c, path, line, _)) and
      (maxLines = 0 or lineCount(t) > maxLines)
    )
  }
}

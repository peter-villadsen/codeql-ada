/**
 * AdaControl rule `Style`: the subrules that can be checked on the tree
 * (`docs/adacontrol.md`): casing of identifiers, attributes, pragmas, aspects, the
 * extended digits and exponent of numbers; `default_in`, `exposed_literal`,
 * `multiple_elements`, `no_closing_name`, `numeric_literal`, `parameter_order`,
 * `formal_parameter_order` and `renamed_entity`. `casing_keyword` and
 * `compound_statement` need the keywords' tokens, which the extractor does not keep.
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Declarations

module Style {
  /* --- casing ------------------------------------------------------------------ */

  /** Gets `text` in title case: each word (between underscores) capitalized, the rest lower case. */
  bindingset[text]
  string titlecase(string text) {
    result =
      concat(int i, string w |
        w = text.splitAt("_", i)
      |
        w.prefix(1).toUpperCase() + w.suffix(1).toLowerCase(), "_" order by i
      )
  }

  /** Holds if `text` is in `casing`: `uppercase`, `lowercase` or `titlecase`. */
  bindingset[text, casing]
  predicate hasCasing(string text, string casing) {
    casing = "uppercase" and text = text.toUpperCase()
    or
    casing = "lowercase" and text = text.toLowerCase()
    or
    casing = "titlecase" and text = titlecase(text)
  }

  /**
   * Gets the casing of the declaration of identifier `n`, when `n` is spelled
   * otherwise (`casing_identifier original`): `n` is a reference, or the name of a
   * body or other completion whose first declaration spells it otherwise.
   */
  string originalCasing(Raw::Identifier n) {
    exists(Raw::BasicDecl d, string text | text = n.getValue() |
      not n.getParent() instanceof Raw::DefiningName and
      d = n.getReferencedDecl() and
      result = d.getADefiningName().getName().getText() and
      result.toLowerCase() = text.toLowerCase() and
      not d.getADefiningName().getName().getText() = text
      or
      exists(Raw::BasicDecl completion |
        ada_body_part(d, completion) and
        n = completion.getADefiningName().getName() and
        result = d.getADefiningName().getName().getText() and
        result.toLowerCase() = text.toLowerCase() and
        result != text
      )
    )
  }

  /**
   * Gets the word of `n` whose casing `element` controls: `attribute` (an attribute
   * designator), `pragma`, `aspect`, `number` (the extended digits of a based
   * literal) or `exponent` (the `E` of an exponent).
   */
  string casedWord(Raw::AdaNode n, string element) {
    result = n.(Raw::AttributeRef).getAttribute().getValue() and element = "attribute"
    or
    result = n.(Raw::PragmaNode).getId().getValue() and element = "pragma"
    or
    result = n.(Raw::AspectAssoc).getId().(Raw::Identifier).getValue() and element = "aspect"
    or
    exists(string v | v = literalText(n) |
      result = v.regexpCapture("[0-9_]+#([0-9a-zA-Z_.]+)#.*", 1) and
      exists(result.regexpFind("[a-zA-Z]", _, _)) and
      element = "number"
      or
      result = v.regexpCapture("([0-9_]+#[0-9a-zA-Z_.]+#|[0-9_.]+)([eE]).*", 2) and
      element = "exponent"
    )
  }

  /** Gets the text of numeric literal `l`, as written. */
  string literalText(Raw::NumLiteral l) {
    result = l.(Raw::IntLiteral).getValue() or result = l.(Raw::RealLiteral).getValue()
  }

  /* --- default_in -------------------------------------------------------------- */

  /**
   * `default_in`: parameter specification or generic formal object `p` has no mode,
   * so `in` is implicit; access parameters are not reported.
   */
  predicate defaultIn(Raw::AdaNode p) {
    p.(Raw::ParamSpec).getMode() instanceof Raw::ModeDefault and
    not p.(Raw::ParamSpec).getTypeExpr() instanceof Raw::AnonymousType
    or
    exists(Raw::ObjectDecl o | o = p.(Raw::GenericFormalObjDecl).getDecl() |
      o.getMode() instanceof Raw::ModeDefault and not o.getTypeExpr() instanceof Raw::AnonymousType
    )
  }

  /* --- exposed_literal --------------------------------------------------------- */

  /**
   * Gets the kind of numeric literal `l` (`integer` or `real`) when it is outside the
   * places literals are allowed by default: a named number declaration (`number`) and
   * a constant declaration (`constant`).
   */
  string exposedLiteral(Raw::NumLiteral l) {
    (l instanceof Raw::IntLiteral and result = "integer" or l instanceof Raw::RealLiteral and result = "real") and
    not l.getParent+() instanceof Raw::NumberDecl and
    not exists(Raw::ObjectDecl o |
      l.getParent+() = o and o.getHasConstant() instanceof Raw::ConstantPresent
    )
  }

  /** Gets the value of numeric literal `l`, normalized for comparison: without underscores, lower case. */
  string literalValue(Raw::NumLiteral l) { result = literalText(l).replaceAll("_", "").toLowerCase() }

  /* --- multiple_elements ------------------------------------------------------- */

  /** Holds if `list` holds elements: clauses, pragmas, declarations, statements or handlers. */
  private predicate isElementList(Raw::AdaNode list) {
    list instanceof Raw::StmtList or
    list = any(Raw::DeclarativePart dp).getChild(_) or
    list = any(Raw::CompilationUnit cu).getPrelude() or
    list = any(Raw::HandledStmts hs).getExceptions() or
    list = any(Raw::GenericFormalPart g).getDecls()
  }

  /**
   * `multiple_elements`: element `b` starts on the line where the element before it,
   * `a`, ends. `flexible` holds when `a` is a `with` clause and `b` a `use` clause of
   * packages it names (AdaControl's `flexible clause`).
   */
  predicate multipleElements(Raw::AdaNode a, Raw::AdaNode b, boolean flexible) {
    exists(Raw::AdaNode list, int i |
      isElementList(list) and
      a = list.getChild(i) and
      b = list.getChild(i + 1) and
      a.getLocation().getEndLine() = b.getLocation().getStartLine()
    ) and
    if
      a instanceof Raw::WithClause and
      b instanceof Raw::UsePackageClause and
      forall(Raw::Name n | n = b.(Raw::UsePackageClause).getPackages().getChild(_) |
        n.getText().toLowerCase() =
          a.(Raw::WithClause).getPackages().getChild(_).(Raw::Name).getText().toLowerCase()
      )
    then flexible = true
    else flexible = false
  }

  /* --- no_closing_name --------------------------------------------------------- */

  /** Holds if construct `c` may have a closing name, and has an `end`. */
  private predicate mayHaveClosingName(Raw::AdaNode c) {
    c instanceof Raw::SubpBody or
    c instanceof Raw::PackageBody or
    c instanceof Raw::BasePackageDecl or
    c instanceof Raw::TaskBody or
    c instanceof Raw::ProtectedBody or
    c instanceof Raw::EntryBody or
    c instanceof Raw::TaskDef or
    c instanceof Raw::ProtectedDef
  }

  /** `no_closing_name`: construct `c`, `lines` lines long, has no name after its `end`. */
  predicate noClosingName(Raw::AdaNode c, int lines) {
    mayHaveClosingName(c) and
    not exists(Raw::EndName e | e.getParent() = c) and
    lines = c.getLocation().getEndLine() - c.getLocation().getStartLine() + 1
  }

  /* --- numeric_literal --------------------------------------------------------- */

  /**
   * `numeric_literal`: decimal literal `l` does not have an underscore every
   * `blockSize` digits of its integer part.
   */
  bindingset[blockSize]
  predicate numericLiteral(Raw::NumLiteral l, int blockSize) {
    exists(string integerPart |
      not literalText(l).matches("%#%") and
      integerPart = literalText(l).regexpCapture("([0-9_]+).*", 1) and
      not integerPart.regexpMatch("[0-9]{1," + blockSize + "}(_[0-9]{" + blockSize + "})*")
    )
  }

  /* --- parameter_order, formal_parameter_order -------------------------------- */

  /**
   * Gets the mode keyword of parameter specification `p`: `in`, `defaulted_in`,
   * `access`, `in_out` or `out`.
   */
  string parameterMode(Raw::ParamSpec p) {
    exists(Raw::Mode m | m = p.getMode() |
      (m instanceof Raw::ModeIn or m instanceof Raw::ModeDefault) and
      (
        p.getTypeExpr() instanceof Raw::AnonymousType and result = "access"
        or
        not p.getTypeExpr() instanceof Raw::AnonymousType and
        if exists(p.getDefaultExpr()) then result = "defaulted_in" else result = "in"
      )
      or
      m instanceof Raw::ModeInOut and result = "in_out"
      or
      m instanceof Raw::ModeOut and result = "out"
    )
  }

  /** Gets the rank of `mode` in the default order of parameters: `in` or `access`, `in_out`, `out`, `defaulted_in`. */
  int parameterRank(string mode) {
    mode = ["in", "access"] and result = 0
    or
    mode = "in_out" and result = 1
    or
    mode = "out" and result = 2
    or
    mode = "defaulted_in" and result = 3
  }

  /** Gets the mode keyword of generic formal `f`: `type`, `in`, `defaulted_in`, `access`, `in_out`, `procedure`, `function` or `package`. */
  string formalMode(Raw::GenericFormal f) {
    f instanceof Raw::GenericFormalTypeDecl and result = "type"
    or
    exists(Raw::ObjectDecl o | o = f.(Raw::GenericFormalObjDecl).getDecl() |
      o.getMode() instanceof Raw::ModeInOut and result = "in_out"
      or
      not o.getMode() instanceof Raw::ModeInOut and
      (
        o.getTypeExpr() instanceof Raw::AnonymousType and result = "access"
        or
        not o.getTypeExpr() instanceof Raw::AnonymousType and
        if exists(o.getDefaultExpr()) then result = "defaulted_in" else result = "in"
      )
    )
    or
    exists(Raw::SubpSpec s | s.getParent+() = f.(Raw::GenericFormalSubpDecl).getDecl() |
      s.getSubpKind() instanceof Raw::SubpKindProcedure and result = "procedure"
      or
      s.getSubpKind() instanceof Raw::SubpKindFunction and result = "function"
    )
    or
    f instanceof Raw::GenericFormalPackage and result = "package"
  }

  /** Gets the rank of `mode` in the default order of generic formals: `type`; `in`, `defaulted_in`, `access`; `in_out`; `procedure`, `function`; `package`. */
  int formalRank(string mode) {
    mode = "type" and result = 0
    or
    mode = ["in", "defaulted_in", "access"] and result = 1
    or
    mode = "in_out" and result = 2
    or
    mode = ["procedure", "function"] and result = 3
    or
    mode = "package" and result = 4
  }

  /**
   * `parameter_order`: parameter specification `p`, of `mode`, follows one of `previous`,
   * a mode that comes after it in the default order.
   */
  predicate parameterOrder(Raw::ParamSpec p, string mode, string previous) {
    exists(Raw::AdaNode list, int i, int j, Raw::ParamSpec q |
      p = list.getChild(i) and
      q = list.getChild(j) and
      j < i and
      mode = parameterMode(p) and
      previous = parameterMode(q) and
      parameterRank(previous) > parameterRank(mode)
    )
  }

  /**
   * `formal_parameter_order`: generic formal `f`, of `mode`, follows one of `previous`,
   * a mode that comes after it in the default order.
   */
  predicate formalParameterOrder(Raw::GenericFormal f, string mode, string previous) {
    exists(Raw::GenericFormalPart g, int i, int j, Raw::GenericFormal q |
      f = g.getDecls().getChild(i) and
      q = g.getDecls().getChild(j) and
      j < i and
      mode = formalMode(f) and
      previous = formalMode(q) and
      formalRank(previous) > formalRank(mode)
    )
  }

  /* --- renamed_entity ---------------------------------------------------------- */

  /** Gets the declaration renaming declaration `r` renames, when it is a whole entity. */
  Raw::BasicDecl renamed(Raw::BasicDecl r) {
    exists(Raw::Name n |
      n = r.(Raw::ObjectDecl).getRenamingClause().getRenamedObject() or
      n = r.(Raw::PackageRenamingDecl).getRenames().getRenamedObject() or
      n = r.(Raw::SubpRenamingDecl).getRenames().getRenamedObject() or
      n = r.(Raw::ExceptionDecl).getRenames().getRenamedObject()
    |
      result = n.getReferencedDecl() and
      (n instanceof Raw::Identifier or n instanceof Raw::DottedName) and
      not result instanceof Raw::ComponentDecl
    )
  }

  /** Gets the region renaming `r` is visible in: its declarative region, and the body of a package spec. */
  private Raw::AdaNode renamingScope(Raw::BasicDecl r) {
    exists(Raw::DeclarativePart dp | r.getParent().getParent() = dp |
      result = dp.getParent()
      or
      ada_body_part(dp.getParent(), result)
      or
      ada_body_part(dp.getParent().getParent(), result)
    )
  }

  /** Holds if `a` starts after `b` ends, in the same file. */
  private predicate after(Raw::AdaNode a, Raw::AdaNode b) {
    exists(string f, int al, int ac, int bl, int bc |
      a.getLocation().hasLocationInfo(f, al, ac, _, _) and
      b.getLocation().hasLocationInfo(f, _, _, bl, bc)
    |
      al > bl or al = bl and ac > bc
    )
  }

  /**
   * `renamed_entity`: name `n` names, by its original name, an entity that renaming
   * `r` renames, where `r` is visible.
   */
  predicate renamedEntity(Raw::Name n, Raw::BasicDecl r) {
    exists(Raw::BasicDecl d, Raw::AdaNode scope |
      d = renamed(r) and
      scope = renamingScope(r) and
      n.getReferencedDecl() = d and
      (n instanceof Raw::Identifier or n instanceof Raw::DottedName) and
      not n = any(Raw::DottedName dn | dn.getReferencedDecl() = d).getSuffix() and
      not n.getParent() instanceof Raw::DefiningName and
      not n.getParent*() instanceof Raw::EndName and
      not n.getParent+() = r and
      not n.getParent+() instanceof Raw::WithClause and
      n.getParent+() = scope and
      (after(n, r) or not n.getEnclosingUnit() = r.getEnclosingUnit())
    )
  }
}

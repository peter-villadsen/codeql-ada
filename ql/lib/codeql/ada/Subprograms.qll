/**
 * Subprograms and their parameters (Phase 12, `docs/phase12-plan.md`).
 *
 * A subprogram declared more than once -- a spec in the `.ads`, a body in the `.adb`,
 * perhaps a body stub `is separate` in between -- is one `Subprogram`: its first
 * declaration. Its parameters are those of that declaration. `getBody()`,
 * `getADeclaration()` and `Parameter.getADeclaration()` reach the other copies.
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.internal.Formals

/**
 * Holds if `d` is a further declaration of the subprogram first declared by `first`:
 * its completion (body), transitively, or the body stub of a separate body. The
 * extractor pairs a spec directly with the subunit's body and the stub with that same
 * body (`ada_body_part`), so a stub is matched through the body they share.
 */
private predicate laterDeclaration(Raw::BasicDecl first, Raw::BasicDecl d) {
  ada_body_part+(first, d)
  or
  exists(Raw::BasicDecl body |
    ada_body_part+(first, body) and
    ada_body_part(d, body) and
    d instanceof Raw::SubpBodyStub and
    // only a spec takes a stub; two stubs sharing a body (duplicate unit names, as in
    // gpr2's testsuite) are two subprograms, not one hidden behind the other
    not first instanceof Raw::SubpBodyStub
  )
}

/**
 * A subprogram: a procedure or a function. One per subprogram, however many times
 * it is declared: the spec when there is one, else the body (or the body stub of a
 * separate body). Includes predefined subprograms such as `Ada.Text_IO.Put_Line`,
 * so that they can be call targets; `fromSource()` excludes them.
 */
class Subprogram extends Raw::BasicDecl {
  Subprogram() {
    exists(subpSpecOf(this)) and
    not laterDeclaration(_, this)
  }

  /** Gets the `SubpSpec` of this declaration. */
  private Raw::SubpSpec getSpecNode() { result = subpSpecOf(this) }

  /** Gets the name of this subprogram, e.g. `Free_All`, or `"+"` for an operator. */
  string getName() { result = this.getAName() }

  /** Holds if this subprogram's simple name is `name`, ignoring case as Ada does. */
  bindingset[name]
  predicate hasName(string name) { this.getName().toLowerCase() = name.toLowerCase() }

  /** Gets the `i`th parameter (0-based, counting each name of `A, B : T` separately). */
  Parameter getParameter(int i) { result.getSubprogram() = this and result.getIndex() = i }

  /** Gets a parameter of this subprogram. */
  Parameter getAParameter() { result.getSubprogram() = this }

  /** Gets the number of parameters of this subprogram. */
  int getNumberOfParameters() { result = count(this.getAParameter()) }

  /** Holds if this subprogram is a function. */
  predicate isFunction() { this.getSpecNode().getSubpKind() instanceof Raw::SubpKindFunction }

  /** Holds if this subprogram is a procedure. */
  predicate isProcedure() { this.getSpecNode().getSubpKind() instanceof Raw::SubpKindProcedure }

  /** Gets the result type of this function, as written (`return String`). */
  Raw::TypeExpr getReturnTypeExpr() { result = this.getSpecNode().getSubpReturns() }

  /** Gets the declaration of this function's result type, if it resolves. */
  Raw::BaseTypeDecl getReturnType() {
    result = this.getReturnTypeExpr().(Raw::SubtypeIndication).getName().getReferencedDecl()
  }

  /** Gets the separate declaration (spec) of this subprogram, if it has one. */
  Raw::ClassicSubpDecl getSpec() { result = this }

  /**
   * Gets the body of this subprogram: this declaration itself when it is the body,
   * else its completion, through a body stub when the body is separate. No result
   * for an abstract or imported subprogram, or when the body was not extracted.
   */
  override Raw::BasicDecl getBody() {
    result = this.(Raw::BaseSubpBody)
    or
    laterDeclaration(this, result) and result instanceof Raw::BaseSubpBody
  }

  /** Gets a declaration of this subprogram: the spec, a body stub, or the body. */
  Raw::BasicDecl getADeclaration() { result = this or laterDeclaration(this, result) }
}

/**
 * A formal parameter of a subprogram, as declared in the subprogram's first
 * declaration (see `Subprogram`). Each name of `A, B : in T` is a parameter.
 *
 * The node is the parameter's `DefiningName`. The class extends `Name` rather than
 * `DefiningName` so that `getName()` can be the parameter's name, as in Java, instead
 * of the generated `DefiningName.getName()`, which gives the name node.
 */
class Parameter extends Raw::Name {
  Subprogram subp;
  int index;

  Parameter() { this = formalAt(subpSpecOf(subp), index) }

  /** Gets the subprogram this is a parameter of. */
  Subprogram getSubprogram() { result = subp }

  /** Gets the 0-based position of this parameter. */
  int getIndex() { result = index }

  /** Gets the name of this parameter. */
  string getName() { result = this.(Raw::DefiningName).getName().getText() }

  /** Holds if this parameter's name is `name`, ignoring case as Ada does. */
  bindingset[name]
  predicate hasName(string name) { this.getName().toLowerCase() = name.toLowerCase() }

  /** Gets the `ParamSpec` declaring this parameter (and any others in its group). */
  Raw::ParamSpec getParamSpec() { this = result.getIds().getChild(_) }

  /** Gets the mode: `"in"` (also when not written), `"out"` or `"in out"`. */
  string getMode() {
    exists(Raw::Mode m | m = this.getParamSpec().getMode() |
      (m instanceof Raw::ModeIn or m instanceof Raw::ModeDefault) and result = "in"
      or
      m instanceof Raw::ModeOut and result = "out"
      or
      m instanceof Raw::ModeInOut and result = "in out"
    )
  }

  /** Holds if the caller's value is passed in: mode `in` or `in out`. */
  predicate isIn() { this.getMode() = ["in", "in out"] }

  /** Holds if a value is passed back to the caller: mode `out` or `in out`. */
  predicate isOut() { this.getMode() = ["out", "in out"] }

  /** Gets this parameter's type, as written (`Formula`, `access String`). */
  Raw::TypeExpr getTypeExpr() { result = this.getParamSpec().getTypeExpr() }

  /** Gets the declaration of this parameter's type, if it is a named type that resolves. */
  override Raw::BaseTypeDecl getType() {
    result = this.getTypeExpr().(Raw::SubtypeIndication).getName().getReferencedDecl()
  }

  /** Gets the default value of this parameter, if it has one (`X : Integer := 0`). */
  Raw::Expr getDefaultExpr() { result = this.getParamSpec().getDefaultExpr() }

  /**
   * Gets this parameter's defining name in another declaration of its subprogram
   * (the body, a body stub): the one that names inside that declaration resolve to.
   */
  Raw::DefiningName getADeclaration() {
    result = this
    or
    exists(Raw::BasicDecl other | other = subp.getADeclaration() and other != subp |
      result = formalAt(subpSpecOf(other), index)
    )
  }

  /** Gets a name, anywhere, that refers to this parameter. */
  Raw::Name getAnAccess() {
    exists(Raw::DefiningName d, Raw::ParamSpec ps |
      d = this.getADeclaration() and
      d = ps.getIds().getChild(_) and
      result.getReferencedDecl() = ps and
      // a reference resolves to the whole `ParamSpec` group; the text picks the name
      result.getText().toLowerCase() = this.getName().toLowerCase()
    )
  }
}

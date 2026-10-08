/**
 * Hand-written predicates of the generated AST classes (D-027).
 *
 * `generator/gen.py` adds each `XExt` class below as an extra supertype of the
 * generated class `X` in `Raw.qll`, so that there is one `Expr`, one `Name`, one
 * `BasicDecl`: the generated accessors and these predicates on the same class.
 * `ifStmt.getCondition().getType()` then compiles, which it could not while these
 * were subclasses of the generated ones.
 *
 * A mixin extends the database type of its node kind as well as `AdaNode`, so that
 * its predicates range over the right nodes when evaluated in bulk: without it,
 * `BasicDeclExt.getADefiningName` was computed for every node, a 20-million-row join
 * on a small database. `this` is cast to the generated class wherever one of its
 * accessors is needed.
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.ast.internal.RawMeta
private import codeql.ada.Declarations as Declarations

/** Holds if `loc` lies in a predefined pseudo-source file (D-026). */
private predicate inPredefinedFile(Raw::Location loc) {
  exists(Raw::File f | locations_default(loc, f, _, _, _, _) and ada_predefined_file(f))
}

/** Predicates of `File`. */
class FileExt extends @file {
  /**
   * Holds if this file is a predefined pseudo-source: package `Standard` or a runtime
   * unit the project refers to directly. These are extracted only so that names
   * resolve into them (D-026); queries report nothing in them.
   */
  predicate isPredefined() { ada_predefined_file(this) }

  /** Gets a textual representation of this file; overridden by `File`. */
  string toString() { none() }
}

/** Predicates of `Comment`. */
class CommentExt extends @ada_comment {
  /** Holds if this comment is in the project's own sources, not a predefined file (D-026). */
  predicate fromSource() { not inPredefinedFile(this.(Raw::Comment).getLocation()) }

  /** Gets a textual representation of this comment; overridden by `Comment`. */
  string toString() { none() }
}

/** Predicates of every AST node. */
class AdaNodeExt extends @ada_ast_node {
  /**
   * Holds if this node is in the project's own sources, not in a predefined
   * pseudo-source such as package `Standard` (D-026). Every query restricts its
   * reported element to this.
   */
  predicate fromSource() { not inPredefinedFile(this.(Raw::AdaNode).getLocation()) }

  /** Gets the compilation unit containing this node. */
  Raw::CompilationUnit getEnclosingUnit() { result = this.(Raw::AdaNode).getParent*() }

  /** Gets a subprogram body containing this node, innermost first. */
  Raw::BaseSubpBody getEnclosingSubprogram() { result = this.(Raw::AdaNode).getParent+() }

  /** Gets a textual representation of this node; overridden by `AdaNode`. */
  string toString() { none() }
}

/** Predicates of `Name`: source text and name resolution. */
class NameExt extends Raw::AdaNode, @ada_name {
  /** Gets the source text of this name, if it is a simple or dotted name. */
  string getText() {
    result = this.(Raw::Identifier).getValue()
    or
    result = this.(Raw::StringLiteral).getValue()
    or
    result = this.(Raw::CharLiteral).getValue()
    or
    exists(Raw::DottedName d | d = this |
      result = d.getPrefix().getText() + "." + d.getSuffix().getText()
    )
  }

  /** Gets the declaration this name resolves to, if extracted. */
  Raw::BasicDecl getReferencedDecl() { ada_xref(this, result) }

  /**
   * Holds if this name and `other` denote the same entity, compared structurally:
   * simple names must resolve to the same declaration *and* name the same defining
   * name within it, since a multi-identifier declaration such as `A, B : T` is one
   * `BasicDecl` (D-024); dotted names must match component-wise, prefix and selector
   * both, so `L.Size` and `R.Size` differ even though both resolve to the component
   * `Size`. Anything else (calls, indexing, dereferences) never matches. Names that
   * do not resolve never match.
   */
  predicate denotesSameEntityAs(Raw::Name other) {
    this instanceof Raw::Identifier and
    other instanceof Raw::Identifier and
    this.getReferencedDecl() = other.getReferencedDecl() and
    this.getText().toLowerCase() = other.getText().toLowerCase()
    or
    exists(Raw::DottedName d, Raw::DottedName e | d = this and e = other |
      d.getPrefix().denotesSameEntityAs(e.getPrefix()) and
      d.getSuffix().denotesSameEntityAs(e.getSuffix())
    )
  }
}

/** Predicates of `Expr`: stored type information. */
class ExprExt extends Raw::AdaNode, @ada_expr {
  /** Gets the declaration of this expression's type, if extracted. */
  Declarations::Type getType() { ada_expr_type(this, result) }
}

/** Predicates of `BasicDecl`: names, references, completion, renaming. */
class BasicDeclExt extends Raw::AdaNode, @ada_basic_decl {
  /** Gets a name this declaration introduces (not names of nested declarations). */
  Raw::DefiningName getADefiningName() {
    result.getParent+() = this and
    not exists(Raw::BasicDecl mid |
      mid != this and result.getParent+() = mid and mid.getParent+() = this
    )
  }

  /** Gets the text of a name this declaration introduces. */
  string getAName() { result = this.getADefiningName().getName().getText() }

  /** Holds if some extracted name resolves to this declaration. */
  predicate isReferenced() { ada_xref(_, this) }

  /**
   * Holds if, inside subprogram body `body`, an identifier that did not resolve at all
   * is spelled like one of this declaration's names (ignoring case), so it may be a
   * reference that extraction could not resolve, typically because the project's
   * dependencies were not available. A query that reports "never referenced" should
   * treat this as a use: D-026's rule, falling back to text only when a name does not
   * resolve.
   */
  predicate hasUnresolvedNamesakeIn(Raw::BaseSubpBody body) {
    exists(Raw::Identifier i |
      unresolvedIdentifier(i, this.getAName().toLowerCase()) and
      i.getEnclosingSubprogram() = body
    )
  }

  /**
   * Holds if this declaration is marked as intentionally unreferenced: by the
   * `Unreferenced` aspect (`X : T with Unreferenced;`), or by a `pragma Unreferenced`
   * naming it, matched by resolution or, if the argument does not resolve, by text
   * within the same subprogram.
   */
  predicate isMarkedUnreferenced() {
    exists(Raw::AspectAssoc a |
      a = this.(Raw::BasicDecl).getAspects().getAspectAssocs().getChild(_)
    |
      a.getId().(Raw::Name).getText().toLowerCase() = "unreferenced" and
      not a.getExpr().(Raw::Name).getText().toLowerCase() = "false"
    )
    or
    exists(Raw::PragmaNode p, Raw::Name arg |
      p.getId().getValue().toLowerCase() = "unreferenced" and
      arg = p.getArgs().getChild(_).(Raw::PragmaArgumentAssoc).getExpr()
    |
      arg.getReferencedDecl() = this
      or
      not exists(arg.getReferencedDecl()) and
      arg.getText().toLowerCase() = this.getAName().toLowerCase() and
      p.getEnclosingSubprogram() = this.getEnclosingSubprogram()
    )
  }

  /**
   * Gets the completion of this declaration: the body of a subprogram or package
   * spec, the subunit of a body stub. Extracted from Libadalang's `p_body_part`,
   * never inferred from name text, since overloading makes textual pairing unsound
   * (D-021). `Subprogram.getBody()` and `Package.getBody()` are the usual way in.
   */
  Raw::BasicDecl getCompletion() { ada_body_part(this, result) }

  /**
   * Gets the fully qualified name of this declaration, as Libadalang computes it:
   * `Ada.Text_IO.Open`, `Standard.Constraint_Error`, `Standard.Boolean.True`.
   * Runtime entities have one when their unit is a predefined pseudo-source (D-026).
   * A declaration of several names (`A, B : T`) has one per name (`Pkg.A`, `Pkg.B`).
   */
  string getQualifiedName() { ada_qualified_name(this, result) }

  /** Holds if this declaration's qualified name is `name`, ignoring case as Ada does. */
  bindingset[name]
  predicate hasQualifiedName(string name) {
    this.getQualifiedName().toLowerCase() = name.toLowerCase()
  }

  /**
   * Gets the declaration this one ultimately renames, following any chain of
   * renamings (`E : exception renames Constraint_Error`, `procedure P renames
   * Ada.Text_IO.Open`, `package T renames Ada.Text_IO`, ...), or this declaration
   * itself if it is not a renaming. No result if a renamed name does not resolve.
   * Generic renamings need no following: `ada_generic_instantiation` already
   * resolves through them.
   */
  Raw::BasicDecl getUltimateDecl() {
    not exists(renamingClause(this)) and result = this
    or
    result = renamingClause(this).getRenamedObject().(Raw::Name).getReferencedDecl().getUltimateDecl()
  }
}

/**
 * Holds if `i` is an identifier used as a name (not a declared name, an `end` name, an
 * attribute designator, or a pragma or aspect identifier) that did not resolve, and
 * `lname` is its text in lower case.
 */
private predicate unresolvedIdentifier(Raw::Identifier i, string lname) {
  not ada_xref(i, _) and
  lname = i.getValue().toLowerCase() and
  not i.getParent() instanceof Raw::DefiningName and
  not i.getParent+() instanceof Raw::EndName and
  not i = any(Raw::AttributeRef a).getAttribute() and
  not i = any(Raw::PragmaNode p).getId() and
  not i = any(Raw::AspectAssoc a).getId()
}

private Raw::RenamingClause renamingClause(BasicDeclExt d) {
  result = d.(Raw::ExceptionDecl).getRenames() or
  result = d.(Raw::SubpRenamingDecl).getRenames() or
  result = d.(Raw::PackageRenamingDecl).getRenames() or
  result = d.(Raw::ObjectDecl).getRenamingClause()
}

/** Predicates of `GenericInstantiation`. */
class GenericInstantiationExt extends Raw::AdaNode, @ada_generic_instantiation {
  /**
   * Gets the generic declaration this instantiates, resolved through generic
   * renamings. No result if it does not resolve (e.g. no GNAT runtime was found).
   */
  Raw::BasicDecl getDesignatedGeneric() { ada_generic_instantiation(this, result) }
}

/** Predicates of `BaseSubpBody`: a subprogram body or expression-function completion. */
class BaseSubpBodyExt extends Raw::AdaNode, @ada_base_subp_body {
  /** Gets the declaration this body completes, if extracted (D-021). */
  Raw::BasicDecl getDeclaration() { ada_body_part(result, this) }
}

/**
 * Gets the text shown for `n` in query results and path explanations (D-027): what
 * the node is, as Java's library does it. A declaration shows its name (`Free_All`),
 * an expression a short rendering (`F.Length`, `Append (...)`, `... + ...`), a
 * statement its leading keywords (`if ...`, `Res := ...`); any other node its class.
 * `getAPrimaryQlClass()` still gives the class.
 */
string nodeToString(Raw::AdaNode n) {
  if n instanceof Raw::Expr
  then result = exprString(n)
  else
    if exists(declString(n))
    then result = declString(n)
    else
      if exists(stmtString(n))
      then result = stmtString(n)
      else result = n.getAPrimaryQlClass()
}

/** Gets a short rendering of expression `e`, or its class when there is no better one. */
private string exprString(Raw::Expr e) {
  if exists(e.(Raw::Name).getText())
  then result = e.(Raw::Name).getText()
  else
    if exists(tokenText(e))
    then result = tokenText(e)
    else
      if e instanceof Raw::DefiningName
      then result = exprString(e.(Raw::DefiningName).getName())
      else
        if e instanceof Raw::CallExpr
        then result = exprString(e.(Raw::CallExpr).getName()) + " (...)"
        else
          if e instanceof Raw::AttributeRef
          then
            result =
              exprString(e.(Raw::AttributeRef).getPrefix()) + "'" +
                e.(Raw::AttributeRef).getAttribute().getValue()
          else
            if e instanceof Raw::ExplicitDeref
            then result = exprString(e.(Raw::ExplicitDeref).getPrefix()) + ".all"
            else
              if e instanceof Raw::QualExpr
              then result = exprString(e.(Raw::QualExpr).getPrefix()) + "'(...)"
              else
                if e instanceof Raw::Allocator
                then result = "new ..."
                else
                  if e instanceof Raw::ConcatOp or e.(Raw::BinOp).getOp() instanceof Raw::OpConcat
                  then result = "... & ..."
                  else
                    if e instanceof Raw::Aggregate or e instanceof Raw::ParenExpr
                    then result = "(...)"
                    else
                      if exists(tokenText(e.(Raw::BinOp).getOp()))
                      then result = "... " + tokenText(e.(Raw::BinOp).getOp()) + " ..."
                      else
                        if exists(tokenText(e.(Raw::UnOp).getOp()))
                        then result = tokenText(e.(Raw::UnOp).getOp()) + " ..."
                        else result = e.getAPrimaryQlClass()
}

/** Gets the names a declaration introduces, as shown in results, if it has any. */
private string declString(Raw::BasicDecl d) {
  result = strictconcat(string name | name = d.getAName() | name, ", ")
  or
  // a generic's name is in its inner declaration, which `getAName` does not look into
  result = declString(d.(Raw::GenericPackageDecl).getPackageDecl())
  or
  result = declString(d.(Raw::GenericSubpDecl).getSubpDecl())
}

/** Gets the leading keywords of statement (or pragma or clause) `s`, if they say something. */
private string stmtString(Raw::AdaNode s) {
  result = exprString(s.(Raw::CallStmt).getCall()) + ";"
  or
  result = exprString(s.(Raw::AssignStmt).getDest()) + " := ..."
  or
  s instanceof Raw::ReturnStmt and
  if exists(s.(Raw::ReturnStmt).getReturnExpr()) then result = "return ..." else result = "return"
  or
  s instanceof Raw::ExtendedReturnStmt and result = "return ... do"
  or
  s instanceof Raw::IfStmt and result = "if ..."
  or
  s instanceof Raw::CaseStmt and result = "case ..."
  or
  s instanceof Raw::ForLoopStmt and result = "for ... loop"
  or
  s instanceof Raw::WhileLoopStmt and result = "while ... loop"
  or
  s instanceof Raw::LoopStmt and result = "loop ..."
  or
  s instanceof Raw::DeclBlock and result = "declare ..."
  or
  s instanceof Raw::BeginBlock and result = "begin ..."
  or
  s instanceof Raw::NullStmt and result = "null;"
  or
  s instanceof Raw::ExitStmt and result = "exit"
  or
  s instanceof Raw::DelayStmt and result = "delay ..."
  or
  s instanceof Raw::RaiseStmt and
  if exists(s.(Raw::RaiseStmt).getExceptionName())
  then result = "raise " + exprString(s.(Raw::RaiseStmt).getExceptionName())
  else result = "raise"
  or
  result = "goto " + exprString(s.(Raw::GotoStmt).getLabelName())
  or
  result = "pragma " + s.(Raw::PragmaNode).getId().getValue()
  or
  s instanceof Raw::WithClause and result = "with ..."
  or
  s instanceof Raw::UseClause and result = "use ..."
}

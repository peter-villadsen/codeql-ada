/** Ada QL library: user-facing entry point. */

import codeql.ada.ast.internal.Raw

/** A file in the snapshot. */
class File = Raw::File;

/** A location in the snapshot. */
class Location = Raw::Location;

/** An Ada AST node, with scope navigation helpers. */
class AdaNode extends Raw::AdaNode {
  /** Gets the compilation unit containing this node. */
  Raw::CompilationUnit getEnclosingUnit() { result = this.getParent*() }

  /** Gets a subprogram body containing this node, innermost first. */
  Raw::BaseSubpBody getEnclosingSubprogram() { result = this.getParent+() }
}

/** A name, with source text reconstruction and name-resolution access. */
class Name extends Raw::Name {
  /** Gets the source text of this name, if it is a simple or dotted name. */
  string getText() {
    result = this.(Raw::Identifier).getValue()
    or
    result = this.(Raw::StringLiteral).getValue()
    or
    result = this.(Raw::CharLiteral).getValue()
    or
    exists(Raw::DottedName d | d = this |
      result =
        d.getPrefix().(Name).getText() + "." + d.getSuffix().(Name).getText()
    )
  }

  /** Gets the declaration this name resolves to, if extracted. */
  Raw::BasicDecl getReferencedDecl() { ada_xref(this, result) }
}

/** An expression, with stored type information. */
class Expr extends Raw::Expr {
  /** Gets the declaration of this expression's type, if extracted. */
  Raw::BaseTypeDecl getType() { ada_expr_type(this, result) }
}

/** A declaration, with defining-name access. */
class BasicDecl extends Raw::BasicDecl {
  /** Gets a name this declaration introduces (not names of nested declarations). */
  Raw::DefiningName getADefiningName() {
    result.getParent+() = this and
    not exists(Raw::BasicDecl mid |
      mid != this and result.getParent+() = mid and mid.getParent+() = this
    )
  }

  /** Gets the text of a name this declaration introduces. */
  string getAName() { result = this.getADefiningName().getName().(Name).getText() }

  /** Holds if some extracted name resolves to this declaration. */
  predicate isReferenced() { ada_xref(_, this) }

  /**
   * Gets the completion (body) of this declaration, if extracted. Extracted
   * from Libadalang's `p_body_part`, never inferred from name text, since
   * overloading makes textual pairing unsound (D-021).
   */
  Raw::BasicDecl getBody() { ada_body_part(this, result) }
}

/** A subprogram body, with its declared name. */
class SubprogramBody extends Raw::SubpBody {
  /** Gets the name of this subprogram. */
  string getName() { result = this.(BasicDecl).getAName() }
}

/** A subprogram body or expression-function completion. */
class BaseSubpBody extends Raw::BaseSubpBody {
  /** Gets the declaration this body completes, if extracted (D-021). */
  Raw::BasicDecl getDeclaration() { ada_body_part(result, this) }
}

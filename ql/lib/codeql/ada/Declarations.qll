/**
 * Types, record components, variables and packages (Phase 12, `docs/phase12-plan.md`).
 *
 * Like `Parameter`, the classes over defining names (`Component`, `Variable`) extend
 * `Name` rather than `DefiningName`, and `Type` and `Package` extend `BasicDecl` rather
 * than the generated declaration classes, so that `getName()` can be the name as a
 * string, as in Java, instead of the generated accessor that gives the name node.
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Subprograms

/** Gets the type `te` names, if it is a named type that resolves (`Integer`, `Pkg.T`). */
Type namedType(Raw::TypeExpr te) {
  result = te.(Raw::SubtypeIndication).getName().getReferencedDecl()
}

/** Gets the text of defining name `dn`. */
private string nameOf(Raw::DefiningName dn) { result = dn.getName().getText() }

/** Gets the subprogram whose body most closely encloses `n`, if any. */
private Subprogram innermostSubprogram(Raw::AdaNode n) {
  exists(Raw::BaseSubpBody body |
    body = n.getParent+() and
    not exists(Raw::BaseSubpBody inner | inner = n.getParent+() and inner.getParent+() = body) and
    result.getBody() = body
  )
}

/**
 * A type or subtype declaration: `type T is ...`, `subtype S is ...`, an incomplete
 * or private view. A private type and its full declaration are two `Type`s in v1.
 */
class Type extends Raw::BasicDecl {
  Type() { this instanceof Raw::BaseTypeDecl }

  /** Gets the name of this type, e.g. `Formula`. No result for an anonymous type. */
  string getName() { result = nameOf(this.(Raw::BaseTypeDecl).getName()) }

  /** Holds if this type's name is `name`, ignoring case as Ada does. */
  bindingset[name]
  predicate hasName(string name) { this.getName().toLowerCase() = name.toLowerCase() }

  /** Gets the definition of this type (`record ... end record`, `(A, B)`, `array ...`). */
  Raw::TypeDef getDefinition() { result = this.(Raw::TypeDecl).getTypeDef() }

  /** Holds if this is a record type, or a derived type with a record extension. */
  predicate isRecord() {
    this.getDefinition() instanceof Raw::RecordTypeDef
    or
    exists(this.getDefinition().(Raw::DerivedTypeDef).getRecordExtension())
  }

  /** Holds if this is a tagged type: `tagged record`, `tagged private`, or an extension. */
  predicate isTagged() {
    this.getDefinition().(Raw::RecordTypeDef).getHasTagged() instanceof Raw::TaggedPresent
    or
    this.getDefinition().(Raw::PrivateTypeDef).getHasTagged() instanceof Raw::TaggedPresent
    or
    exists(this.getDefinition().(Raw::DerivedTypeDef).getRecordExtension())
  }

  /** Holds if this is an enumeration type. */
  predicate isEnumeration() { this.getDefinition() instanceof Raw::EnumTypeDef }

  /** Holds if this is an array type. */
  predicate isArray() { this.getDefinition() instanceof Raw::ArrayTypeDef }

  /** Holds if this is an access type. */
  predicate isAccess() { this.getDefinition() instanceof Raw::AccessDef }

  /** Holds if this is a private type (`type T is private;`), the partial view. */
  predicate isPrivate() { this.getDefinition() instanceof Raw::PrivateTypeDef }

  /** Holds if this is a subtype declaration (`subtype S is T range ...`). */
  predicate isSubtype() { this instanceof Raw::BaseSubtypeDecl }

  /**
   * Gets the type this one is derived from (`type T is new P`) or is a subtype of
   * (`subtype S is P range ...`), if it resolves.
   */
  Type getParentType() {
    result = namedType(this.getDefinition().(Raw::DerivedTypeDef).getSubtypeIndication())
    or
    result = namedType(this.(Raw::SubtypeDecl).getSubtype())
  }

  /** Gets a component of this record type (`F : Integer;`). */
  Component getAComponent() { result.getDeclaringType() = this }

  /** Gets an enumeration literal of this enumeration type. */
  Raw::EnumLiteralDecl getAnEnumerationLiteral() {
    result = this.getDefinition().(Raw::EnumTypeDef).getEnumLiterals().getChild(_)
  }
}

/** A component of a record type (`F : Integer := 0;`), each name of `A, B : T` separately. */
class Component extends Raw::Name {
  Raw::ComponentDecl decl;

  Component() { this = decl.getIds().getChild(_) }

  /** Gets the name of this component. */
  string getName() { result = nameOf(this) }

  /** Holds if this component's name is `name`, ignoring case as Ada does. */
  bindingset[name]
  predicate hasName(string name) { this.getName().toLowerCase() = name.toLowerCase() }

  /** Gets the declaration of this component (and any others in its group). */
  Raw::ComponentDecl getComponentDecl() { result = decl }

  /** Gets the record type this component belongs to. */
  Type getDeclaringType() {
    result = decl.getParent+() and
    not exists(Type inner | inner = decl.getParent+() and inner.getParent+() = result)
  }

  /** Gets the declaration of this component's type, if it is a named type that resolves. */
  override Type getType() { result = namedType(decl.getComponentDef().getTypeExpr()) }

  /** Gets the default value of this component, if it has one. */
  Raw::Expr getDefaultExpr() { result = decl.getDefaultExpr() }

  /** Gets a name that refers to this component (`R.F`, `(F => 1)`). */
  Raw::Name getAnAccess() {
    result.getReferencedDecl() = decl and
    result.getText().toLowerCase() = this.getName().toLowerCase()
  }
}

/**
 * A variable or constant: an object declaration (`X : Integer := 0;`,
 * `C : constant T := ...`, an object renaming), each name of `A, B : T` separately,
 * or a loop variable (`for I in ...`). Parameters and record components are
 * `Parameter`s and `Component`s instead.
 */
class Variable extends Raw::Name {
  Raw::BasicDecl decl;

  Variable() {
    this = decl.(Raw::ObjectDecl).getIds().getChild(_)
    or
    this = decl.(Raw::ForLoopVarDecl).getId()
  }

  /** Gets the name of this variable. */
  string getName() { result = nameOf(this) }

  /** Holds if this variable's name is `name`, ignoring case as Ada does. */
  bindingset[name]
  predicate hasName(string name) { this.getName().toLowerCase() = name.toLowerCase() }

  /** Gets the declaration of this variable (and any others in its group). */
  Raw::BasicDecl getDeclaration() { result = decl }

  /** Gets this variable's type, as written, if it is written. */
  Raw::TypeExpr getTypeExpr() {
    result = decl.(Raw::ObjectDecl).getTypeExpr() or result = decl.(Raw::ForLoopVarDecl).getIdType()
  }

  /**
   * Gets the declaration of this variable's type: the named type written, else the
   * type Libadalang computed (a loop variable over a range, `for I in 1 .. N`).
   */
  override Type getType() {
    result = namedType(this.getTypeExpr())
    or
    not exists(namedType(this.getTypeExpr())) and result = super.getType()
  }

  /** Gets the initial value of this variable (`:= ...`), if it has one. */
  Raw::Expr getInitializer() { result = decl.(Raw::ObjectDecl).getDefaultExpr() }

  /** Holds if this is a constant (`C : constant T := ...`). */
  predicate isConstant() { decl.(Raw::ObjectDecl).getHasConstant() instanceof Raw::ConstantPresent }

  /** Holds if this is an object renaming (`X : T renames Y;`). */
  predicate isRenaming() { exists(decl.(Raw::ObjectDecl).getRenamingClause()) }

  /** Holds if this is a loop variable. */
  predicate isLoopVariable() { decl instanceof Raw::ForLoopVarDecl }

  /**
   * Gets the subprogram this variable is declared in (the innermost one), if it is
   * local to one; no result for a variable declared in a package.
   */
  Subprogram getDeclaringSubprogram() { result = innermostSubprogram(this) }

  /** Holds if this variable is declared in a subprogram, not in a package. */
  predicate isLocal() { exists(this.getDeclaringSubprogram()) }

  /** Gets a name that refers to this variable. */
  Raw::Name getAnAccess() {
    result.getReferencedDecl() = decl and
    result.getText().toLowerCase() = this.getName().toLowerCase()
  }
}

/**
 * A package: its spec (`package P is ... end P;`), a generic package
 * (`generic ... package G is ...`), or an instance of one (`package I is new G (...)`).
 * One per package: the body is reached by `getBody()`.
 */
class Package extends Raw::BasicDecl {
  Package() {
    this instanceof Raw::PackageDecl or
    this instanceof Raw::GenericPackageDecl or
    this instanceof Raw::GenericPackageInstantiation
  }

  /** Gets the spec node holding this package's declarations. */
  private Raw::BasePackageDecl getSpecNode() {
    result = this or result = this.(Raw::GenericPackageDecl).getPackageDecl()
  }

  /** Gets the simple name of this package (`Text_IO` for `Ada.Text_IO`). */
  string getName() {
    exists(string full |
      full = this.getSpecNode().getPackageName().getName().getText()
      or
      full = nameOf(this.(Raw::GenericPackageInstantiation).getName())
    |
      result = full.regexpCapture("(?:.*\\.)?([^.]+)", 1)
    )
  }

  /** Holds if this package's simple name is `name`, ignoring case as Ada does. */
  bindingset[name]
  predicate hasName(string name) { this.getName().toLowerCase() = name.toLowerCase() }

  /** Gets the body of this package, if it has one and it was extracted. */
  Raw::BasicDecl getBody() {
    ada_body_part(this, result) or ada_body_part(this.getSpecNode(), result)
  }

  /** Gets a declaration of this package: the spec or the body. */
  Raw::BasicDecl getADeclaration() { result = this or result = this.getBody() }

  /** Gets a declaration in the visible part of this package. */
  Raw::BasicDecl getAPublicMember() {
    result = this.getSpecNode().getPublicPart().getDecls().getChild(_)
  }

  /**
   * Gets a declaration directly in this package: in the visible part, the private
   * part, or the body's declarative part. Not declarations nested in those.
   */
  Raw::BasicDecl getAMember() {
    result = this.getAPublicMember()
    or
    result = this.getSpecNode().getPrivatePart().getDecls().getChild(_)
    or
    result = this.getBody().(Raw::PackageBody).getDecls().getDecls().getChild(_)
  }

  /** Gets a subprogram declared directly in this package (see `getAMember`). */
  Subprogram getASubprogram() { result = this.getAMember() }

  /** Gets a type declared directly in this package (see `getAMember`). */
  Type getAType() { result = this.getAMember() }

  /** Gets a variable declared directly in this package (see `getAMember`). */
  Variable getAVariable() { result.getDeclaration() = this.getAMember() }

  /** Holds if this is a generic package. */
  predicate isGeneric() { this instanceof Raw::GenericPackageDecl }

  /** Holds if this is an instance of a generic package. */
  predicate isGenericInstance() { this instanceof Raw::GenericPackageInstantiation }

  /** Gets the generic package this is an instance of, if it resolves. */
  Package getGeneric() { result = this.(Raw::GenericInstantiation).getDesignatedGeneric() }
}

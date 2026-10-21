/**
 * AdaControl rule `Declarations`: declarations by kind, optionally only at given places
 * (`codeql.ada.adacontrol.Places`). `declaration(d, kw)` holds for each AdaControl
 * `<declaration_kw>` that applies to `d`; several may apply to one declaration
 * (`docs/adacontrol.md` lists the keywords implemented).
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Subprograms
private import codeql.ada.Calls
private import codeql.ada.Declarations as D
private import codeql.ada.adacontrol.TypeCategories

module Declarations {
  /** Gets the type definition of type declaration `t`. */
  private Raw::TypeDef typeDef(Raw::BasicDecl t) { result = t.(Raw::TypeDecl).getTypeDef() }

  /** Gets the subprogram spec of a subprogram declaration, body or stub. */
  private Raw::SubpSpec subpSpec(Raw::BasicDecl d) {
    result = d.(Raw::ClassicSubpDecl).getSubpSpec() or
    result = d.(Raw::BaseSubpBody).getSubpSpec() or
    result = d.(Raw::SubpBodyStub).getSubpSpec()
  }

  private predicate isFunctionSpec(Raw::SubpSpec s) { s.getSubpKind() instanceof Raw::SubpKindFunction }

  private predicate isOperatorName(Raw::SubpSpec s) {
    s.getSubpName().getName() instanceof Raw::StringLiteral
  }

  /** Holds if `d` is a subprogram body without a separate spec (and not the subunit of a stub). */
  private predicate isBodyWithoutSpec(Raw::BasicDecl d) {
    (d instanceof Raw::SubpBody or d instanceof Raw::SubpBodyStub) and
    not exists(Raw::BasicDecl spec | ada_body_part(spec, d)) and
    not d.getParent() instanceof Raw::Subunit
  }

  /** Gets the statements of subprogram body `b`, if it has no declarations. */
  private Raw::StmtList statementsOnly(Raw::SubpBody b) {
    not exists(Raw::AdaNode decl |
      decl = b.getDecls().getDecls().getChild(_) and not decl instanceof Raw::PragmaNode
    ) and
    not exists(b.getStmts().getExceptions().getChild(_)) and
    result = b.getStmts().getStmts()
  }

  /** Gets the only statement of subprogram body `b`, pragmas aside, if it has only one. */
  private Raw::Stmt onlyStatement(Raw::SubpBody b) {
    result = statementsOnly(b).getChild(_) and
    strictcount(Raw::Stmt s | s = statementsOnly(b).getChild(_)) = 1
  }

  /** Holds if `s` is `null;`, or a block without declarations of such statements only. */
  private predicate isNullStatement(Raw::Stmt s) {
    s instanceof Raw::NullStmt
    or
    forex(Raw::Stmt inner | inner = s.(Raw::BeginBlock).getStmts().getStmts().getChild(_) |
      isNullStatement(inner)
    )
  }

  /** Gets the record definition of record type `t` (`record ... end record`, `null record`, an extension). */
  private Raw::BaseRecordDef recordDef(Raw::TypeDecl t) {
    result = t.getTypeDef().(Raw::RecordTypeDef).getRecordDef() or
    result = t.getTypeDef().(Raw::DerivedTypeDef).getRecordExtension()
  }

  /** Holds if record definition `r` declares no components, and no variant part. */
  private predicate isNullRecord(Raw::BaseRecordDef r) {
    r instanceof Raw::NullRecordDef
    or
    not exists(Raw::ComponentDecl c | c = r.getComponents().getComponents().getChild(_)) and
    not exists(r.getComponents().getVariantPart())
  }

  /** Gets the declaration of the type `te` names, if it resolves. */
  private D::Type typeOf(Raw::TypeExpr te) { result = D::namedType(te) }

  /** Holds if `te` is an anonymous access type (`access T`, `access procedure ...`). */
  private predicate isAnonymousAccess(Raw::TypeExpr te) {
    te.(Raw::AnonymousType).getTypeDecl().getTypeDef() instanceof Raw::AccessDef
  }

  /** Holds if `d` is a variable: an object declaration that is not a constant, a renaming or a formal. */
  private predicate isVariable(Raw::ObjectDecl d) {
    not d.getHasConstant() instanceof Raw::ConstantPresent and
    not exists(d.getRenamingClause()) and
    not d.getParent() instanceof Raw::GenericFormal and
    not d instanceof Raw::ExtendedReturnStmtObjectDecl
  }

  private predicate isConstant(Raw::ObjectDecl d) {
    d.getHasConstant() instanceof Raw::ConstantPresent and not exists(d.getRenamingClause())
  }

  /** Holds if `t` is limited: `limited` in its definition, a task or protected type. */
  private predicate isLimited(D::Type t) {
    exists(D::Type u | u = TypeCategories::ultimateType(t) |
      u.getDefinition().(Raw::RecordTypeDef).getHasLimited() instanceof Raw::LimitedPresent or
      u.getDefinition().(Raw::PrivateTypeDef).getHasLimited() instanceof Raw::LimitedPresent or
      u.getDefinition().(Raw::DerivedTypeDef).getHasLimited() instanceof Raw::LimitedPresent or
      u instanceof Raw::TaskTypeDecl or
      u instanceof Raw::ProtectedTypeDecl
    )
  }

  /** Gets the category (`TypeCategories`) of the type of object declaration `d`. */
  private string objectCategory(Raw::ObjectDecl d) {
    result = TypeCategories::category(typeOf(d.getTypeExpr()), false)
    or
    result =
      TypeCategories::declaredCategory(d.getTypeExpr().(Raw::AnonymousType).getTypeDecl())
  }

  /** Holds if `d`'s type is class-wide (`T'Class`). */
  private predicate isClassWide(Raw::ObjectDecl d) {
    d.getTypeExpr().(Raw::SubtypeIndication).getName().(Raw::AttributeRef).getAttribute().getValue().toLowerCase() =
      "class"
  }

  /** Holds if `f` is declared as a generic formal. */
  private predicate isGenericFormal(Raw::AdaNode f) { f.getParent() instanceof Raw::GenericFormal }

  /** Holds if `part` declares nothing (pragmas aside). */
  private predicate hasNoDeclarations(Raw::DeclarativePart part) {
    not exists(Raw::AdaNode decl | decl = part.getDecls().getChild(_) and not decl instanceof Raw::PragmaNode)
  }

  /** Holds if `d` is of a kind AdaControl's `Declarations` names `kw`. */
  predicate declaration(Raw::AdaNode d, string kw) {
    kw = "any_declaration" and
    d instanceof Raw::BasicDecl and
    not d instanceof Raw::ExceptionHandler and
    // the wrapper of a generic formal; the formal's own declaration is inside it
    not d instanceof Raw::GenericFormal
    or
    // subprograms
    exists(Raw::SubpSpec s | s = subpSpec(d) |
      d instanceof Raw::AbstractSubpDecl and
      (
        isFunctionSpec(s) and kw = "abstract_function"
        or
        not isFunctionSpec(s) and kw = "abstract_procedure"
        or
        isOperatorName(s) and kw = "abstract_operator"
      )
      or
      not d instanceof Raw::FormalSubpDecl and
      (
        isFunctionSpec(s) and not d instanceof Raw::ExprFunction and kw = "function"
        or
        not isFunctionSpec(s) and kw = "procedure"
        or
        isOperatorName(s) and
        (not exists(Raw::BasicDecl spec | ada_body_part(spec, d))) and
        (
          kw = "operator"
          or
          s.getSubpName().getName().(Raw::StringLiteral).getValue() = ["\"=\"", "\"/=\""] and
          kw = "equality_operator"
        )
      )
      or
      isBodyWithoutSpec(d) and
      (
        isFunctionSpec(s) and kw = "no_spec_function"
        or
        not isFunctionSpec(s) and kw = "no_spec_procedure"
      )
    )
    or
    d instanceof Raw::ExprFunction and kw = "expression_function"
    or
    d instanceof Raw::NullSubpDecl and kw = ["null_procedure_declaration", "null_procedure"]
    or
    exists(Raw::SubpBody b | b = d and not isFunctionSpec(b.getSubpSpec()) |
      forex(Raw::Stmt s | s = statementsOnly(b).getChild(_) | isNullStatement(s)) and
      kw = ["null_procedure_body", "null_procedure"]
    )
    or
    exists(Raw::SubpBody b, Raw::Stmt s, Call c | b = d and s = onlyStatement(b) |
      isFunctionSpec(b.getSubpSpec()) and
      c = s.(Raw::ReturnStmt).getReturnExpr() and
      (
        c.getTarget().getADeclaration() = b and kw = "self_calling_function"
        or
        c.getTarget().isFunction() and
        not c.getTarget().getADeclaration() = b and
        kw = "relay_function"
      )
      or
      not isFunctionSpec(b.getSubpSpec()) and
      c = s.(Raw::CallStmt).getCall() and
      (
        c.getTarget().getADeclaration() = b and kw = "self_calling_procedure"
        or
        not c.getTarget().getADeclaration() = b and kw = "relay_procedure"
      )
    )
    or
    d instanceof Raw::BodyStub and kw = "separate"
    or
    // generics and instantiations
    d instanceof Raw::GenericDecl and kw = "generic"
    or
    d instanceof Raw::GenericPackageDecl and kw = "generic_package"
    or
    exists(Raw::GenericSubpDecl g | g = d |
      isFunctionSpec(g.getSubpDecl().getSubpSpec()) and kw = "generic_function"
      or
      not isFunctionSpec(g.getSubpDecl().getSubpSpec()) and kw = "generic_procedure"
    )
    or
    d instanceof Raw::GenericInstantiation and kw = "instantiation"
    or
    d instanceof Raw::GenericPackageInstantiation and kw = "package_instantiation"
    or
    exists(Raw::GenericSubpInstantiation i | i = d |
      i.getKind() instanceof Raw::SubpKindFunction and kw = "function_instantiation"
      or
      i.getKind() instanceof Raw::SubpKindProcedure and kw = "procedure_instantiation"
    )
    or
    exists(Raw::FormalSubpDecl f, Raw::Expr def | f = d |
      isFunctionSpec(f.getSubpSpec()) and kw = "formal_function"
      or
      not isFunctionSpec(f.getSubpSpec()) and kw = "formal_procedure"
      or
      def = f.getDefaultExpr() and
      (
        def instanceof Raw::BoxExpr and
        if isFunctionSpec(f.getSubpSpec())
        then kw = "box_defaulted_formal_function"
        else kw = "box_defaulted_formal_procedure"
        or
        def instanceof Raw::Name and
        not def instanceof Raw::NullLiteral and
        if isFunctionSpec(f.getSubpSpec())
        then kw = "name_defaulted_formal_function"
        else kw = "name_defaulted_formal_procedure"
        or
        def instanceof Raw::NullLiteral and kw = "null_defaulted_formal_procedure"
      )
    )
    or
    d.getParent() instanceof Raw::GenericFormalPackage and kw = "formal_package"
    or
    d instanceof Raw::FormalTypeDecl and kw = "formal_type"
    or
    exists(Raw::ObjectDecl o | o = d and isGenericFormal(o) |
      exists(o.getDefaultExpr()) and kw = "defaulted_generic_parameter"
      or
      o.getMode() instanceof Raw::ModeInOut and kw = "in_out_generic_parameter"
    )
    or
    // packages
    d instanceof Raw::PackageDecl and kw = "package"
    or
    exists(Raw::PackageDecl p | p = d |
      hasNoDeclarations(p.getPublicPart()) and kw = "empty_visible_part"
      or
      hasNoDeclarations(p.getPrivatePart()) and kw = "empty_private_part"
    )
    or
    exists(d.(Raw::PackageBody).getStmts()) and kw = "package_statements"
    or
    exists(Raw::LibraryItem li | d = li.getItem() and li.getParent() instanceof Raw::CompilationUnit |
      d.(Raw::BasicDecl).getADefiningName().getName() instanceof Raw::DottedName and
      not d instanceof Raw::BodyNode and
      kw = "child_unit"
    )
    or
    // types
    (
      d instanceof Raw::TypeDecl and not d instanceof Raw::AnonymousTypeDecl
      or
      d instanceof Raw::TaskTypeDecl and not d instanceof Raw::SingleTaskTypeDecl
      or
      d instanceof Raw::ProtectedTypeDecl
      or
      d instanceof Raw::IncompleteTypeDecl
    ) and
    not d instanceof Raw::FormalTypeDecl and
    kw = "type"
    or
    d instanceof Raw::SubtypeDecl and kw = "subtype"
    or
    exists(Raw::TypeDecl t, Raw::TypeDef td |
      t = d and td = typeDef(t) and not t instanceof Raw::AnonymousTypeDecl
    |
      td instanceof Raw::AccessDef and kw = "access_type"
      or
      td instanceof Raw::AccessToSubpDef and kw = "access_subprogram_type"
      or
      td.(Raw::TypeAccessDef).getHasAll() instanceof Raw::AllPresent and kw = "access_all_type"
      or
      td.(Raw::TypeAccessDef).getHasConstant() instanceof Raw::ConstantPresent and
      kw = "access_constant_type"
      or
      exists(D::Type des |
        des = typeOf(td.(Raw::TypeAccessDef).getSubtypeIndication()) and
        des = TypeCategories::ultimateType(des)
      |
        des instanceof Raw::TaskTypeDecl and kw = "access_task_type"
        or
        des instanceof Raw::ProtectedTypeDecl and kw = "access_protected_type"
        or
        des.getDefinition().(Raw::ArrayTypeDef).getIndices() instanceof Raw::ConstrainedArrayIndices and
        kw = "access_constrained_array_type"
        or
        des.getDefinition().(Raw::ArrayTypeDef).getIndices() instanceof Raw::UnconstrainedArrayIndices and
        kw = "access_unconstrained_array_type"
      )
      or
      td instanceof Raw::ArrayTypeDef and kw = ["array", "array_type"]
      or
      td.(Raw::ArrayTypeDef).getIndices() instanceof Raw::ConstrainedArrayIndices and
      kw = "constrained_array_type"
      or
      td.(Raw::ArrayTypeDef).getIndices() instanceof Raw::UnconstrainedArrayIndices and
      kw = "unconstrained_array_type"
      or
      td.(Raw::ArrayTypeDef).getComponentType().getHasAliased() instanceof Raw::AliasedPresent and
      kw = "aliased_array_component"
      or
      td instanceof Raw::EnumTypeDef and kw = "enumeration_type"
      or
      (td instanceof Raw::OrdinaryFixedPointDef or td instanceof Raw::DecimalFixedPointDef) and
      kw = "fixed_type"
      or
      td instanceof Raw::OrdinaryFixedPointDef and kw = "ordinary_fixed_type"
      or
      td instanceof Raw::DecimalFixedPointDef and kw = "decimal_fixed_type"
      or
      td instanceof Raw::FloatingPointDef and kw = "float_type"
      or
      (td instanceof Raw::SignedIntTypeDef or td instanceof Raw::ModIntTypeDef) and
      kw = "integer_type"
      or
      td instanceof Raw::SignedIntTypeDef and kw = "signed_type"
      or
      td instanceof Raw::ModIntTypeDef and kw = "modular_type"
      or
      td instanceof Raw::InterfaceTypeDef and kw = "interface_type"
      or
      td instanceof Raw::RecordTypeDef and kw = "record_type"
      or
      td instanceof Raw::RecordTypeDef and
      (
        td.(Raw::RecordTypeDef).getHasTagged() instanceof Raw::TaggedPresent and
        kw = "tagged_type"
        or
        not td.(Raw::RecordTypeDef).getHasTagged() instanceof Raw::TaggedPresent and
        kw = "ordinary_record_type"
      )
      or
      td.(Raw::RecordTypeDef).getHasAbstract() instanceof Raw::AbstractPresent and
      kw = "abstract_type"
      or
      td.(Raw::PrivateTypeDef).getHasAbstract() instanceof Raw::AbstractPresent and
      kw = "abstract_type"
      or
      td.(Raw::DerivedTypeDef).getHasAbstract() instanceof Raw::AbstractPresent and
      kw = "abstract_type"
      or
      exists(Raw::BaseRecordDef r | r = recordDef(t) and isNullRecord(r) |
        td.(Raw::RecordTypeDef).getHasTagged() instanceof Raw::TaggedPresent and
        kw = "null_tagged_type"
        or
        td instanceof Raw::RecordTypeDef and
        not td.(Raw::RecordTypeDef).getHasTagged() instanceof Raw::TaggedPresent and
        kw = "null_ordinary_record_type"
        or
        td instanceof Raw::DerivedTypeDef and kw = "null_extension"
      )
      or
      exists(Raw::DerivedTypeDef dd | dd = td |
        exists(dd.getRecordExtension()) and kw = "extension"
        or
        dd.getHasWithPrivate() instanceof Raw::WithPrivatePresent and kw = "private_extension"
        or
        not exists(dd.getRecordExtension()) and
        not dd.getHasWithPrivate() instanceof Raw::WithPrivatePresent and
        kw = "derived_type"
      )
      or
      exists(Raw::PrivateTypeDef p | p = td |
        p.getHasLimited() instanceof Raw::LimitedPresent and kw = "limited_private_type"
        or
        not p.getHasLimited() instanceof Raw::LimitedPresent and kw = "non_limited_private_type"
        or
        p.getHasTagged() instanceof Raw::TaggedPresent and kw = "tagged_private_type"
      )
    )
    or
    exists(Raw::IncompleteTypeDecl t | t = d |
      t instanceof Raw::IncompleteTaggedTypeDecl and kw = "tagged_incomplete_type"
      or
      not t instanceof Raw::IncompleteTaggedTypeDecl and kw = "incomplete_type"
    )
    or
    // discriminants and records
    exists(Raw::DiscriminantPart dp |
      dp = [d.(Raw::TypeDecl).getDiscriminants(), d.(Raw::TaskTypeDecl).getDiscriminants(),
            d.(Raw::ProtectedTypeDecl).getDiscriminants()] and
      not d instanceof Raw::FormalTypeDecl
    |
      kw = "discriminant"
      or
      dp instanceof Raw::UnknownDiscriminantPart and kw = "unknown_discriminant"
      or
      exists(dp.(Raw::KnownDiscriminantPart).getDiscrSpecs().getChild(_).(Raw::DiscriminantSpec).getDefaultExpr()) and
      kw = "defaulted_discriminant"
      or
      d instanceof Raw::TaskTypeDecl and kw = "task_discriminant"
      or
      d instanceof Raw::ProtectedTypeDecl and kw = "protected_discriminant"
    )
    or
    isAnonymousAccess(d.(Raw::DiscriminantSpec).getTypeExpr()) and kw = "anonymous_access_discriminant"
    or
    exists(Raw::ComponentDecl c | c = d and c.getParent+() instanceof Raw::BaseRecordDef |
      c.getComponentDef().getHasAliased() instanceof Raw::AliasedPresent and
      kw = "aliased_record_component"
      or
      exists(c.getDefaultExpr()) and kw = "initialized_record_component"
      or
      not exists(c.getDefaultExpr()) and
      not isLimited(typeOf(c.getComponentDef().getTypeExpr())) and
      kw = "uninitialized_record_component"
    )
    or
    isAnonymousAccess(d.(Raw::ComponentDecl).getComponentDef().getTypeExpr()) and
    kw = "anonymous_access_component"
    or
    isAnonymousAccess(d.(Raw::ArrayTypeDef).getComponentType().getTypeExpr()) and
    kw = "anonymous_access_component"
    or
    d instanceof Raw::VariantPart and kw = "variant_part"
    or
    // objects
    exists(Raw::ObjectDecl o | o = d and not isGenericFormal(o) |
      isVariable(o) and
      (
        kw = "variable"
        or
        exists(o.getDefaultExpr()) and not isClassWide(o) and kw = "initialized_variable"
        or
        not exists(o.getDefaultExpr()) and
        not isLimited(typeOf(o.getTypeExpr())) and
        kw = "uninitialized_variable"
        or
        o.getHasAliased() instanceof Raw::AliasedPresent and kw = "aliased_variable"
        or
        isAnonymousAccess(o.getTypeExpr()) and kw = "anonymous_access_variable"
        or
        isClassWide(o) and kw = ["class_wide_variable", "tagged_variable"]
        or
        objectCategory(o) = ["()", "range", "mod", "digits", "delta"] and kw = "scalar_variable"
        or
        objectCategory(o) = "record" and kw = "ordinary_record_variable"
        or
        objectCategory(o) = ["tagged", "extension"] and kw = "tagged_variable"
        or
        objectCategory(o) = "task" and kw = "task_variable"
        or
        objectCategory(o) = "protected" and kw = "protected_variable"
      )
      or
      isConstant(o) and
      (
        kw = "constant"
        or
        not exists(o.getDefaultExpr()) and kw = "deferred_constant"
        or
        o.getHasAliased() instanceof Raw::AliasedPresent and kw = "aliased_constant"
        or
        isAnonymousAccess(o.getTypeExpr()) and kw = "anonymous_access_constant"
        or
        isClassWide(o) and kw = "class_wide_constant"
      )
      or
      o.getTypeExpr().(Raw::AnonymousType).getTypeDecl().getTypeDef() instanceof Raw::ArrayTypeDef and
      kw = ["array", "single_array"]
    )
    or
    d instanceof Raw::NumberDecl and kw = "named_number"
    or
    d instanceof Raw::ExceptionDecl and not exists(d.(Raw::ExceptionDecl).getRenames()) and
    kw = "exception"
    or
    exists(Raw::DefiningNameList ids |
      ids = [d.(Raw::ObjectDecl).getIds(), d.(Raw::NumberDecl).getIds(),
             d.(Raw::ExceptionDecl).getIds(), d.(Raw::ComponentDecl).getIds(),
             d.(Raw::ParamSpec).getIds(), d.(Raw::DiscriminantSpec).getIds()] and
      exists(ids.getChild(1)) and
      kw = "multiple_names"
    )
    or
    exists(Raw::EnumLiteralDecl e | e = d and e.getName().getName() instanceof Raw::CharLiteral |
      kw = "character_literal"
    )
    or
    // parameters
    exists(Raw::ParamSpec p | p = d and not exists(Raw::BasicDecl spec | ada_body_part(spec, p.getParent+())) |
      p.getMode() instanceof Raw::ModeInOut and kw = "in_out_parameter"
      or
      p.getMode() instanceof Raw::ModeOut and kw = "out_parameter"
      or
      exists(p.getDefaultExpr()) and kw = "defaulted_parameter"
      or
      isAnonymousAccess(p.getTypeExpr()) and kw = "anonymous_access_parameter"
    )
    or
    // tasks and protected
    (d instanceof Raw::TaskTypeDecl and not d instanceof Raw::SingleTaskTypeDecl or d instanceof Raw::SingleTaskDecl) and
    kw = "task"
    or
    d instanceof Raw::TaskTypeDecl and not d instanceof Raw::SingleTaskTypeDecl and kw = "task_type"
    or
    d instanceof Raw::SingleTaskDecl and kw = "single_task"
    or
    (d instanceof Raw::ProtectedTypeDecl or d instanceof Raw::SingleProtectedDecl) and kw = "protected"
    or
    d instanceof Raw::ProtectedTypeDecl and kw = "protected_type"
    or
    d instanceof Raw::SingleProtectedDecl and kw = "single_protected"
    or
    d instanceof Raw::EntryDecl and
    (
      kw = "entry"
      or
      d.getParent+() instanceof Raw::TaskDef and kw = "task_entry"
      or
      d.getParent+() instanceof Raw::ProtectedDef and kw = "protected_entry"
    )
    or
    exists(Raw::ProtectedDef pd |
      pd = [d.(Raw::ProtectedTypeDecl).getDefinition(), d.(Raw::SingleProtectedDecl).getDefinition()] and
      count(Raw::EntryDecl e | e.getParent+() = pd) > 1 and
      kw = "multiple_protected_entries"
    )
    or
    // handlers
    exists(Raw::HandledStmts hs | hs = d and exists(hs.getExceptions().getChild(_)) | kw = "handlers")
    or
    exists(Raw::ExceptionHandler h | h = d |
      handledName(h) = ["constraint_error", "numeric_error"] and
      not (handledName(h) = "constraint_error" and handledName(h) = "numeric_error") and
      kw = "non_joint_ce_ne_handler"
    )
  }

  /** Gets the simple name, lower-cased, of an exception handler `h` handles. */
  private string handledName(Raw::ExceptionHandler h) {
    result =
      h.getHandledExceptions().getChild(_).(Raw::Name).getText().regexpCapture("(?:.*\\.)?([^.]+)", 1).toLowerCase()
  }
}

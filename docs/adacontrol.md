# AdaControl parity

[AdaControl](https://www.adalog.fr/compo/adacontrol_ug.html) checks Ada code against a
coding standard written as rules (user guide V1.22r16c, 73 rules). This page says, rule
by rule, which query covers it, which of its subrules are implemented, which the query
checks by default, and which are left out. Progress is tracked in
[issue #73](https://github.com/peter-villadsen/codeql-ada/issues/73).

AdaControl is GPL. The queries here are written from its documented behaviour; none of
its code or tests are copied.

## How a rule is implemented

Almost every AdaControl rule is parameterised: entity lists, limits, patterns, a choice
of subrules. CodeQL queries take no parameters, so a rule is split in two:

- **A library**, `codeql/ada/adacontrol/<Rule>.qll`, with one predicate per subrule. Its
  parameters (an entity, a limit, a place) are the predicate's arguments.
- **A query**, `ql/src/queries/<Rule>.ql`, which calls the library with a fixed default
  configuration: the subrules and settings a typical coding standard asks for, chosen so
  that the query reports problems rather than every occurrence of a construct.

To check a rule your own way, write a query that calls the library with your settings
(see [Writing queries](query-writing.md)). Configuration through data extensions, so
that a team can write its standard as YAML instead, is
[issue #7](https://github.com/peter-villadsen/codeql-ada/issues/7). Every query carries
the tag `adacontrol`.

AdaControl's control kinds (`check`, `search`, `count`) correspond to a query's
`@problem.severity` and to whether you run it at all. Its `not` modifiers and lists of
exceptions become conditions in your query.

## Rules

### Abnormal_Function_Return

`ada/function-missing-return`. A function body whose statements can complete without a
`return`, and each exception handler of the function's body that can complete normally,
are reported separately. Decided along feasible control-flow paths, which is more precise
than AdaControl's rule on the shape of the last statement; a handler the control-flow
graph does not reach (it raises only at calls and `raise`, not at `10 / X`) is judged by
that shape instead: a `return`, a `raise`, a call that does not return, or a block, an
`if` with an `else`, a `case` or a plain `loop` without `exit` or `goto`, every branch of
which ends so.

### Actual_Parameters

`ada/actual-parameters`, library `ActualParameters`.

| Subrule | Library | Default |
|---|---|---|
| `default_used` | `defaultUsed(site, formal)` | no |
| `default_not_used` | `defaultNotUsed(site, formal, actual)` | no |
| `default_positional` | `defaultPositional(site, formal, actual)` | no: ~1,600 corpus results, mostly container instantiations given `"<"` by position |
| `entity` | `entityActual(site, formal, actual, entity, anywhere)` | all calls, all formals, `Ada.Unchecked_Conversion` |

A site is a `Call` or a `GenericInstantiation`; the formals of an instantiation are the
generic's formal objects and subprograms. Restrict `site` (by target) and `formal` (by
name) for AdaControl's `<place>` and `<formal>`; `anywhere = true` is AdaControl's
`all <entity>`. Left out: formal types with defaults (Ada 2022).

### Allocators

`ada/allocators`, library `Allocators`.

| Subrule | Library | Default |
|---|---|---|
| all allocators, or of a type (`<entity>`) | `allocates(a, t)`: `t` or a subtype of it | no |
| of a category | `allocatesCategory(a, category)` | no |
| `anonymous` | `isAnonymous(a)` | yes |
| `inconsistent` | `isInconsistent(a)` | yes |

`not` is a negation in your query. Categories (`codeql/ada/adacontrol/TypeCategories.qll`)
traverse derivations and privacy. A partial view (`type T;`, `type T is private;`) and its
full declaration count as the same subtype, paired by qualified name, since the extractor
does not pair type views. Left out: types declared in generics matched through their
instances.

### Aspects

`ada/aspects`, library `Aspects`.

| Subrule | Library | Default |
|---|---|---|
| all aspects | every `AspectAssoc`; `aspectMark(a)` is its mark (`Pre'Class`) | no |
| given aspect marks | `hasAspectMark(a, mark)`, ignoring case | no |
| `implicit_true` | `isImplicitTrue(a)` | yes |

AdaControl's `all` together with marks (the aspects not given) is a negation of
`hasAspectMark` in your query.

### Comments

`ada/comments`, library `Comments`. `ada/todo-comment` is a fixed `pattern`.

| Subrule | Library | Default |
|---|---|---|
| `pattern` | `matchesPattern(c, pattern)`: the text after `--` and spaces, ignoring case | no |
| `position` | `column(c)` | no |
| `terminating` | `isTerminating(c, allowBegin)`; allowed patterns are `matchesPattern` | no |
| `unnamed_begin` | `isUnnamedBegin(body, condition, minLines)` for `always`, `declaration`, `program_unit`; `unitKind(body)` is the `<unit_kind>` | no |
| `unnamed_end_record` | `isUnnamedEndRecord(t, maxLines)` | 10 lines |

Comments are not AST nodes: they are matched with code by file and line. A comment is
terminating when an AST node starts or ends before it on its line. Left out:
`terminating`'s `end` option (a line holding only an `end`), and AdaControl's `search`
and `check` with different `position` values (two queries).

### Declarations

`ada/declarations`, library `Declarations` (and `Places`). `declaration(d, kw)` holds for
each keyword that applies to `d`; several may apply, as in AdaControl. The query checks
`self_calling_function`, `self_calling_procedure` and `empty_private_part`, at all
places.

AdaControl's `<location>`s are `Places::isAt(n, place)`, shared with the other rules that
take them:

| Place | Meaning |
|---|---|
| `library` | no enclosing subprogram, task, entry, protected body or block |
| `local` | inside one of those |
| `block` | directly in a block's declarations |
| `own` | directly in a package body's declarations |
| `public`, `private` | directly in a package spec's visible or private part |
| `in_generic` | anywhere in a generic unit, its formal part, spec or body |
| `task_body` | directly in a task body's declarations |

`not <location>` and `ignore "<pattern>"` (on `getQualifiedName()`) are conditions in your
query.

Implemented (130 of 157): `abstract_function`, `abstract_operator`, `abstract_procedure`,
`abstract_type`, `access_all_type`, `access_constant_type`,
`access_constrained_array_type`, `access_protected_type`, `access_subprogram_type`,
`access_task_type`, `access_type`, `access_unconstrained_array_type`,
`aliased_array_component`, `aliased_constant`, `aliased_record_component`,
`aliased_variable`, `anonymous_access_component`, `anonymous_access_constant`,
`anonymous_access_discriminant`, `anonymous_access_parameter`,
`anonymous_access_variable`, `any_declaration`, `array`, `array_type`,
`box_defaulted_formal_function`, `box_defaulted_formal_procedure`, `character_literal`,
`child_unit`, `class_wide_constant`, `class_wide_variable`, `constant`,
`constrained_array_type`, `decimal_fixed_type`, `defaulted_discriminant`,
`defaulted_generic_parameter`, `defaulted_parameter`, `deferred_constant`,
`derived_type`, `discriminant`, `empty_private_part`, `empty_visible_part`, `entry`,
`enumeration_type`, `equality_operator`, `exception`, `expression_function`,
`extension`, `fixed_type`, `float_type`, `formal_function`, `formal_package`,
`formal_procedure`, `formal_type`, `function`, `function_instantiation`, `generic`,
`generic_function`, `generic_package`, `generic_procedure`, `handlers`,
`in_out_generic_parameter`, `in_out_parameter`, `incomplete_type`,
`initialized_record_component`, `initialized_variable`, `instantiation`,
`integer_type`, `interface_type`, `limited_private_type`, `modular_type`,
`multiple_names`, `multiple_protected_entries`, `name_defaulted_formal_function`,
`name_defaulted_formal_procedure`, `named_number`, `no_spec_function`,
`no_spec_procedure`, `non_joint_ce_ne_handler`, `non_limited_private_type`,
`null_defaulted_formal_procedure`, `null_extension`, `null_ordinary_record_type`,
`null_procedure`, `null_procedure_body`, `null_procedure_declaration`,
`null_tagged_type`, `operator`, `ordinary_fixed_type`, `ordinary_record_type`,
`ordinary_record_variable`, `out_parameter`, `package`, `package_instantiation`,
`package_statements`, `private_extension`, `procedure`, `procedure_instantiation`,
`protected`, `protected_discriminant`, `protected_entry`, `protected_type`,
`protected_variable`, `record_type`, `relay_function`, `relay_procedure`,
`scalar_variable`, `self_calling_function`, `self_calling_procedure`, `separate`,
`signed_type`, `single_array`, `single_protected`, `single_task`, `subtype`,
`tagged_incomplete_type`, `tagged_private_type`, `tagged_type`, `tagged_variable`,
`task`, `task_discriminant`, `task_entry`, `task_type`, `task_variable`, `type`,
`unconstrained_array_type`, `uninitialized_record_component`,
`uninitialized_variable`, `unknown_discriminant`, `variable`, `variant_part`.

Left out: `access_def_discriminated_type`, `access_nondef_discriminated_type`,
`access_unknown_discriminated_type`, `access_formal_type`, `access_language_type`,
`aliased_protected_component`, `initialized_protected_component`,
`uninitialized_protected_component`, the `anonymous_subtype_*` family,
`binary_modular_type` and `non_binary_modular_type` (need the modulus's value),
`constrained_array_constant`, `constrained_array_variable`,
`unconstrained_array_constant`, `unconstrained_array_variable`,
`unconstrained_subtype`, `constructor`, `controlled_type`, `non_ravenscar_task`,
`ordinary_fixed_type_no_small`, `ordinary_fixed_type_with_small`,
`predefined_operator`, `relay_package`; and the variable `Limited_Initialization`
(`uninitialized_variable` and `uninitialized_record_component` never report limited
types).

### Dependencies

`ada/dependencies`, library `Dependencies`.

| Subrule | Library | Default |
|---|---|---|
| `with` | `withOf(cu, withName, unit)`, through renamings and to the generic of an instance | no |
| `others` | `withOf` with the allowed units negated in your query | no |
| `public_child`, `private_child` | `dependsOnOwnChild(cu, withName, isPrivate)` | yes |
| `raw` | `rawCount(cu)` | no |
| `direct` | `directCount(cu)`: a child unit's parents counted | no |
| `parent` | `parentCount(cu)` | no |

Left out: AdaControl's semantic dependencies of `others` beyond `with` clauses (a child's
parent units are counted by `direct` only).

### Derivations

`ada/derivations`, library `Derivations`.

| Subrule | Library | Default |
|---|---|---|
| `from` an entity | `derivesFrom(t, ancestor)`: a type, a subtype of it, or a unit declaring the parent | no |
| `from` a category | `derivesFromCategory(t, category)`, derivations traversed, privacy not | no |
| `max_parents` | `parentCount(t)`: the parent and the progenitors | no |
| `max_depth` | `depth(t)` | no |
| `indicator` | `missingIndicator(s, d, expected, onBody)`, `indicatorOnBody(s, d)` | `overriding`, tagged, declarations |

A primitive overrides when an ancestor (parent or progenitor, at any depth) has a
primitive function or procedure of the same name and number of parameters, controlled by
the same parameter. Left out: `indicator` on untagged types, and types derived in
generics followed into their instances.

### Entities

`ada/entities`, library `Entities` (and `Places`).
`ada/unchecked-conversion` and `ada/unchecked-deallocation` are two fixed entities.

| Subrule | Library | Default |
|---|---|---|
| an entity | `uses(n, entity, false)`: by its name or a renaming | no |
| `instance` | `uses(n, entity, true)`: through an instance of generic `entity` | no |
| `all '<attribute>` | `usesAttribute(a, name)` | `'Unchecked_Access`, `'Unrestricted_Access` |
| places | `Places::useIsAt(n, place)`: `block`, `library`, `local`, `nested`, `own`, `public`, `private`, `in_generic`, `task_body` | all |

Left out: entities declared inside a generic, followed into each instance (a use through
an instance resolves to the generic's declaration, so `uses` finds it as a use of the
generic's entity).

### Entity_Inside_Exception

`ada/entity-inside-exception`, library `EntityInsideException`.

| Subrule | Library | Default |
|---|---|---|
| an entity | `referenceIn(n, handler, entity)`, through renamings | no |
| `calls` | `callIn(call, handler)`: subprogram and entry calls | no |
| `entry_calls` | `entryCallIn(call, handler)` | yes |

`not <entity>` is a negation in your query.

### Expressions

`ada/expressions`, library `Expressions`. `expression(e, kw)` holds for each keyword
that applies to `e`; `typeCategory(e)` gives the category of `e`'s type for AdaControl's
`<category>` prefixes (derivations traversed). `ada/float-equality` is a fixed
`real_equality`.

The query checks the unary case of `mixed_operators` (`-A mod B`, `-A rem B`). The binary
case reports every `A + B * C` and `X > 0 and Y > 0`: 4,589 corpus results.

Implemented (50 of 60): `and`, `and_array`, `and_binary`, `and_boolean`, `and_then`,
`array_aggregate`, `array_named_others`, `array_others`, `array_partial_others`,
`array_positional_others`, `array_range`, `case`, `complex_parameter`,
`downward_conversion`, `dynamic_function_call`, `explicit_dereference`,
`extension_aggregate`, `fixed_multiplying_op`, `for_all`, `for_some`, `function_call`,
`if`, `if_elsif`, `if_no_else`, `in`, `mixed_operators`, `not`, `not_in`, `or`,
`or_array`, `or_binary`, `or_boolean`, `or_else`, `parameter_view_conversion`,
`prefixed_operator`, `real_equality`, `record_aggregate`, `record_others`,
`record_partial_others`, `slice`, `target_name`, `trivial_target_name`,
`type_conversion`, `underived_conversion`, `unqualified_aggregate`, `upward_conversion`,
`xor`, `xor_array`, `xor_binary`, `xor_boolean`.

Left out: `dispatching_function_call`, `redispatching_function_call`,
`inherited_function_call`, `implicit_dereference`, `inconsistent_attribute_dimension`,
`extendable_aggregate`, `array_non_static_range`, `static_membership` and
`universal_range` (these three need static evaluation),
`unconverted_fixed_multiplying_op`; the two-category form of the conversion subrules (a
condition on the operand's and the result's `typeCategory` in your query), and the
variable `Called_Info`.

### Header_Comments

`ada/header-comments`, library `HeaderComments`.

| Subrule | Library | Default |
|---|---|---|
| `minimum` | `headerLineCount(cu)`: comment lines before the first unit of a file; `headerLine(cu, i)` | 1 line |
| `model` | `Model<model>::mismatch(cu, i)`, `firstMismatch(cu)`, with `string model(int i)` the `i`th line's regular expression | no |

A model line matches part of the comment line unless anchored with `^` and `$`, as in
AdaControl. Left out: the model's repetitions (`{min,max}`, `*`, `+`, `?`), and
AdaControl's disabling comments.

### Instantiations

`ada/instantiations`, library `Instantiations` (and `Places`).

| Subrule | Library | Default |
|---|---|---|
| a generic | `instantiates(inst, generic)`, through generic renamings | `Ada.Unchecked_Conversion`, `Ada.Unchecked_Deallocation` |
| an actual entity | `actualIs(inst, i, entity, subtypes)`; `subtypes` is `Type_Matches_Subtype` | no |
| an actual category | `actualIsOfCategory(inst, i, category)`, derivations and privacy not traversed | no |
| `=` | `repeats(inst, positions, previous)`, positions `"0"`, `"1"`, `"0,1"`, `"0,1,2"` | `=, =` |
| `<>` | leave the position out | |
| places | `Places::isAt(inst, place)` | all |

"Earlier" for `=` is by file name and position. Left out: `=` on formal `in` parameters
(AdaControl compares static values; here the actual must be a name).

### Insufficient_Parameters

`ada/insufficient-parameters`, library `InsufficientParameters`:
`Make<enumerationType>::insufficientActual(call, actual)` and `insufficientCount(call)`,
with the enumeration types as a predicate. The query uses `Standard.Boolean` and a
maximum of 1. An actual is insufficient when given by position and made only of numeric
literals and literals of the listed enumerations; operators are not checked.

### Local_Hiding

`ada/local-hiding`, library `LocalHiding`.

| Subrule | Library | Default |
|---|---|---|
| `strict` | `hides(inner, outer)`: the nearest declaration of the same name in an enclosing region; two subprograms overload rather than hide | yes, `not_different_families` |
| `overloading` | `overloads(inner, outer)`: a subprogram or enumeration literal of the same name in the same or an enclosing region | no |
| `not_operator` | `isOperator(d)` | |
| `not_enumeration` | `Raw::EnumLiteralDecl` | |
| `not_identical_renaming` | `isIdenticalRenaming(d)` | |
| `not_different_families` | `family(d)`: data, type, subprogram, package, generic, exception, label | |

Regions are packages (spec and body together), subprogram, task, entry and protected
bodies, blocks, loops and generic formal parts; a subprogram body's parameters are in its
region. Allowed patterns are a condition on `getAName()` in your query. Left out: names
declared in a parent unit and hidden in a child unit, the variable
`Overloading_Report`.

### Max_Expression_Items

`ada/max-expression-items`, library `MaxExpressionItems`: `items(e)` of each whole
expression (`isWhole(e)`). A primary counts 1: a name, a literal, a call, an aggregate,
an `if` or `case` expression; operators and parentheses add their operands; what is
inside a call or an aggregate is counted as an expression of its own. The query's limit
is 20 (AdaControl's `check` example).

### Max_Nesting

`ada/max-nesting`, library `MaxNesting`: `depth(n, kind)`, the number of constructs of
`kind` around `n`, for `all` (packages, subprogram bodies, generics, tasks, protected
units, entry bodies, blocks), `generic` and `task`. The query checks `all` with 7
(AdaControl's `check` example). Left out: `separate` (the nesting of subunits).

### Max_Primitives

`ada/max-primitives`, library `MaxPrimitives`: `isPrimitive(s, t, visible)`,
`visibleCount(t)` and `totalCount(t)`. A primitive is a subprogram declared in the same
package spec as `t` with a parameter or the result of type `t`; `tagged` and
`untagged` are `t.isTagged()` in your query. The query checks `visible, 30`. Left out:
inherited primitives, and tasks and protected types.

### Max_Size

`ada/max-size`, library `MaxSize`: `isElement(n, kind)` for every AdaControl kind
(`accept`, `block`, `simple_block`, `unnamed_block`, `loop`, `unnamed_loop`, `if`,
`if_branch`, `case`, `case_branch`, `package_spec`, `package_body`, `procedure_body`,
`function_body`, `protected_spec`, `protected_body`, `entry_body`, `task_spec`,
`task_body`, `unit`), and `lines(n)`. The query checks `procedure_body` and
`function_body` with 200 lines.

### Max_Statement_Nesting

`ada/max-statement-nesting`, library `MaxStatementNesting`: `depth(s, kind)` for `block`,
`case`, `if`, `loop` (statements of that kind only) and `all` (any compound statement,
`select`, `accept` and extended `return` included), within the statement's body. The
query checks `all, 5` and reports the outermost statement too deep, not each one inside
it.

### Naming_Convention

`ada/naming-convention`, library `NamingConvention`.

- `kind(dn)` is the most specific of AdaControl's filter kinds for a defining name,
  `parentKind(k, parent)` the hierarchy, and `appliesTo(dn, k)` holds for the kind and
  every kind above it, up to `all`.
- `location(dn)` is `unit`, `global` or `local`.
- `Convention<rule>::violates(dn, k, pattern)` checks names against
  `rule(kind, pattern, positive, caseSensitive)`: a name must match one of its kind's
  positive patterns, if there are any, and none of the negative ones.

The query checks `all` with the case-sensitive pattern
`^[A-Z0-9][A-Za-z0-9]*(_[A-Z0-9][A-Za-z0-9]*)*$`: every word starts with a capital
letter or a digit, so acronyms (`GPR2_Path`) pass. Only the identifier is checked, not
the parent units of a child unit's name; operators and character literals are not
checked, nor bodies and their parameters when there is a spec.

Left out: `regular_static_constant` and `regular_nonstatic_constant` (constants are
`regular_constant`), `class_type`, the modifiers `root` and `others`, `<type_spec>`
(a condition on the entity's type in your `rule`), pattern files, and the variable
`Default_Case_Sensitivity`. Subtypes and derived types take the kind of the type they
derive from; incomplete types are not checked.

### Not_Selected_Name

`ada/not-selected-name`, library `NotSelectedName`: `simpleReference(id, entity)` (not
the selector of a dotted name, a defining name, an `end` name, or the formal of a named
association), `allowedAt(id, entity, place)` and `notSelected(id, entity, place)` for the
exception places `none`, `unit`, `compilation` and `family`. The query checks types
named `Object`, `Instance` or `T` with `unit`, after AdaControl's tip. Left out: a
prefix that itself must be selected ("only one level of prefix is required, unless the
prefix itself is the target of a rule").

### Object_Declarations

`ada/object-declarations`, library `ObjectDeclarations`.

| Subrule | Library | Default |
|---|---|---|
| `min_integer_span` | `integerSpan(d)`, where the range has literal bounds | no |
| `type` | `hasType(d, t, exact)`: `t` or a subtype of it | no |
| `volatile_no_address` | `volatileNoAddress(d)` | no |
| `address_not_volatile` | `addressNotVolatile(d)` | yes |

`constant` and `variable` are `isObject(d, isConstant)`. Volatile means a `Volatile`,
`Atomic` or `Volatile_Full_Access` aspect or pragma; an address an `Address` aspect, an
attribute definition clause or an `at` clause. Left out: `not_required_type`, and
`min_integer_span` for bounds that are not literals (they need static evaluation).

### Parameter_Declarations

`ada/parameter-declarations`, library `ParameterDeclarations`:
`parameterCount(c, subrule)` for `all_parameters`, `in_parameters`, `out_parameters`,
`in_out_parameters`, `defaulted_parameters`, `access_parameters`, `tagged_parameters`
and `class_wide_parameters`; `singleOutParameter(c, noInout)`; and `callableKind(c)`
(`function`, `procedure`, `dispatching_function`, `dispatching_procedure`,
`protected_function`, `protected_procedure`, `protected_entry`, `task_entry`). A
callable is a subprogram spec, a body without one, a generic subprogram or an entry;
generic formal subprograms are not checked. The query checks `all_parameters, max 10`
(AdaControl's `check` example). Left out: instantiations (counted from the generic in
AdaControl).

### Positional_Associations

`ada/positional-associations`, library `PositionalAssociations`:
`associations(site, list, kind)` for the kinds `call`, `discriminant`, `pragma`,
`record_aggregate`, `array_aggregate`, `instantiation` and
`enumeration_representation`; `isPositional(list, assoc)`; and the counts of the
subrules: `allCount(list)` (`all`), `positionalCount(list)` (`all_positional`),
`sameTypeCount(list)` (`same_type`) and `declaredCount(site)` (`declared`, for calls).
Infix operators and attributes are not calls here; `not_operator` is
`isPrefixedOperator(site)`. The query checks `same_type, 3, call`. Left out: `declared`
for instantiations, and exempted entities (a condition on the target in your query).

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
[issue #7](https://github.com/peter-villadsen/codeql-ada/issues/7). The mechanism exists
and one query uses it, `ada/cyclomatic-complexity` (user guide, "Configuring queries");
the AdaControl rules do not yet. Every query carries
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

### Pragmas

`ada/pragmas`, library `Pragmas`: `pragmaName(p)` (given pragmas and `all`),
`isStandard(name)` (the pragmas of the Ada 2022 RM, Annexes J and L), `isNonstandard(p)`
(`nonstandard`) and `isMultiple(p)` (`multiple`: an argument names an overloaded entity,
declared more than once in the same declarative part; not for the assertion pragmas,
whose argument is evaluated). `not` is a negation in your query.

The query checks `multiple all`. `nonstandard` reports every GNAT and SPARK pragma
(`Warnings`, `Unreferenced`, `Loop_Invariant`, ...): 1,218 corpus results.
`ada/pragma-suppress`, `ada/warnings-off` and `ada/spark-mode-off` are three fixed
pragmas.

### Record_Declarations

`ada/record-declarations`, library `RecordDeclarations` (on `Component`):

| `component` condition | Library |
|---|---|
| of a type (or its subtypes) | `isOfType(c, t, exact)` |
| of a category | `isOfCategory(c, category)`, derivations traversed, privacy not |
| `in_variant` | `inVariant(c)` |
| `initialized` | `isInitialized(c)` |
| `sized` | `isSized(c)`: a component clause applies |
| `aligned` | `isAligned(c)`: no component clause, or its first bit (when literal) a multiple of 8 |
| `packed` | `isPacked(c)`: `Pack` applies to the component's type |

`not` is a negation in your query. The query checks `component, (), not initialized`
(AdaControl's example; Boolean is an enumeration). Left out: discriminants, which
AdaControl counts as components, and a storage unit other than 8 bits.

### Renaming_Declarations

`ada/renaming-declarations`, library `RenamingDeclarations` (and `Places`):
`isRenaming(d)`, `renamed(d)`, `kind(d)` (`object`, `function_call`, `procedure`,
`function`, `package`, `exception`) and `hasFilter(d, filter)` for `identical`,
`generic`, `as_body`, `operator`, `as_operator`, `synonym`, `library_unit` and
`renaming`; places are `Places::isAt(d, place)`. A `synonym` is a renaming in the same
declarative part as what it renames, not of a function call's result nor a renaming as
body. The query checks `synonym all`.

### Representation_Clauses

`ada/representation-clauses`, library `RepresentationClauses`:
`representation(c, kw)` for `at`, `at_mod`, `enumeration`, `layout`,
`no_bit_order_layout`, `incomplete_layout`, `overlay`, `fractional_size` and
`non_power2_size` (literal sizes), and `'<attribute>` for each attribute definition
clause (`'size`, `'address`, `'class'input`, ...); `isGlobal(c)` and `isForObject(c)`
are the modifiers `global` and `object`; `target(c)` is the entity the clause applies
to, for categories. The query checks `incomplete_layout`. Left out:
`non_aligned_component` and `non_contiguous_layout` (they need component sizes), and
representation aspects (`with Size => 8`) other than `Bit_Order`.

### Return_Statements

`ada/return-statements`, library `ReturnStatements`: `callable(r)` (the subprogram body,
entry body or accept statement a return leaves) and `callableKind(c)` (`procedure`,
`function`, `entry`); `depth(r)` (compound statements around it, blocks included);
`regularCount(c)` (`regular_count`) and `handlerCount(c, h)` (`handler_count`, per
handler; a block's handlers count on their own, its statements with the enclosing
callable or handler). `min` and `max` are comparisons in your query. The query checks
`regular_count, max 5`.

### Return_Type

`ada/return-type`, library `ReturnType`: `returnsKind(f, kind)` for `anonymous_access`,
`class_wide`, `limited_class_wide`, `constrained_array`, `unconstrained_array`,
`unconstrained_discriminated`, `task` and `protected` (a type with a task or protected
component, at any depth, counts), and `returnsType(f, t, exact)` for `type <entity>`.
The query checks `anonymous_access`.

### Silent_Exceptions

`ada/silent-exceptions`, library `SilentExceptions`. `Make<isReport>::isSilent(h)` holds
when some path through handler `h` passes no report item, with `isReport` your report
items: `isReportOfKind(s, kind)` for `explicit_raise`, `reraise`, `return` and
`requeue`, and `callsReporting(s, entity)` for reporting subprograms. As in AdaControl,
reporting must be written in the handler: an `if` reports when every branch does, a
`case` when every alternative does, a block when its statements do; a loop's body does
not count. `handlesOthers(h)` and `handles(h, e)` select the exceptions (`with`, `not`,
`others`).

The query checks `with others`, with `raise`, `return`, `requeue` and any procedure call
(standing for the reporting procedures a team would list) as report items; handlers of
only `null` are left to `ada/exception-swallowing`. Left out: exceptions of a library
unit given as a unit, and generic packages as report items.

### Statements

`ada/statements`, library `Statements`. `statement(s, kw)` holds for each keyword that
applies to `s`; `othersHandler(h, kw)` gives `exception_others` and
`exception_others_null`. The query checks `backward_goto` and `case_others_null`.
`ada/goto-statement`, `ada/raise-predefined-exception` and `ada/empty-loop-body` are
fixed `goto`, `raise_standard` and `null_loop_body`.

Implemented: `any_statement`, `abort`, `accept`, `accept_return`, `assignment`,
`asynchronous_select`, `backward_goto`, `block`, `case`, `case_others`,
`case_others_null`, `conditional_entry_call`, `declare_block`, `delay`, `delay_until`,
`dynamic_procedure_call`, `effective_declare_block`, `entry_call`, `entry_return`,
`exception_others`, `exception_others_null`, `exit`, `exit_expanded_name`,
`exit_for_loop`, `exit_outer_loop`, `exit_plain_loop`, `exit_while_loop`,
`extended_return`, `for_in_loop`, `for_iterator_loop`, `for_loop`, `for_of_loop`,
`function_return`, `goto`, `goto_not_continue`, `if`, `if_elsif`, `labelled`,
`loop_return`, `multiple_exits`, `named_exit`, `no_else`, `null`, `null_case_path`,
`null_if_path`, `null_loop_body`, `procedure_call`, `procedure_return`, `raise`,
`raise_locally_handled`, `raise_nonpublic`, `raise_standard`, `requeue`, `reraise`,
`selective_accept`, `simple_block`, `simple_loop`, `terminate`, `timed_entry_call`,
`unconditional_exit`, `unnamed_block`, `unnamed_exit`, `unnamed_for_loop`,
`unnamed_loop_exited`, `unnamed_multiple_loop`, `unnamed_simple_block`,
`unnamed_simple_loop`, `unnamed_while_loop`, `untyped_for`, `untyped_for_in`,
`untyped_for_of`, `while_loop`.

Left out: `code`, `dispatching_call`, `redispatching_call`, `inherited_procedure_call`,
`exited_extended_return`, `hard_bounds_array_for_loop`, `multi_for_of_loop`,
`raise_foreign`, and the variables `Called_Info` and `Small_Loop_Length`.

### Type_Initial_Values

`ada/type-initial-values`, library `TypeInitialValues`: `isChecked(t)` (type declarations;
a private type stands for its full view), `initialConstant(t, c)` (a constant of the type,
or a view of it, in the same declarative part; a package's visible and private parts are
one) and `lacksInitialValue(t, pattern)`. The query checks record and private types with
any constant; other types and a name pattern (`"^C_Init_"`) are for a query of your own.

### Unit_Pattern

`ada/unit-pattern`, library `UnitPattern`:

| Subrule | Library | Default |
|---|---|---|
| `single_tagged_type` | `secondTaggedType(p, t, first)` | yes |
| `tagged_type_hierarchy` | `breaksHierarchy(t, parent)` | no: 95 corpus results, mostly extensions of `Ada.Finalization.Controlled` |
| `context_clauses_order` | `Order<group>::outOfOrder(contextClauses(cu), e)`, kinds `clauseKind` | no |
| `declarations_order` | `Order<group>::outOfOrder(declarations(part, target), e)`, kinds `declarationKind` | no |

`group(kind)` gives the position of the group a kind belongs to; a kind in no group is not
allowed. Left out: the `own`, `public` and `private` places of body declarations, and
`others` (give every remaining kind the last group). An element whose kind is in several
groups is taken at its first.

### Units

`ada/units`, library `Units`: `isLibraryUnit(d)` and `isUnreferenced(d)` (`unreferenced`:
no unit withs it, through renamings and instances, and it has no child unit). The query
checks packages; a library subprogram nobody withs is usually a main program. AdaControl's
`unchecked` (units withed but not analyzed) is a property of the extraction, not of the
code: the extractor's diagnostics report the units it could not find.

### Use_Clauses

`ada/use-clauses`, library `UseClauses`: `controlled(u, n, subrule)` for `package`,
`global`, `local`, `type`, `type_global`, `type_local`, `all_type`, `all_type_global` and
`all_type_local`; `clauseKind(u)` and `isGlobal(u)`. The packages and types to allow are
a condition on `n` in your query. The query checks `global` (AdaControl's example).

### With_Clauses

`ada/with-clauses`, library `WithClauses`. `ada/unused-with-clause` is the unused part of
`reduceable`.

| Subrule | Library | Default |
|---|---|---|
| `multiple_names` | `hasMultipleNames(w)` | no |
| `reduceable`, redundant | `isRedundant(cu, withName, earlier)`: twice in a unit, or in the spec and again in the body | yes |
| `reduceable`, an ancestor | `withsAncestor(cu, withName)` | yes |
| `reduceable`, movable | `isMovable(cu, withName, to)`: to the body, or to a `private with` | no |
| `inherited` | `inheritsWith(cu, n, unitCu)` | no |
| `limited`, `private`, `limited_private` | `withKind(w)` | no |

Left out: the variables `Check_Private_With` and `Ignore_Use_Clause` (use clauses never
count as a use here), and subunits for `inherited`.

### Simplifiable_Statements

`ada/simplifiable-statements`, library `SimplifiableStatements`. `simplifiable(s, subrule)`
holds for each subrule that applies to `s`, with the modifiers as their own names
(`no_exit loop_for_while`, `no_exit while_for_for`); `forInForForOf(l, arr, fullRange)`
gives `full_range`.

| Subrule | Default |
|---|---|
| `block` (no name, declarations or handlers) | yes |
| `dead`: static `False` conditions, paths after a `True` one, a repeated `elsif` condition, static empty `for` ranges | yes |
| `dead`: statements after `return`, `requeue`, `goto`, `raise`, an unconditional `exit` (`deadAfterJump`) | no: `ada/unreachable-statement` reports them |
| `for_in_for_for_of` | yes |
| `for_for_slice` | yes |
| `handler` (only `raise;`, unless a non-trivial `when others` follows) | yes |
| `if` (an `else` of only `null`) | yes |
| `if_for_case` | yes |
| `if_not` | no: 298 corpus results, a style preference |
| `loop` (`while True`) | yes |
| `loop_for_while` | yes |
| `nested_path` | no: 417 corpus results, a style preference |
| `null` (among other statements, not labelled) | yes |
| `true_if` | yes |
| `unnecessary_if` | yes |
| `while_for_for` | yes |

Static means the literals `True` and `False` (possibly negated) and integer literals.
`while_for_for` requires the step to be a statement of the loop body itself, not of a
branch in it, which AdaControl does not; that is the `While_For_Expression => any`
setting otherwise. Left out: `dead` for `case` branches over null ranges, the variables
`Acceptable_Dead_Case` and `Acceptable_Indexings`, and the other values of
`While_For_Expression`. `ada/useless-if` and `ada/empty-loop-body` are related fixed
checks.

### Terminating_Tasks

`ada/terminating-tasks`, library `TerminatingTasks`: `isTerminating(t, reason)` for a task
body that can terminate because its statements can complete (`completesNormally(t)`, the
normal exit reached along a feasible path), because an explicit `raise` propagates out of
it (`raisesOut(t)`: an unhandled exception ends a task silently), or because it has a
`terminate` alternative (`terminateAlternative(t)`).

AdaControl judges by the shape of the last statement (not an unconditional loop, or a loop
that is exited); the control-flow graph decides it here, so a loop left only by a `goto`,
or a `raise` caught by a handler inside the loop, is judged by where control can really
go. Exceptions that calls may raise are not followed (every call may raise), nor aborts,
as in AdaControl.

### Case_Statement

`ada/case-statement`, library `CaseStatement`:

| Subrule | Library | Default |
|---|---|---|
| `paths` | `paths(c)` | no |
| `values` | `values(c)` | no |
| `values_if_others` | `valuesIfOthers(c)` | no |
| `others_span` | `othersSpan(c)` | `min 1`: a `when others` that covers no value |
| `range_span` | `rangeSpan(c, range)` | no |

`<category>` is `selectorCategory(c)`; `min` and `max` are comparisons in your query. The
counts need static values: integer, character and enumeration literals, named numbers,
`2 ** N`, and ranges and subtypes made of them; `Standard.Character` has 256 values.
Where a bound or a choice is anything else (a selector of type `Integer`, whose bounds
exceed QL's integers, a constant, an expression), the count is unknown and nothing is
reported: on gpr2, 31 of the 209 `case` statements with `when others` get an
`others_span`. Left out: static predicates, and values beyond 2^30.

### Simplifiable_Expressions

`ada/simplifiable-expressions`, library `SimplifiableExpressions`.
`simplifiable(e, subrule)` holds for each subrule that applies to `e`.

| Subrule | Default |
|---|---|
| `conversion` (of a universal value, to the operand's subtype or its first subtype) | yes |
| `if_not` | no: 103 corpus results, a style preference |
| `logical_true`, `logical_false` | no: `ada/boolean-literal-comparison` reports them |
| `logical_redundant` | yes |
| `logical_not` | yes |
| `membership` (equalities and `in` joined by `or`; inequalities and `not in` by `and`) | yes |
| `parentheses` | no: 427 corpus results, a style preference |
| `range` (`T'First .. T'Last`) | yes |

`parentheses` follows the precedence levels of Ada RM 4.5 (`precedence(e)`) and, as
AdaControl does, does not report parentheses between operators of the same level. Left
out: `membership` for range comparisons (`X >= A and X <= B`).

### Local_Access

`ada/local-access`, library `LocalAccess`: `localAccess(a, entity, category)` for an
`'Access`, `'Unchecked_Access` or `'Unrestricted_Access` attribute `a` whose prefix
designates `entity`, which is not global, of category `category`.

| Subrule | Library | Default |
|---|---|---|
| `constant`, `variable` | `category(e)`: an `in` parameter is a constant, an `out` or `in out` one a variable | yes |
| `procedure`, `function` | `category(e)` | yes |
| `protected_procedure`, `protected_function` | `category(e)` | yes |

The entity is `entity(prefix)`: what the prefix names, through renamings; for a component
(`R.Field'Access`) or an element (`A (I)'Access`), the object it belongs to. Through a
dereference (`P.all'Access`, `P.Field'Access` with `P` an access value) the designated
object is unknown and nothing is reported. Global is `isGlobal(e)`: declared at library
level, in packages only; a parameter never is. The components and subprograms of a
protected type are judged by where the type is declared, not by the object. With all
categories, `ada/local-access` also reports what `ada/entities` reports for
`'Unchecked_Access` and `'Unrestricted_Access` of local entities.

### Barrier_Expressions

`ada/barrier-expressions`, library `BarrierExpressions`: `construct(n, b, kw)` for each
part `n` of the barrier of entry body `b` other than a Boolean component of the protected
object or a literal, with `kw` the keyword that allows it.

| `<keyword>` | What `construct` finds | Default |
|---|---|---|
| `allocation` | allocators | reported |
| `any_component` | protected components not of a Boolean type | allowed |
| `any_variable` | objects declared outside the protected object, constants included | reported |
| `arithmetic_operator` | predefined `+`, `-`, `*`, `/`, `mod`, `rem`, `**`, `abs`, `&` | reported |
| `array_aggregate`, `record_aggregate` | aggregates, by their type | reported |
| `comparison_operator` | predefined comparisons and membership tests | allowed |
| `conversion` | type conversions and qualified expressions | reported |
| `dereference` | `.all`, and selecting, indexing or calling through an access value | reported |
| `indexing` | indexing and slices | reported |
| `function_attribute` | attributes with arguments (`'Succ (X)`, `'Image (X)`) | reported |
| `local_function` | calls of functions of the same protected object | reported |
| `logical_operator` | predefined `and`, `or`, `xor`, `not`, `and then`, `or else` | allowed |
| `value_attribute` | attributes without arguments (`'Count`, `'First`) | allowed |
| `<entity>` | `call`: other function calls and user-defined operators; name the function in your query | reported |

The default allows what Ada 2022's `Pure_Barriers` restriction (the Jorvik profile)
allows, a little more liberally (any value attribute, not only `'Count`); AdaControl's own
default, Ravenscar's `Simple_Barriers`, is the query with no keyword allowed. Named
numbers and the index of an entry family are always allowed. Conditional, quantified and
declare expressions are not constructs of their own; their parts are checked.

### Assignments

`ada/assignments`, library `Assignments`. A group is a run of assignment statements with
nothing but `null` statements between them (`groupStart(s)`, `before(a, b)`). For
`repeated` and `groupable`, only targets known statically count (`isStaticTarget(n)`): a
variable, a component of one, or an element at static indices (literals, enumeration
literals, named numbers, constants). A dereference or a slice never counts.

| Subrule | Library | Default |
|---|---|---|
| `type`, `component`, `ancestor` | `assignsType(site, t, component)` for assignments and initialized object declarations; `isOfType(t, wanted, ancestor)` | no |
| `sliding` | `sliding(a, targetFirst, valueFirst)` | yes |
| `access_duplication`, `controlled` | `accessDuplication(site, value, controlled)`; `designatedTypeOf(value)` for a `<target>` | no |
| `repeated` | `repeated(first, second)` | when the target is not read in between (`readBetween`) |
| `groupable` | `groupable(start, object, t, given, total)`; `passes(given, total, minGiven, maxMissing, minRatio, maxTotal)` for the filters | every component, at least two (`missing 0`, `given 2`), when the group does not read the object (`groupReads`) |
| `possible_target_name`, `trivial` | `possibleTargetName(a, sub, trivial)`; `nameComponents(n)` for `<max length>` | no |

`repeated` gives each assignment and the latest earlier one to the same target in its
group. AdaControl reports them whatever happens in between; the query leaves out the
ones where the first may not be dead (`readBetween`): an assignment in between, or the
second one, names the target's object (`K := 1; K := K + 1;`), or, for a target that is
not a local variable (a global, a parameter, a variable of an enclosing subprogram),
calls a subprogram or allocates, since the callee may read it and an exception would
leave the first value there.

`groupable` counts the direct components of a record variable assigned in one group
(`R.F := ...`); `total` is the number of components of the type, or -1 when it is not
known statically (discriminants, a variant part, a type extension). A group is not
reported for a limited type or one with a class-wide component. Left out: AdaControl's
recursive counting of a component that "should have been assigned in full", and arrays.

`sliding` compares the static lower bound of the first index of a whole variable target
(its constraint, or its constrained array type's) with the value's: another whole
variable, or a string literal (which starts at 1). Initializations and dynamic bounds
are not checked; a slice is dynamic.

`access_duplication` holds when the value stored is the content of an object (not a
function result, `null` or an allocator) of an access type, or of a type with an access
subcomponent; `controlled` is whether that type is derived from
`Ada.Finalization.Controlled` or `Limited_Controlled`. It is checked for initializations
too. `possible_target_name` finds each part of a right-hand side that names the target
again; `trivial` is whether the target is an identifier.

### Directly_Accessed_Globals

`ada/directly-accessed-globals`, library `DirectlyAccessedGlobals`. The globals are the
variables declared directly in a package body (`isGlobal(v)`); constants, renamings and
objects of task or protected types are not. `access(v, n, mode)` gives each read and
write; an `in out` actual is both, an `out` actual or an assignment to a component or
element a write. The prefix of `'Access`, `'Unchecked_Access`, `'Unrestricted_Access` or
`'Address` is not an access: as for AdaControl, aliases are not followed.

An access belongs to the innermost subprogram body, entry body, `accept` statement or task
body around it (`callable(n)`), of kind `kind(c)`:

| `<kind>` | Callable | Accessor (`accessor(c)`) |
|---|---|---|
| `plain` | a subprogram, not protected | the subprogram |
| `protected` | a protected subprogram or entry | the protected object |
| `accept` | an `accept` statement | the task |

The callable is dedicated (`isDedicated(c, v)`) unless `notDedicated(c, v, reason)`: the
accessor is not declared directly in the package body (`nested`), is a generic
subprogram (`generic`) or the body of a protected or task type (`type`), or the access is
in a task body outside its `accept` statements (`task body`). The query reports those
accesses (`undedicatedAccess`), the ones in the package's own statements and declarations
(`outside`), and the variables with more than one reading or more than one writing
accessor, or one that does both and another (`tooManyAccessors`). It allows every kind;
for fewer, also report the accesses whose `kind` you do not allow. The query leaves out
the files the GNAT binder generates (`b__*.adb`, `b~*.adb`), whose elaboration flags are
package-body globals set by `adainit` and `adafinal` by design. The operations of one
protected object, and the `accept` statements of one task, count as one accessor, as
AdaControl's "the same single protected object" requires.

### Duplicate_Initialization_Calls

`ada/duplicate-initialization-calls`, library `DuplicateInitializationCalls`. The
procedures are those named by the data extension `initializationProcedure` (AdaControl's
`<entity>` list), or, with no row, those of the source named `Init` or `Initialize`
(`isInitializationProcedure(s, configured)`). `pattern(s)` is AdaControl's:

| Pattern | Profile | Reported |
|---|---|---|
| `in` | only `in` parameters | a call passing the same static values as an earlier one (`callKey`, `duplicate`); for a named procedure, a call passing a value that is not static (`nonStaticActual`) |
| `out` | exactly one `out` parameter, no `in out` one | a call passing the same variable as an earlier one (`outParameter`, `duplicate`); for named procedures only |

A named procedure that fits neither pattern is reported itself. A parameter left to its
default counts with its default value. Static values (`staticKey`) are literals,
possibly negated or qualified, and names of enumeration literals, named numbers and
constants, compared by entity rather than by value. The `out` variable is compared with
`Assignments::sameName` (the same variable, component, or element at static indices).
Each duplicate is reported against the first call in the source (by file, line, column)
that it repeats. Without a setting, the `out` pattern is left out: a procedure that just
happens to be named `Init` is often meant to initialize a context again once it is used
(libkeccak's `Init (Ctx, ...)` in its tests).

### Exception_Propagation

`ada/exception-propagation`, library `ExceptionPropagation`. A subprogram or task body
`b` is non-propagating at level `level` (`isNonPropagating(b, level)`) when it has a
`when others` handler, no handler raises (`handlerRaises`: a `raise` statement or
expression, `Raise_Exception`, `Reraise_Occurrence`), and no declaration of its
declarative part propagates at that level; a null procedure never propagates.
`canPropagate(b, level)` is the opposite.

| `<level>` | `declarationPropagates(d, level)` |
|---|---|
| 0 | never |
| 1 | `d` calls a function or an operator (`isFunctionCall`), unless it is a named number or a scalar type declaration |
| 2 | also when it uses a variable or a parameter (`isVariableUse`) |
| 3 | also when it is an object declaration |

Only what is evaluated when `d` is elaborated counts: not default parameters, bodies,
generics, task or protected types, or component defaults.

| Subrule | Library | Default |
|---|---|---|
| `task` | `canPropagate(t, level)` for each task body | yes, level 0 |
| `interface`, `<convention>` | `isExported(s, convention)`: pragma `Export` or `Interface`, or the aspects `Export` and `Convention` | yes, every convention, level 0 |
| `parameter`, `<entity>` | `passesSubprogram(c, p, s)`: `s'Access`, `'Unchecked_Access`, `'Unrestricted_Access` or `'Address` passed for parameter `p` | the parameters of the data extension `callbackParameter`, level 0 |
| `local_exception` | `localExceptionEscapes(e, b, site, reason)`: `unhandled`, `reraised`, `raised` | yes |
| `declaration` | `declarationPropagates(d, level)` | no |

A local exception is one declared in a block, a subprogram, entry or task body. Its
`catcher` is the handler naming it, else the `when others` one; it escapes when there is
none, when that handler re-raises (`raise;`, `Reraise_Occurrence`), or when any handler
raises it explicitly (`raise E`, `Raise_Exception (E'Identity, ...)`). As in AdaControl,
calls of other subprograms that raise it are not followed. Left out of `parameter`:
generic formal subprograms, and call-backs registered through an access type's formal.
The query leaves out the files the GNAT binder generates, whose `adainit` is exported
without a handler.

### Generic_Aliasing

`ada/generic-aliasing`, library `GenericAliasing`: `aliasing(inst, i, j, kind,
condition)` for formals `i < j` of instantiation `inst`, of kind `kind`
(`formalKind(formal)`), whose actuals alias with `condition`, the strongest that applies.

| `<kind>` | Formals | `certain` | `possible` | `unlikely` |
|---|---|---|---|---|
| `variable` | `in out` formal objects | the same object, or one a part of the other: a component, or an element at the same index (as written) | an element or slice of the same array at an index that is not static | `.all` of two access values of the same type |
| `type` | formal types | the same type, or the same attribute of it (`T'Base`, `T'Class`) | | |
| `subprogram` | formal subprograms | the same subprogram, through renamings | | |
| `package` | formal packages | the same instance, through renamings | | |

The query reports `certain variable`. AdaControl's default, `certain` for every kind,
gives 12 corpus results, none a mistake: maps from a type to the same type
(`Indefinite_Ordered_Maps (String, String)`) and sets whose `"="` and
`Equivalent_Elements` are one function. An `in` formal object
is a copy and is not checked. Elements at different static indices (`A (1)`, `A (2)`)
and different components do not alias. A subprogram actual must be in the source:
predefined operators (`"+"`) of different types resolve alike, which is AdaControl's
documented limitation, so they are left out. Left out: `possible` and `unlikely` for
subprograms (`Ptr.all` of access-to-subprogram values), implicit dereferences
(`P.Field` with `P` an access value), and a type and its subtype.

### Global_References

`ada/global-references`, library `GlobalReferences`. The roots (`rootKind(r)`) are
`function` and `procedure` (a subprogram of the source with a body), `task` (a task
body) and `protected` (a protected body); `isTypeRoot(r)` holds for the body of a task or
protected type. Each root starts in its bodies (`rootBody(r)`: the subprogram's body, the
task body, the bodies of the protected operations and entries) and reaches the bodies
they call (`calls(b, callee)`: subprogram calls and protected entry calls, `reaches(r,
b)`).

An access belongs to the innermost subprogram, entry or task body around it
(`bodyOf(n)`); `directAccess(b, v, n, mode)` reads or writes a variable declared outside
`b`, classified as for `Directly_Accessed_Globals`. `accesses(b, v, mode)` adds what the
bodies `b` calls access, except the variables declared in `b`: a variable of an
enclosing subprogram is global to a nested one, not to the subprogram itself.
Constants, renamings, loop variables, protected components and objects of task or
protected types are not checked (`isVariable(v)`).

| Subrule | Library | Default |
|---|---|---|
| `all` | `referenceSite(r, v, n, mode)`, `reference(r, v, mode)` | no |
| `read`, `written` | `reference(r, v, "read")`, `reference(r, v, "write")` | no |
| `multiple` | `GlobalReferencesMultiple<isRoot>::multiple(v)`: more than one root, or a task or protected type | no |
| `multiple_non_atomic` | `GlobalReferencesMultiple<isRoot>::multipleNonAtomic(v)`: `multiple`, except an atomic variable (`Atomic`, `Atomic_Components`) written by one root at most | yes, roots `task` and `protected` |

`GlobalReferencesMultiple` takes AdaControl's list of roots as a predicate; for an
`<entity>`, hold for that subprogram, task or protected body. The query also requires
one root to write the variable: a variable that tasks only read is set before they
start, during elaboration. It leaves out the files the GNAT binder generates. As in
AdaControl, calls through access-to-subprogram values and dispatching calls are assumed
to access nothing, and the Ada library is not followed (its bodies are not in the
database). Left out: atomic types (only objects declared atomic count), and accesses
through renamings and `'Access` values.

### Improper_Initialization

`ada/improper-initialization`, library `ImproperInitialization`. The rule checks a
design pattern, not data flow: in a subprogram body, local variables and `out`
parameters (`isTarget(target, b, kind)`) get their value in the *initial sequence*, the
statements before the first non-trivial one (`initialEnd(b)`, `firstNonTrivial(b)`).
Trivial (`not isNonTrivial(s)`) are `null`, assignments, procedure calls, `return`,
`raise`, and `if`, `case` and extended `return` statements made only of trivial
statements; a loop, a block, a `goto` label are not. A target is assigned by a statement
(`assigns(s, target, parts)`) that assigns it as a whole or passes it for an `out`
parameter (not `in out`) of any call, also in an `if` condition or a `case` selector,
or by an `if` with an `else` or a `case` whose every branch assigns it or ends with
`return`, `raise` or `goto`; a read in a
branch comes after its `if` condition (`precededByAssign`). An `out` actual in the
initial value of a declaration (`R : constant T := F (Target)`) assigns it before the
statements (`assignedInDeclarations`). An actual of a call the extractor does not
resolve, or of `'Asm_Output`, may be an output and counts as assigning. In AdaControl assigning a component or an element does not count
(`parts` = `false`); with `parts` = `true` it does. A name the extractor leaves
unresolved but spelled like the target (the target of an assignment whose value does not
resolve) counts as the target. The prefix of `'First`, `'Last`, `'Length`, `'Range`,
`'Size`, `'Address`, `'Access` and the like is not a read (`isRead`).

| Subrule | Library | Default |
|---|---|---|
| `variable`, `out_parameter`: uses | `readBeforeAssign(n, target, b, parts)`: a read in the initial sequence not preceded by an assignment (`precededByAssign`) | yes, with `parts` |
| `out_parameter`: returns | `returnBeforeAssign(r, p, b, parts)`: a `return` of the initial sequence that may leave `p` unassigned | yes, with `parts` |
| `out_parameter`, never assigned | `notSafelyInitialized(p, b, "out_parameter", parts)` in a body with no non-trivial statement | yes, with `parts` |
| `variable`, `out_parameter` | `notSafelyInitialized(target, b, kind, parts)`: no initial value, not assigned in the initial sequence | no: 1144 corpus results, a design pattern (a variable first set in a loop is not a mistake) |
| `initialized_variable` | `redundantInitializer(v, b)`: an initial value replaced in the initial sequence before any read | no: 291 corpus results, a style preference |
| `access`, `limited` extras | `isSkipped(target, extra)`: targets of access types or types holding access values, and of limited types, which the query leaves out | no |

The query reports what is likely a mistake rather than a departure from the pattern, and
counts assignments to parts: AdaControl's whole-assignment rule reports every record or
array initialized component by component (`P.A := 1; P.B := P.A;`) as read before it is
assigned. It checks a target only when its type is known to have no default value
(`hasNoDefault(t)`: scalars and arrays of them; records, private types and containers may
be initialized by default, which AdaControl lists as its own false positives) and it is
not aliased (`isAliased`: its `'Access` or `'Address` is taken, or it is an overlay or
imported). AdaControl's subrules as written gave 1356 corpus results, most of them the
design pattern, component-wise initialization and default-initialized objects.

A variable that is never read is left to `ada/unused-local`. An `out` parameter of a body
whose statements are all trivial and end with `raise` is not reported: `out` parameters
are not passed back when an exception propagates. Left out: the `package` and `return`
extras (package variables, extended-return objects), entry and task bodies, and
dispatching calls and attribute procedures, which AdaControl also does not count as
initializing. AdaControl's own `access` extra covers access types and arrays of them;
`isSkipped` also skips records with access components.

### Max_Call_Depth

`ada/max-call-depth`, library `MaxCallDepth`: `callDepth(c)` is the depth of call `c`, the
number of frames it stacks: 1 for a subprogram that calls nothing, 1 plus the deepest
call in the body otherwise (`depth(s)`). A subprogram without a body in the database
(imported, from the Ada library) counts 1, and a recursive one (`isRecursive(s)`, the
`finite` subrule) is not followed; either makes the depth a minimum (`isExactCall(c)`
does not hold), reported as "at least". Predefined operators count 0. Calls of
expression functions count, AdaControl's `Count_Expr_Fun_Calls` `on`. Depths are
computed up to `maxComputedDepth()` (100).

| Parameter | Library | Default |
|---|---|---|
| `<allowed depth>` | `tooDeep(c, limit)` | the data extension `maxCallDepth`, else 15 |
| `finite` | `isRecursive(c.getTarget())` | no: `ada/direct-recursion` and `ada/indirect-recursion` report recursion |

Each call over the limit is reported, as in AdaControl, so a deep chain is reported at
every call above the limit along it. Left out: entry calls (a task entry is always
depth 1 in AdaControl), the `<entity>` list of subprograms assumed to call nothing, and
`Count_Expr_Fun_Calls` `off`. Calls through access-to-subprogram values and dispatching
calls count as calls of their static target, or not at all when they have none.

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

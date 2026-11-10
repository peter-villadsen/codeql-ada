/**
 * @name Style
 * @description A consistent style makes code easier to read. AdaControl rule `Style`,
 *              the subrules that can be checked on the tree: casing of identifiers
 *              (as declared), attributes, pragmas, aspects, and the extended digits and
 *              exponent of numbers; `default_in` (a parameter without mode);
 *              `exposed_literal` (a number outside a constant or named number);
 *              `multiple_elements` (two elements on one line); `no_closing_name`;
 *              `numeric_literal` (digits not grouped by underscores); `parameter_order`
 *              and `formal_parameter_order`; `renamed_entity` (an entity used by its
 *              original name where a renaming is visible). The subrules are chosen
 *              with the data extension `styleCheck`. By default: the casing subrules,
 *              `multiple_elements` (`flexible`), `no_closing_name` and
 *              `numeric_literal` (blocks of 3); `default_in` and `exposed_literal`
 *              are checked when a row names them. Left out: `casing_keyword` and `compound_statement`, which
 *              need tokens the extractor does not keep. See
 *              `codeql.ada.adacontrol.Style`.
 * @id ada/style
 * @kind problem
 * @problem.severity recommendation
 * @precision medium
 * @tags maintainability readability adacontrol
 */

import ada
import codeql.ada.adacontrol.Style
import codeql.ada.adacontrol.Settings
import codeql.ada.adacontrol.Generated

/**
 * Holds if the query checks `subrule` with `parameter` when there is no `styleCheck`
 * row: AdaControl's defaults, but for `default_in` and `exposed_literal`, which most
 * projects do not follow, and with `multiple_elements` `flexible` (`with P; use P;`
 * on one line is accepted).
 */
predicate defaultCheck(string subrule, string parameter) {
  subrule = "casing_identifier" and parameter = "original"
  or
  subrule = ["casing_attribute", "casing_pragma", "casing_aspect"] and parameter = "titlecase"
  or
  subrule = ["casing_number", "casing_exponent"] and parameter = "uppercase"
  or
  subrule = "multiple_elements" and parameter = "flexible"
  or
  subrule = "no_closing_name" and parameter = ""
  or
  subrule = "numeric_literal" and parameter = "3"
}

/** Holds if the query checks `subrule` with `parameter`. */
predicate enabled(string subrule, string parameter) {
  exists(string s, string p | styleCheck(s, p) | subrule = s.toLowerCase() and parameter = p.toLowerCase())
  or
  not styleCheck(_, _) and defaultCheck(subrule, parameter)
}

/** Holds if `text` has one of the casings `subrule` is enabled with. */
bindingset[text]
predicate wellCased(string text, string subrule) {
  exists(string casing | enabled(subrule, casing) | Style::hasCasing(text, casing))
}

/** Holds if numeric literal `l` has a value `exposed_literal` allows. */
predicate allowedLiteral(Raw::NumLiteral l) {
  exists(string v | enabled("exposed_literal", v) and v != "" | Style::literalValue(l) = v)
  or
  not exists(string v | enabled("exposed_literal", v) and v != "") and
  Style::literalValue(l) = ["0", "1", "0.0", "1.0"]
}

from AdaNode n, string subrule, string msg
where
  n.fromSource() and
  not isBinderGenerated(n) and
  (
    subrule = "casing_identifier" and
    (
      enabled(subrule, "original") and
      msg = "'" + n.(Raw::Identifier).getValue() + "' is declared as '" + Style::originalCasing(n) + "'."
      or
      exists(string text |
        text = n.(Raw::Identifier).getValue() and
        exists(string c | enabled(subrule, c) and c != "original") and
        not n = any(Raw::AttributeRef a).getAttribute() and
        not n = any(Raw::PragmaNode p).getId() and
        not n = any(Raw::AspectAssoc a).getId() and
        not wellCased(text, subrule) and
        msg = "'" + text + "' does not have the required casing."
      )
    )
    or
    exists(string element, string word |
      word = Style::casedWord(n, element) and
      subrule = "casing_" + element and
      exists(string c | enabled(subrule, c)) and
      not wellCased(word, subrule) and
      msg = "'" + word + "' does not have the required casing."
    )
    or
    subrule = "default_in" and
    enabled(subrule, _) and
    Style::defaultIn(n) and
    msg = "The mode 'in' is implicit."
    or
    subrule = "exposed_literal" and
    enabled(subrule, _) and
    exists(Style::exposedLiteral(n)) and
    not allowedLiteral(n) and
    msg = "The literal " + Style::literalText(n) + " is not in a constant declaration."
    or
    subrule = "multiple_elements" and
    exists(AdaNode a, boolean flexible |
      Style::multipleElements(a, n, flexible) and
      enabled(subrule, _) and
      not (flexible = true and enabled(subrule, "flexible")) and
      msg = "This element is on the same line as the one before it."
    )
    or
    subrule = "no_closing_name" and
    exists(int lines, string maxLines |
      Style::noClosingName(n, lines) and
      enabled(subrule, maxLines) and
      (maxLines = "" or lines > maxLines.toInt()) and
      msg = "This construct has no name after its 'end'."
    )
    or
    subrule = "numeric_literal" and
    exists(string size |
      enabled(subrule, size) and
      Style::numericLiteral(n, size.toInt()) and
      msg = "The digits of " + Style::literalText(n) + " are not grouped by " + size + "."
    )
    or
    subrule = "parameter_order" and
    enabled(subrule, _) and
    exists(string mode, string previous |
      Style::parameterOrder(n, mode, previous) and
      msg = "A parameter of mode " + mode + " follows one of mode " + previous + "."
    )
    or
    subrule = "formal_parameter_order" and
    enabled(subrule, _) and
    exists(string mode, string previous |
      Style::formalParameterOrder(n, mode, previous) and
      msg = "A generic formal " + mode + " follows a formal " + previous + "."
    )
    or
    subrule = "renamed_entity" and
    enabled(subrule, _) and
    exists(Raw::BasicDecl r |
      Style::renamedEntity(n, r) and
      msg = "This entity is renamed as " + r.getADefiningName().getName().getText() + ", but used by its original name."
    )
  )
select n, "Style (" + subrule + "): " + msg

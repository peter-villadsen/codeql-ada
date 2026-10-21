/**
 * AdaControl rule `Header_Comments`: every compilation unit starts with a standard
 * comment header (`docs/adacontrol.md`).
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.adacontrol.Comments

module HeaderComments {
  /** Gets the first line of code of `cu`: where its first node (a context clause or the unit) starts. */
  private int firstCodeLine(Raw::CompilationUnit cu) {
    result = min(Raw::AdaNode n, int l | n.getParent() = cu and l = n.getLocation().getStartLine() | l)
  }

  /** Holds if `cu` is the first compilation unit of its file (the header is the file's). */
  private predicate isFirstUnit(Raw::CompilationUnit cu, string path) {
    cu.getLocation().hasLocationInfo(path, _, _, _, _) and
    not exists(Raw::CompilationUnit other, int l |
      other.getLocation().hasLocationInfo(path, l, _, _, _) and l < cu.getLocation().getStartLine()
    )
  }

  /** Gets the `i`th (1-based) comment line before the code of `cu`, the first unit of its file. */
  Raw::Comment headerLine(Raw::CompilationUnit cu, int i) {
    exists(string path |
      isFirstUnit(cu, path) and
      result =
        rank[i](Raw::Comment c, int line |
          Comments::commentAt(c, path, line, _) and line < firstCodeLine(cu)
        |
          c order by line
        )
    )
  }

  /** `minimum`: the number of comment lines before the code of `cu`. */
  int headerLineCount(Raw::CompilationUnit cu) {
    isFirstUnit(cu, _) and result = count(headerLine(cu, _))
  }

  /**
   * Gets a regular expression matching a whole line where `pattern` matches part of it,
   * as AdaControl's patterns do unless anchored with `^` and `$`.
   */
  bindingset[pattern]
  private string wholeLine(string pattern) {
    exists(string start, string end |
      (if pattern.matches("^%") then start = "" else start = ".*") and
      (if pattern.matches("%$") then end = "" else end = ".*")
    |
      result = start + pattern.regexpReplaceAll("^\\^|\\$$", "") + end
    )
  }

  /** The model of `model`: its `i`th (1-based) line is a regular expression. */
  signature string modelLine(int i);

  /**
   * `model`: a header that follows a model, one regular expression per line, matched
   * against the whole comment line (`^-- Author: .+$`). AdaControl's repetitions
   * (`{min,max}`, `*`, `+`, `?`) are not supported.
   */
  module Model<modelLine/1 model> {
    /** Holds if line `i` of the header of `cu` does not match line `i` of the model, or is missing. */
    predicate mismatch(Raw::CompilationUnit cu, int i) {
      isFirstUnit(cu, _) and
      exists(string pattern | pattern = model(i) |
        not exists(headerLine(cu, i))
        or
        not headerLine(cu, i).getText().regexpMatch(wholeLine(pattern))
      )
    }

    /** Gets the first line of the header of `cu` that does not follow the model. */
    int firstMismatch(Raw::CompilationUnit cu) { result = min(int i | mismatch(cu, i)) }
  }
}

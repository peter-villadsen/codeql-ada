/**
 * Code that tools generate, which the AdaControl-parity queries leave out where it
 * breaks a rule by design.
 */

private import codeql.ada.ast.internal.Raw

/**
 * Holds if `n` is in a file the GNAT binder generates (`b__*.adb`, `b~*.adb`), whose
 * elaboration flags are package-body globals and whose `adainit` and `adafinal` are
 * exported without handlers.
 */
predicate isBinderGenerated(Raw::AdaNode n) {
  exists(string path |
    n.getLocation().hasLocationInfo(path, _, _, _, _) and path.regexpMatch(".*/b(__|~)[^/]*")
  )
}

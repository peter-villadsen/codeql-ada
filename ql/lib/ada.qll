/** Ada QL library: user-facing entry point. */

import codeql.ada.ast.internal.Raw

/** A file in the snapshot. */
class File = Raw::File;

/** A location in the snapshot. */
class Location = Raw::Location;

/** An Ada AST node. */
class AdaNode = Raw::AdaNode;

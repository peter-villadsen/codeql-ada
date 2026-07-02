/** Spike QL library for Ada (burndown 1.2). */

/** A file in the snapshot. */
class File extends @file {
  string getAbsolutePath() { files(this, result) }

  string toString() { result = this.getAbsolutePath() }
}

/** An Ada compilation unit (spike granularity: one per source file). */
class CompilationUnit extends @compilation_unit {
  string getName() { compilation_units(this, result) }

  File getFile() { compilation_unit_file(this, result) }

  string toString() { result = this.getName() }
}

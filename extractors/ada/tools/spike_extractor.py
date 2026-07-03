"""Spike extractor (burndown 1.2): proves the TRAP pipeline without Libadalang.

Walks the source root for Ada files, emits one TRAP file per source file with a
files() row and a compilation_units() row, and copies sources into the source
archive. The real extractor will replace this with a Libadalang AST walk.
"""

import os
import pathlib
import shutil
import sys

LANG = "ADA"
EXTENSIONS = {".ads", ".adb", ".ada"}


def env_path(suffix: str) -> pathlib.Path:
    return pathlib.Path(os.environ[f"CODEQL_EXTRACTOR_{LANG}_{suffix}"])


def norm(path: pathlib.Path) -> str:
    """Absolute path with forward slashes, as stored in the database."""
    return str(path.resolve()).replace("\\", "/")


def trap_quote(s: str) -> str:
    return '"' + s.replace('"', '""') + '"'


def main() -> int:
    trap_dir = env_path("TRAP_DIR")
    archive_dir = env_path("SOURCE_ARCHIVE_DIR")
    src_root = pathlib.Path.cwd()

    trap_dir.mkdir(parents=True, exist_ok=True)
    archive_dir.mkdir(parents=True, exist_ok=True)

    # Global facts.
    (trap_dir / "metadata.trap").write_text(
        f"sourceLocationPrefix({trap_quote(norm(src_root))})\n", encoding="utf-8"
    )

    count = 0
    for path in sorted(src_root.rglob("*")):
        if path.suffix.lower() not in EXTENSIONS or not path.is_file():
            continue
        count += 1
        db_path = norm(path)

        # Copy into the source archive, mirroring the absolute path.
        dest = archive_dir / db_path.replace(":", "_")
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, dest)

        file_label = f'@"{db_path};sourcefile"'
        lines = [
            f"#10000={file_label}",
            f"files(#10000,{trap_quote(db_path)})",
        ]
        trap_file = trap_dir / (db_path.replace(":", "_").replace("/", "_") + ".trap")
        trap_file.write_text("\n".join(lines) + "\n", encoding="utf-8")
        print(f"[spike-extractor] extracted {db_path}")

    print(f"[spike-extractor] done, {count} file(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

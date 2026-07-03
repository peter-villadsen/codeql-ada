# Third-party notices

`codeql-extractor-ada-linux64.tar.gz` bundles the Libadalang runtime (D-010) so
users need only a system Python and their own CodeQL CLI. This file lists
every bundled third-party component, verified against the actual LICENSE file
in each project's source tree (pinned commits in `scripts/build-libadalang.sh`,
D-012) rather than assumed from project reputation — several of these differ
from a first guess.

Full license texts are linked below rather than reproduced in full (except the
two short exception texts, which aren't at a single stable canonical URL).

## Apache License 2.0 (with LLVM Exceptions)

- **Libadalang** — https://github.com/AdaCore/libadalang
- **Langkit** (`langkit_support` runtime) — https://github.com/AdaCore/langkit
- **VSS** — https://github.com/AdaCore/VSS
- **prettier-ada** — https://github.com/AdaCore/prettier-ada
- **AdaSAT** — https://github.com/AdaCore/adasat

License text: https://www.apache.org/licenses/LICENSE-2.0

LLVM Exception (permits embedding compiled/Object-form portions without the
Section 4(a)/4(b)/4(d) notice-propagation conditions):

> As an exception, if, as a result of your compiling your source code, portions
> of this Software are embedded into an Object form of such source code, you
> may redistribute such embedded portions in such Object form without complying
> with the conditions of Sections 4(a), 4(b) and 4(d) of the License.

## Apache License 2.0 (plain)

- **gpr2** (`libgpr2.so`, the project-file library; from the `AdaCore/gpr`
  repo's `src/lib` tree — see that repo's `LICENSE-lib`, distinct from its
  `LICENSE-tool`, which covers GPL-licensed command-line tool code not bundled
  here) — https://github.com/AdaCore/gpr

License text: https://www.apache.org/licenses/LICENSE-2.0

## GPLv3 WITH GCC Runtime Library Exception 3.1

- **GNATcoll** (`gnatcoll-core`, `gnatcoll-bindings`: core, minimal, projects,
  gmp, iconv components) — https://github.com/AdaCore/gnatcoll-core,
  https://github.com/AdaCore/gnatcoll-bindings
- **libgpr** (legacy GNAT project-file library, from `AdaCore/gprbuild`,
  pinned tag v25.0.0, used by `gnatcoll_projects`) —
  https://github.com/AdaCore/gprbuild
- **XML/Ada** (`libxmlada-dom`, `-sax`, `-input`, `-schema`, `-unicode`;
  Debian system packages, version 25.0.0-4) —
  https://github.com/AdaCore/xmlada
- **GNAT/GCC Ada runtime** (`libgnat-14.so`, `libgnarl-14.so`; Debian
  `gnat-14` package, version 14.2.0-19) — https://gcc.gnu.org/

License text: https://www.gnu.org/licenses/gpl-3.0.txt

GCC Runtime Library Exception, version 3.1 (an additional permission under
GPLv3 section 7 that allows non-GPL, including proprietary, programs to be
compiled/linked against these runtime libraries):
https://www.gnu.org/licenses/gcc-exception-3.1.en.html

Both of these apply because target machines have no GNAT install of their
own — the GNAT/GCC Ada runtime and its GNATcoll/libgpr/XML-Ada dependents must
travel with the extractor, and the Exception is exactly what permits that for
a non-GPL (here, MIT) extractor.

## LGPL-3.0-or-later (dual-licensed GPL-2.0-or-later / LGPL-3.0-or-later)

- **GMP** (`libgmp10`; Debian system package, version 2:6.3.0+dfsg-3) —
  https://gmplib.org/

We redistribute under the LGPL-3.0-or-later branch of GMP's dual license.
License text: https://www.gnu.org/licenses/lgpl-3.0.txt

## Our code

The extractor, dbscheme, generator, and QL packs in this repository are MIT
licensed — see `LICENSE` next to this file (and the repository root).

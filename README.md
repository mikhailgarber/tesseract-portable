# Tesseract Portable

Unofficial, portable, statically linked [Tesseract](https://github.com/tesseract-ocr/tesseract)
5 command-line binaries and tessdata language models. This project is not affiliated
with the Tesseract project.

## Targets

| Target | Build environment | vcpkg triplet |
| --- | --- | --- |
| `x86_64-unknown-linux-gnu` | `manylinux_2_28_x86_64` on Ubuntu 24.04 | `x64-linux-portable` |
| `aarch64-unknown-linux-gnu` | `manylinux_2_28_aarch64` on Ubuntu 24.04 Arm | `arm64-linux-portable` |
| `x86_64-apple-darwin` | macOS 15 Intel | `x64-osx-portable` |
| `aarch64-apple-darwin` | macOS 15 | `arm64-osx-portable` |
| `x86_64-pc-windows-msvc` | Windows 2025, MSVC | `x64-windows-static` |

Linux binaries require glibc 2.28 or newer. macOS binaries target macOS 11. Windows
binaries use the static MSVC runtime and need no Visual C++ redistributable.

## Releases

Binary releases use tags such as `v5.5.3_1` and contain, for each target:

- `tesseract-<version>-<target>.tar.gz`
- `tesseract-<version>-<target>.tar.gz.sha256`

Each archive contains `bin/tesseract` (or `bin/tesseract.exe`), `LICENSES/`, and
`BUILDINFO.json`. The checksum file uses the standard `sha256sum` format. Releases are
immutable; a fix is always a new build number. Each archive has a build provenance
attestation (see [SECURITY.md](SECURITY.md)).

Tessdata models have their own `<source>-<upstream-tag>` releases, published by
`tessdata.yml` from `tesseract-ocr/tessdata_fast` (e.g. `tessdata_fast-4.1.0`, the
models Debian and Ubuntu package) or `tesseract-ocr/tessdata` (e.g. `tessdata-4.1.0`).
These releases contain unmodified `.traineddata` files, individual checksum files,
`SHA256SUMS`, and `SOURCE.txt`. Script models (`script/Cyrillic.traineddata`
upstream) are published flat as `Cyrillic.traineddata`, where Debian installs them.
Publish `tessdata-4.1.0` before the first binary release (CI's test model).

## Verification

Every build checks allowed dynamic dependencies, Linux GLIBC symbol versions, macOS
ad-hoc signatures, `tesseract --version`, OCR of `test/hello.png`, and archive
completeness. Linux artifacts are also executed in a clean Debian Bookworm container.

The test model is downloaded rather than committed. CI first tries this repository's
`tessdata-4.1.0` release, then falls back to the byte-identical upstream 4.1.0 model.
Both are required to match SHA-256
`daa0c97d651c19fba3b25e81317cd697e9908c8208090c94c3905381c23fc047`.

## Maintenance

`refresh.yml` runs monthly and can be dispatched manually. It updates the vcpkg
baseline, regenerates the overlay from the upstream port (preserving only the
intentional removal of curl and libarchive), moves the digest-pinned build containers
to their newest images, pushes the branch `automation/vcpkg-refresh`, and opens an
issue with a link to open the PR (workflows may not create pull requests here). That
PR's Build run writes the `BUILDINFO.json` package changes against the latest release
to its job summary. If nothing changed, close the PR; otherwise merge it and tag the
next `v<version>_<build>` release.

Dependabot keeps the commit-SHA-pinned actions current. Security settings and
reporting: see [SECURITY.md](SECURITY.md).

## Licenses

Build scripts are MIT-licensed. Every binary archive ships the vcpkg copyright text
for Tesseract (Apache-2.0), Leptonica, giflib, libjpeg-turbo, libpng, libspng,
libwebp, OpenJPEG, libtiff, liblzma/xz, and zlib. Tessdata models are Apache-2.0.

Derived from the vcpkg Tesseract port at commit
`eb2d3a3279fd019cb7733072d86900d0ad2a1aef` (2026-10-01).

This overlay differs only by removing the `curl` and `libarchive` dependencies
and disabling their CMake integrations. Refreshes must copy the upstream port
again and repeat only those changes.

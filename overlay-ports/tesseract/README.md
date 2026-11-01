Derived from the vcpkg Tesseract port at commit
`9a5dfef5d1a0438a7d24856a85bd60f309d355e9` (2026-11-01).

This overlay differs only by removing the `curl` and `libarchive` dependencies
and disabling their CMake integrations. Refreshes must copy the upstream port
again and repeat only those changes.

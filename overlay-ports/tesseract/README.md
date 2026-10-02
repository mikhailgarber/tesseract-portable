Derived from the vcpkg Tesseract port at commit
`3aea538b2bb21a586502c67b00eb474fdd2e3098` (2026-10-02).

This overlay differs only by removing the `curl` and `libarchive` dependencies
and disabling their CMake integrations. Refreshes must copy the upstream port
again and repeat only those changes.

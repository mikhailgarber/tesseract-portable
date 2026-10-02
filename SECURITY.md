# Security

Please report vulnerabilities privately through
[GitHub's private vulnerability reporting](https://github.com/mikhailgarber/tesseract-portable/security/advisories/new),
not in public issues.

This covers the build and release process of this repository. Vulnerabilities in Tesseract or
one of the bundled libraries belong upstream; once vcpkg carries the fix, a new build number is
released here.

## Verifying a download

Every binary release asset is built by this repository's `release.yml` workflow and has a build
provenance attestation:

```sh
gh attestation verify tesseract-5.5.3_4-x64-linux-portable.tar.gz \
  --repo mikhailgarber/tesseract-portable
```

Releases are immutable: once published, their assets and tags cannot change.

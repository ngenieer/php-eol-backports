# Security Policy

This repository carries **unofficial** backports of the PHP2Shell fix (CVE-2026-109618, CVE-2026-109619) to end-of-life PHP 7.0–7.3, and packages rebuilt from them. It is not part of the PHP project.

## Scope

Report to this repository:

- A backport patch in `patches/` that is incomplete, wrong, or introduces a new vulnerability compared to the official 7.4 backport
- A problem in the rebuilt RPM or .deb packages on the [releases](../../releases) page (for example a missing fix, a checksum mismatch, or files that differ from what the build scripts produce)
- A problem in the build and verification scripts that could lead to a broken or unsafe package

Report elsewhere:

| Issue | Where |
|---|---|
| A vulnerability in PHP itself, including one present in supported versions | The PHP project: https://github.com/php/php-src/security |
| A problem in Remi's source packages | Remi: https://github.com/remicollet/remirepo/issues |
| A problem in Sury's source packages | Sury: https://github.com/oerdnj/deb.sury.org/issues |
| A problem in a distribution package (Freexian ELTS, Ubuntu Pro ESM) | That vendor |

## Reporting

Use [private vulnerability reporting](../../security/advisories/new) (Security tab → "Report a vulnerability"). Do not open a public issue for anything that could be exploited.

Include the PHP version, the patch or package version (for example `7.3.33-24.sizlon1.el7`), and how to reproduce the problem. A proof of concept is welcome but not required.

## What to expect

This is maintained on a best-effort basis with no response time guarantee. A confirmed problem is fixed in the patch, the affected packages are rebuilt under a new release, and the old release is marked as superseded, as was done for `el7-php73-7.3.33-22.sizlon1`.

## Supported versions

Only the latest release of each package target and the patches on `main` are maintained. These backports reduce exposure on versions that should no longer be used; the real fix is to move to a supported PHP version.

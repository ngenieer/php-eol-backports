# CentOS 7 + Remi php73 RPM verification (2026-10-26)

## Background
- Remi's php73 for CentOS 7 (el7) stopped at **7.3.33-14 (2024-06)**. Since then Remi has released security fixes for EL8/EL9 only.
- On 2026-10-25 Remi released **7.3.33-23**. It contains the PHP2Shell fix (CVE-2026-109618, CVE-2026-109619) and two SOAP fixes (CVE-2026-91765, CVE-2025-14181), but again only for EL8/EL9.
- So the **Remi 7.3.33-23 source RPM was rebuilt on CentOS 7**. CentOS 7 users get the PHP2Shell fix together with all of Remi's security fixes from -15 to -23.

## What was built
- Packages: 35 `php-*-7.3.33-23.sizlon1.el7.x86_64.rpm`, the same set of subpackages as Remi's, including debuginfo.
- Source: Remi `php-7.3.33-23.remi.src.rpm`. Its signature was checked against Remi's 2026 key (`befa00e2`); CentOS 7's rpm cannot read this signature format, so the check was done on Rocky 9.
- Files to reproduce: `rpm/el7/php73/php73.spec.diff`, `rpm/el7/php73/php-cve-2026-109618-109619-shutdown.patch`

### Added on top of Remi's patch
Remi's `php-from-8.2.35-to-7.3.patch` is almost identical to this repository's 7.3 patch. Compared line by line, only `zend_execute_API.c` differs. In the fast-shutdown branch of `shutdown_executor()`, Remi's patch only resets `objects_store` and lacks two things:
- resetting the user error/exception handlers **before** the object store is freed
- resetting `EG(error_handling)` and `EG(exception)` after it is freed

Both are in php.net's official fixes (802c210 for 8.x, 712e60f9ed for 7.4) and in Remi's own 7.4 patch (7.4.33-31). Without them, a handler registered as a closure stays referenced after it is freed (see [sury-crosscheck.md](sury-crosscheck.md)). Only these two parts were added, as `Patch236`; they are the same as the corresponding parts of `patches/7.3`. Remi 7.2.34-30 lacks the same parts, and this was reported to Remi ([remicollet/remirepo#364](https://github.com/remicollet/remirepo/issues/364)). Once Remi includes it, `Patch236` can be dropped and the package built from Remi's source alone.

The earlier release `7.3.33-22.sizlon1` was built from Remi -22 plus this repository's full patch, using the patch before the handler reset position was fixed. It is superseded by `23.sizlon1`. The full patch file for -22 is no longer used and was removed; it remains in the git history.

## Verification A: yum upgrade
Done in a CentOS 7 container, the way it would be done on a real server.

1. Installed `php-cli php-common php-fpm php-mysqlnd php-pdo php-gd php-opcache php-mbstring php-xml php-json` from Remi's php73 repository. → **7.3.33-14.el7.remi**
2. Ran the FPM smoke test.
3. Installed the new RPMs with `yum localinstall`. → upgraded in place to **7.3.33-23.sizlon1.el7**, with no dependency problems.
4. Ran the same FPM smoke test again.

| Item | Remi -14 (what servers run today) | New RPM |
|---|---|---|
| opcache, mysqli, pdo_mysql, gd, session | OK | OK |
| Nested GET/POST arrays, multipart upload, session persistence | OK | **Same** |
| Response to a request exceeding the memory limit | 500 (display_errors Off) | Empty response → 502 in nginx |
| Shutdown function on memory limit | Runs | Does not run |
| Worker after exceeding the memory limit | Reused | Exits; FPM starts a new one |
| 4 normal requests right after exceeding the memory limit | Succeed | Succeed |

Upgrading from the earlier release `22.sizlon1` to `23.sizlon1` was also verified. No package was left un-upgraded. The smoke results were the same; the only difference was the cumulative FPM log counts.

## Verification B: regression tests
Two builds from the same Remi 7.3.33-23 source were compared with PHP's test suites:
- `23.base0`: built without the PHP2Shell patches (Patch235, Patch236)
- `23.sizlon1`: built with both patches

| | Unpatched | Patched |
|---|---|---|
| Passed | 6,205 | 6,196 |
| Failed | 9 | 18 |

**The 9 tests that fail only after the patch are exactly the same as for php.net's official 7.4 backport** (upload progress 8 + memory limit 1, see EXPECTED-CHANGES.md). Remi's build includes php-cgi, so the upload progress tests actually ran.

Session upload progress (`session.upload_progress`) is disabled in the code. The precondition of CVE-2026-115560 (upload progress enabled), covered by the KISA (Korea Internet & Security Agency) advisory of 2026-10-24, therefore does not hold either.

## How to reproduce
```bash
docker build -f rpm/el7/Dockerfile.builder -t peb-el7-builder .   # put a proxy CA in rpm/el7/ca/ if needed
# Remi's SRPM php-7.3.33-23.remi.src.rpm uses an EL8 rpm feature (RichDependencies), so rpm -i fails on el7.
# Unpack it with rpm2cpio into SOURCES/SPECS, apply php73.spec.diff, copy the Patch236 file into SOURCES, then
# (before building) yum install gd3php-devel libicu69-devel oniguruma5php-devel; yum-builddep php73.spec
rpmbuild -bb --define "runselftest 0" php73.spec
rpm/el7/verify.sh <rpm-dir> <php-source-tree> <out-dir>
rpm/el7/sha256sums.sh <rpm-dir>/fix 7.3.33-23.sizlon1   # SHA256SUMS for the release
```

## Limitations
- These are not packages made by Remi. They do not carry Remi's signature; distributing them through a repository requires a separate signing key.
- If additional PHP extensions are installed on a server (pecl and the like), they may need to be rebuilt for the same version.
- The vulnerabilities were not reproduced to confirm the fix. The patch is not endorsed by php.net or Remi.

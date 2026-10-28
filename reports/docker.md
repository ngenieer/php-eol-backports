# Verification on Docker images (2026-10-25)

`docker/verify.sh` rebuilds the PHP of the official `php:<x.y>-fpm` images twice, unpatched and patched, **using each image's own configure options**, and adds extensions common on legacy sites (mysqli, pdo_mysql, gd, opcache) before comparing.

| Version | Base OS | Unpatched passed/failed | Patched passed/failed | Failing only after the patch |
|---|---|---|---|---|
| 7.3.33 | Debian 11 | 6,131 / 5 | 6,130 / 6 | `tests/lang/bug45392.phpt` |
| 7.2.34 | Debian 10 | 5,934 / 5 | 5,933 / 6 | `tests/lang/bug45392.phpt` |
| 7.1.33 | Debian 10 | 5,784 / 0 | 5,783 / 1 | `tests/lang/bug45392.phpt` |
| 7.0.33 | Debian 9 | 5,490 / 0 | 5,489 / 1 | `tests/lang/bug45392.phpt` |

Suites: Zend/tests, tests, main, ext/session, ext/standard (file, strings, array), ext/opcache/tests

- On all four versions, the only test failing after the patch is the one for the memory-limit behaviour change (EXPECTED-CHANGES item 2).
- The upload progress tests (`ext/session/tests/rfc1867*.phpt`) were skipped because the official images are built without php-cgi. That behaviour change was confirmed in the minimal-build verification (reports/7.x.md).

## PHP-FPM smoke test

Requests were sent over FastCGI to a real FPM worker pool (`docker/smoke/run.sh`). The results are the same on all four versions.

| Item | Unpatched | Patched |
|---|---|---|
| opcache, mysqli, pdo_mysql, gd, session loaded | OK | OK |
| Nested GET/POST arrays (`a[b][c]`, `x[]`) | OK | **Same** |
| Multipart upload of 2 files + a plain field (with an extra header) | OK | **Same** |
| Session persistence (second request with the cookie) | OK | **Same** |
| Fatal message in the response body of a request exceeding the memory limit | Present | Absent (empty response → 502 in nginx) |
| `register_shutdown_function` runs on memory limit | Runs | Does not run |
| Worker after exceeding the memory limit | Reused | Exits; FPM starts a new one |
| Fatal error and worker exit records in the FPM log | None | Present |
| 4 normal requests right after exceeding the memory limit | All succeed | All succeed |

## Notes
- FPM in 7.1 and 7.0 tries to open `listen = 9000` on IPv6 and fails to start in containers without IPv6. The smoke test switches it to `127.0.0.1:9000` (an environment issue unrelated to the patch).
- The Debian releases in these images are all end-of-life, so archive.debian.org is used. Debian 9 is fetched with `trusted=yes` because its signing keys have expired. This is a test-only setting.

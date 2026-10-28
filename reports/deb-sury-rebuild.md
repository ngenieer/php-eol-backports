# Sury PHP rebuilds for Debian 10 / Ubuntu 18.04: verification (2026-10-25)

## Background: where Debian-family systems can get the fix
Results of checking the repositories and security trackers directly, as of 2026-10-25.

| Installed from | PHP2Shell fix | How to get it |
|---|---|---|
| Debian 9 default php7.0 | `7.0.33-0+deb9u26` (ELA-1855-1) | Freexian ELTS repository (publicly accessible) |
| Debian 10 default php7.3 | `7.3.31-1~deb10u16` (ELA-1854-1) | Freexian ELTS repository (publicly accessible) |
| Ubuntu 16.04 default php7.0 | `7.0.33-0ubuntu0.16.04.16+esm22` | Ubuntu Pro (ESM) |
| Ubuntu 18.04 default php7.2 | `7.2.24-0ubuntu0.18.04.17+esm14` | Ubuntu Pro (ESM) |
| Sury, Debian 11–13 / Ubuntu 22.04+ | php7.0 -92, 7.1 -80, 7.2 -66, 7.3 -35 | packages.sury.org, `ppa:ondrej/php` |
| **Sury, Debian 9/10 / Ubuntu 16.04–20.04** | **None** | Sury no longer builds for these releases (the buster repository returns 404; the last PPA build for bionic is php7.2 -39 from 2023) |

The servers with no way to get the fix are **end-of-life distribution releases with PHP installed from Sury**. Falling back to the distribution's own package would actually lower the version (7.3.33 → 7.3.31, 7.2.34 → 7.2.24). So **Sury's current source was rebuilt as is on those releases**. Sury's source already contains the PHP2Shell fix, so this repository's patch was not added. The comparison of the two patches is in [sury-crosscheck.md](sury-crosscheck.md).

## What was built

| Target | Source | Package version | Count |
|---|---|---|---|
| Debian 10 buster | Sury php7.3 `7.3.33-35` | `7.3.33-35+0~20261021.144+debian10~1.gbpecf76f+sizlon1` | 39 (+ 36 dbgsym) |
| Ubuntu 18.04 bionic | Sury php7.2 `7.2.34-66` | `7.2.34-66+0~20261021.122+ubuntu18.04~1.gbpe0bcd4+sizlon1` | 39 |

- To reproduce: `deb/build.sh <buster|bionic> <x.y> <out>`, `deb/verify.sh <buster|bionic> <x.y> <out>`. `build.sh` also writes `<out>/fix/SHA256SUMS` for the release, with the asset names GitHub serves ("~" becomes "."). Source versions and SHA256 hashes are pinned in `deb/sources.txt`.
- The source was not modified; only one changelog entry was added. For verification, a `+base0` build of the same source with only the PHP2Shell patch removed was also made.
- The versions are higher than the earlier Sury builds (`-39` etc.) and the distribution packages, so `apt install` upgrades them in place.

### php-common dependency
These packages require `php-common (>= 1:81~)`.
- Debian 10 default `2:69`: satisfies it, because the epoch is 2.
- Servers already using Sury: Sury's `2:9x` is installed and satisfies it.
- Ubuntu 18.04 default `1:60`: does **not** satisfy it. A bionic server not using Sury must also install Sury's php-common, which can conflict (Breaks) with old PECL extension packages such as php-redis. Such servers are better off with Ubuntu Pro (ESM).

## Verification A: apt upgrade
The distribution's own PHP (`php*-cli common fpm mysql gd opcache mbstring xml json`) was installed and the FPM smoke test run. Then every installed php package was replaced with the rebuilt package via `apt install`, and the same test was run again. On bionic, Sury's php-common was installed as well, for the reason above.

| Item | buster 7.3.31-1~deb10u7 → rebuild | bionic 7.2.24-0ubuntu0.18.04.17 → rebuild |
|---|---|---|
| Dependency problems, packages left un-upgraded | None | None |
| opcache, mysqli, pdo_mysql, gd, session | OK | OK |
| Nested GET/POST arrays, multipart upload, session persistence | Same | Same |
| Response on memory limit | 500 → empty response (502 in nginx) | 500 → empty response (502 in nginx) |
| Shutdown function on memory limit | Runs → does not run | Runs → does not run |
| Worker after exceeding the memory limit | Reused → exits, new one started | Reused → exits, new one started |
| 4 normal requests right after exceeding the memory limit | Succeed | Succeed |

The FPM log file (`/var/log/php7.x-fpm.log`) keeps the entries from before the upgrade, so `fpm_log_fatal` is a cumulative value.

## Verification B: regression tests
PHP's test suites were compared between packages built from the same Sury source without the PHP2Shell patch (`+base0`) and with it (`+sizlon1`). php-cgi was installed too, so the upload progress tests actually ran.

| | buster unpatched | buster patched | bionic unpatched | bionic patched |
|---|---|---|---|---|
| Passed | 6,194 | 6,185 | 5,997 | 5,988 |
| Failed | 10 | 19 | 10 | 19 |

On both releases, **the 9 tests that fail only after the patch are exactly the same as for the official 7.4 backport** (upload progress 8 + memory limit 1, see EXPECTED-CHANGES.md).

## Limitations
- These are not packages made by Sury and do not carry Sury's signature. Distributing them through an apt repository requires a separate signing key.
- The actual previous state of such servers (old Sury buster/bionic builds) can no longer be downloaded since Sury removed it, so the upgrade was verified from the distribution's own packages instead.
- Only the 7.3/buster and 7.2/bionic combinations were built. Other combinations can be built the same way by adding the source to `deb/sources.txt` and the release to `deb/build.sh` and `deb/verify.sh`, but they have not been verified.
- The vulnerabilities were not reproduced to confirm the fix.

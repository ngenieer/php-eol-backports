# php-eol-backports

**English** | [한국어](README.ko.md)

**Unofficial** backports of the PHP2Shell fix (CVE-2026-109618, CVE-2026-109619) to **end-of-life PHP 7.0–7.3**.

> Not produced, reviewed or endorsed by the PHP project. Use at your own risk.

## Which fix applies to you

Find out what you run: `php -v`, then `rpm -qa 'php*'` (CentOS) or `apt-cache policy php7.3-common` (Debian/Ubuntu, with your PHP version) to see where the packages came from.

| Your system | What to do |
|---|---|
| PHP 7.4, 8.0, 8.1 | Official source backports exist (php-src branches `PHP-x.y-CVE-2026-109618-109619`), or use your vendor's package. Not covered here |
| Debian or Ubuntu, the distribution's own PHP | Use the vendor fix, see [Debian and Ubuntu users](#debian-and-ubuntu-users) |
| CentOS 7, Remi `remi-php73` repository (packages named `php-cli`, `php-fpm`, …, version `7.3.33-*.el7.remi`) | Install the RPMs, see [Installing the packages](#installing-the-packages) |
| Debian 10, Sury php7.3 | Install the .debs, see [Installing the packages](#installing-the-packages) |
| Ubuntu 18.04, Sury php7.2 | Install the .debs, see [Installing the packages](#installing-the-packages) |
| Anything else on PHP 7.0–7.3: CentOS 7 with Remi php70–php72 or Remi's `php73-php-*` collection, Sury on Debian 9 / Ubuntu 16.04 / 20.04 or other PHP versions, PHP built from source, official `php:7.x` Docker images | No package here. Patch the source, see [Building from source](#building-from-source) |

Whatever you choose, read [EXPECTED-CHANGES.md](EXPECTED-CHANGES.md) first and try it on a staging server: requests that exceed the memory limit now end with a 502 from nginx, and session upload progress stops working.

## Installing the packages

The packages are unsigned and not made by php.net, Remi or Sury. The steps below download only the packages you already have installed, check them against the release's SHA256SUMS, and upgrade them in place.

### CentOS 7 + Remi php73

```bash
TAG=el7-php73-7.3.33-23.sizlon1 VR=7.3.33-23.sizlon1
URL=https://github.com/ngenieer/php-eol-backports/releases/download/$TAG
mkdir -p ~/php-update && cd ~/php-update
curl -fsSLO "$URL/SHA256SUMS"
for p in $(rpm -qa 'php*' --qf '%{NAME}\n'); do
  f="$p-$VR.el7.x86_64.rpm"
  if awk -v f="$f" '$2 == f' SHA256SUMS | grep -q .; then
    curl -fsSLO "$URL/$f"; awk -v f="$f" '$2 == f' SHA256SUMS >> SHA256SUMS.mine
  else echo "not in this release: $p"; fi
done
sha256sum -c SHA256SUMS.mine          # every line must say OK
sudo yum localinstall ./*.rpm
sudo systemctl restart php-fpm        # and/or httpd when PHP runs as mod_php
```

Check: `rpm -q --changelog php-common | head -3` shows the `sizlon1` entry, and `rpm -qa 'php*' | grep -v sizlon1` lists only packages this release does not replace, such as `php-pecl-*` extensions. Run `php -v` and check that no extension fails to load; one that does must be rebuilt for the new package.

Roll back: `sudo yum --enablerepo=remi-php73 history undo last` returns to Remi's 7.3.33-14, which is still in the `remi-php73` repository.

### Debian 10 + Sury php7.3, Ubuntu 18.04 + Sury php7.2

On Ubuntu 18.04 use `TAG=deb-bionic-php7.2-7.2.34-66-sizlon1 X=7.2`. These packages need Sury's `php-common` (1:81 or later); servers that used the Sury PPA already have it.

```bash
TAG=deb-buster-php7.3-7.3.33-35-sizlon1 X=7.3
URL=https://github.com/ngenieer/php-eol-backports/releases/download/$TAG
mkdir -p ~/php-update && cd ~/php-update
dpkg-query -W -f '${db:Status-Abbrev} ${Package} ${Version}\n' "php$X*" "libapache2-mod-php$X" "libphp$X-embed" 2>/dev/null \
  | awk '$1 == "ii" {print $2, $3}' > versions-before.txt
curl -fsSLO "$URL/SHA256SUMS"
for p in $(awk '{print $1}' versions-before.txt); do
  if awk -v p="${p}_" 'index($2, p) == 1' SHA256SUMS | grep -q .; then
    awk -v p="${p}_" 'index($2, p) == 1' SHA256SUMS | tee -a SHA256SUMS.mine | while read -r h f; do curl -fsSLO "$URL/$f"; done
  else echo "not in this release: $p"; fi
done
sha256sum -c SHA256SUMS.mine          # every line must say OK
sudo apt install ./*.deb
sudo systemctl restart php$X-fpm      # and/or apache2 when PHP runs as mod_php
```

Check: `dpkg-query -W -f '${db:Status-Abbrev} ${Package} ${Version}\n' "php$X*" | awk '$1 == "ii" && $3 !~ /sizlon1/'` prints nothing, and `zcat /usr/share/doc/php$X-common/changelog.Debian.gz | head -4` shows the `sizlon1` entry.

Roll back: `sudo apt install --allow-downgrades $(awk '{print $1"="$2}' versions-before.txt)`. This only works if the old versions can still be downloaded; Sury no longer serves these releases, so keep copies of the old .deb files (`/var/cache/apt/archives`) before upgrading if you may need to go back.

### Cross-check the checksums (optional)

Each release's SHA256SUMS is also committed to this repository, so a changed release asset would not match the git history:

```bash
curl -fsSL "https://raw.githubusercontent.com/ngenieer/php-eol-backports/main/checksums/$TAG.sha256" | diff - SHA256SUMS && echo same
```

## Status

| Branch | Base version | Status | Derived from |
|---|---|---|---|
| 7.4 / 8.0 / 8.1 | — | Official source backports exist (out of scope here) | php-src branches `PHP-x.y-CVE-2026-109618-109619` |
| 7.3 | 7.3.33 | Ported and verified ([report](reports/7.3.md)) | Official 7.4 backport (712e60f9ed) |
| 7.2 | 7.2.34 | Ported and verified ([report](reports/7.2.md)) | The 7.3 backport |
| 7.1 | 7.1.33 | Ported and verified ([report](reports/7.1.md)) | The 7.2 backport; the shutdown changes were rewritten with the same intent |
| 7.0 | 7.0.33 | Ported and verified ([report](reports/7.0.md)) | The 7.1 backport |

On every version, the set of tests that fail only after patching is identical to that of the official 7.4 backport (9 tests, see [EXPECTED-CHANGES.md](EXPECTED-CHANGES.md)). The patches were also compared with Sury's independent ports of the same backport ([report](reports/sury-crosscheck.md)), which led to one fix in the 7.3 and 7.2 patches (2026-10-25). Results on the official Docker images with real PHP-FPM requests are in [reports/docker.md](reports/docker.md).

### Packages (RPM, deb)

| Target | Status | Notes |
|---|---|---|
| CentOS 7 + Remi php73 | Built and verified ([report](reports/el7-remi-php73.md)) | Remi 7.3.33-23 source (includes the fix) plus the missing handler reset → `7.3.33-23.sizlon1.el7`. In-place `yum` upgrade verified from Remi el7 (-14) and from the earlier `22.sizlon1` |

The RPMs are attached to the release [`el7-php73-7.3.33-23.sizlon1`](../../releases/tag/el7-php73-7.3.33-23.sizlon1) (with SHA256SUMS, no GPG signature). The earlier release `22.sizlon1` was built before the 7.3 patch fix and is superseded.

| Target | Status | Notes |
|---|---|---|
| Debian 10 + Sury php7.3 | Built and verified ([report](reports/deb-sury-rebuild.md)) | Sury 7.3.33-35 source (includes the fix) rebuilt on buster → `…+debian10~1.gbpecf76f+sizlon1` |
| Ubuntu 18.04 + Sury php7.2 | Built and verified ([report](reports/deb-sury-rebuild.md)) | Sury 7.2.34-66 source (includes the fix) rebuilt on bionic → `…+ubuntu18.04~1.gbpe0bcd4+sizlon1` |

The .deb packages are attached to the releases [`deb-buster-php7.3-7.3.33-35-sizlon1`](../../releases/tag/deb-buster-php7.3-7.3.33-35-sizlon1) and [`deb-bionic-php7.2-7.2.34-66-sizlon1`](../../releases/tag/deb-bionic-php7.2-7.2.34-66-sizlon1) (with SHA256SUMS, unsigned).

### Debian and Ubuntu users
If you use your distribution's own PHP, a vendor fix already exists. Prefer the vendor package over anything in this repository.

| Installed from | Fixed package |
|---|---|
| Debian 9 php7.0 / Debian 10 php7.3 | Freexian ELTS repository (`7.0.33-0+deb9u26`, `7.3.31-1~deb10u16`) |
| Ubuntu 16.04 php7.0 / 18.04 php7.2 | Ubuntu Pro ESM (`+esm22`, `+esm14`) |
| Sury, Debian 11+ / Ubuntu 22.04+ | packages.sury.org, `ppa:ondrej/php` (php7.3 -35, 7.2 -66, 7.1 -80, 7.0 -92 or later) |
| **Sury, Debian 9/10 / Ubuntu 16.04–20.04** | **None** (Sury no longer builds for these releases). Rebuilt packages exist here only for Debian 10 php7.3 and Ubuntu 18.04 php7.2; for anything else, see [Building from source](#building-from-source) |

## Principles

- Each patch is based on the **official 7.4 EOL backport** in php-src (Arnaud Le Blanc, Ilija Tovilo) and only adapted to the structure of the target version, without changing its meaning.
- The generated file `Zend/zend_vm_execute.h` is never edited by hand; it is regenerated with that version's `zend_vm_gen.php`. For versions where running the old generator under a current PHP introduces unrelated differences (7.1, 7.0), only the difference between the regenerated unpatched and patched outputs is applied to the shipped file.
- The official EOL backport has no regression tests that can be ported to these versions. Verification is therefore done by **running each version's full existing test suite before and after the patch and comparing the results** (`scripts/compare-tests.sh`). No exploit code is used.
- These patches reduce exposure; they do not make anything safe. Move to a supported version (8.3 or later recommended; 8.2 support ends on 2026-12-31) as soon as you can.

**Read [EXPECTED-CHANGES.md](EXPECTED-CHANGES.md) before applying.** As with the official fix, session upload progress is disabled and the process exits immediately when the memory limit is exceeded.

## Building from source

The patches are made for the last release of each branch: 7.3.33, 7.2.34, 7.1.33 and 7.0.33. On an older release of the same branch they may not apply; move to the last release first.

```bash
# 1. Note the configure options of the PHP you run now
php -i | grep 'Configure Command'
# 2. Get the source of the last release of your branch (https://www.php.net/releases/) and apply the patch
tar xf php-7.3.33.tar.gz
git clone https://github.com/ngenieer/php-eol-backports
php-eol-backports/scripts/apply.sh php-7.3.33
# 3. Configure with the same options, then make && make install, and restart every PHP worker (php-fpm, Apache)
```

For the official `php:7.x-fpm` Docker images, [docker/Dockerfile](docker/Dockerfile) shows how to rebuild the image's own PHP with its original configure options and the patch applied. It is a test image: leave out its archive.debian.org `trusted=yes` setting in production.

If PHP was installed from distribution packages (apt/yum), check your distribution's or LTS vendor's security notices first.

## Configuration mitigations to apply as well

Independently of the patch, applying the officially recommended settings is advised:

- `session.upload_progress.enabled = 0` (php.ini or FPM pool configuration, then restart every worker)
- For services without file uploads, limit request size and multipart requests at the web server or proxy

## Layout

```
patches/<x.y>/NNNN-*.patch   per-version patches (git format-patch)
scripts/apply.sh             apply the patch to a source tree
scripts/compare-tests.sh     build unpatched/patched and compare PHP test results (minimal build)
docker/Dockerfile            rebuild the PHP of the official php:<x.y>-fpm image with its own options (+mysqli, pdo_mysql, gd, opcache)
docker/verify.sh             per version: build unpatched/patched images → compare tests → compare FPM smoke tests
docker/smoke/                FastCGI requests to FPM: GET/POST arrays, uploads, sessions, opcache, memory-limit behaviour
rpm/el7/                     CentOS 7 RPM build and verification (based on Remi SRPMs; per-version patches and spec changes)
deb/                         Debian 10 / Ubuntu 18.04 rebuilds of Sury PHP and verification (sources pinned in deb/sources.txt)
reports/<x.y>.md             per-version verification results (minimal build)
reports/docker.md            Docker verification results (all versions)
checksums/<tag>.sha256       SHA256 of each release's packages, matching the release's SHA256SUMS
RELEASING.md                 how packages are built, checked and published as releases
```

## Verifying with Docker

```bash
docker/verify.sh 7.3          # one version
docker/verify.sh              # all of 7.3 7.2 7.1 7.0 (about 20 minutes per version on 2 cores)
```

The Debian releases inside these Docker images are all end-of-life, so packages come from archive.debian.org. For stretch (7.0) the archive signing keys have expired and packages are fetched with `trusted=yes`. **This is a test-only setting; do not copy it into a production Dockerfile.**

## License

All files in this repository (patches, scripts, documentation) are distributed under the [PHP License 3.01](LICENSE), because the patches are derived from the PHP source.

As required by clause 4 of the PHP License, packages built from this repository are not made or endorsed by the PHP Group.

# Releasing packages

How rebuilt RPM and .deb packages are published as GitHub releases. The patches themselves are not released; they live on `main`.

## Names

| Target | Tag | Title |
|---|---|---|
| CentOS 7 + Remi | `el7-php73-<version>-<release>.sizlonN` (e.g. `el7-php73-7.3.33-24.sizlon1`) | `CentOS 7 Remi php73 7.3.33-24.sizlon1 (PHP2Shell)` |
| Debian / Ubuntu + Sury | `deb-<dist>-php<x.y>-<sury-version>-sizlonN` (e.g. `deb-buster-php7.3-7.3.33-35-sizlon1`) | `Debian 10 Sury php7.3 7.3.33-35 rebuild (PHP2Shell)` |

`sizlonN` is the package's own release suffix. Raise `N` when the same upstream source is rebuilt with a change on our side.

## 1. Build and verify

deb:
```bash
deb/build.sh buster 7.3 out/buster-7.3     # writes out/buster-7.3/fix/*.deb and fix/SHA256SUMS
deb/verify.sh buster 7.3 out/buster-7.3
```

el7:
```bash
rpm/el7/build.sh out/el7                     # writes out/el7/{fix,base}/*.rpm, fix/SHA256SUMS and src/
rpm/el7/verify.sh out/el7 out/el7/src out/el7/results
```
For a new Remi release, update `SRPM`, `SUM` and `VR` in `rpm/el7/build.sh` (check the SRPM's signature with Remi's key on an EL8/EL9 system first) and the `Release:` line and changelog in `php73.spec.diff`.

Update the matching report in `reports/` with the results before publishing. Do not release a build whose regression list differs from the 9 tests in [EXPECTED-CHANGES.md](EXPECTED-CHANGES.md) without explaining why in the report.

SHA256SUMS lists asset names with `~` replaced by `.`, because GitHub renames uploaded files that way. `deb/build.sh` and `rpm/el7/build.sh` (through `rpm/el7/sha256sums.sh`) do this; a hand-written SHA256SUMS must too.

## 2. Publish

Write the notes in English. Start from the notes of the previous release for the same target and update the versions:

```bash
gh release view <previous-tag> --json body --jq .body > notes.md
```

The notes keep these parts: an **Unofficial** first line, the base source and version, links to the report and EXPECTED-CHANGES.md, the install commands from the README's "Installing the packages" section (with the new tag; CentOS 7's `sha256sum` has no `--ignore-missing`), and the note that the packages are unsigned and not endorsed by php.net, Remi or Sury.

```bash
# el7
gh release create el7-php73-7.3.33-24.sizlon1 --target main \
  --title "CentOS 7 Remi php73 7.3.33-24.sizlon1 (PHP2Shell)" --notes-file notes.md \
  <rpm-dir>/fix/*-7.3.33-24.sizlon1.el7.*.rpm <rpm-dir>/fix/SHA256SUMS

# deb: only the el7 release is marked Latest
gh release create deb-buster-php7.3-7.3.33-35-sizlon1 --target main --latest=false \
  --title "Debian 10 Sury php7.3 7.3.33-35 rebuild (PHP2Shell)" --notes-file notes.md \
  out/buster-7.3/fix/*+sizlon1_*.deb out/buster-7.3/fix/SHA256SUMS
```

Check the release as a user would get it:

```bash
mkdir /tmp/check && gh release download <tag> -D /tmp/check
(cd /tmp/check && sha256sum -c SHA256SUMS)   # every line must say OK
```

## 3. Record it on main

```bash
cp <dir>/fix/SHA256SUMS checksums/<tag>.sha256
```

Update the release links, version strings and the `TAG=` lines of the install commands in both `README.md` and `README.ko.md`, then commit the checksums, the READMEs and the report together.

## Superseding a release

When a release turns out to be wrong (as `el7-php73-7.3.33-22.sizlon1` did):

1. Publish the fixed build as a new release with a higher release number or `sizlonN`, and verify an in-place upgrade from the old one.
2. Put a **Superseded** notice at the top of the old release's notes that says why and links the new release.
3. Delete the old release's assets (`gh release delete-asset <tag> <file> -y`) so the broken packages can no longer be downloaded, and mark it as a pre-release. Keep the release page and tag: the reports and SECURITY.md refer to them.
4. Remove `checksums/<old-tag>.sha256` and point the READMEs to the new release.

When a release is replaced but not wrong (as `el7-php73-7.3.33-23.sizlon1` was, when Remi -24 included its extra patch), do the same except step 3's deletion: keep its assets, say in the notice that it remains safe to run, and mark it as a pre-release.

## Repository rules

- `Protect main`: `main` cannot be force-pushed or deleted.
- `Protect release tags`: tags matching `el7-*` and `deb-*` cannot be deleted or moved, so a release's tag is final once created. If a tag really has to change, disable the ruleset in Settings → Rules, make the change, and enable it again.

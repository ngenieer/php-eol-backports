# php-eol-backports

[English](README.md) | **한국어**

PHP2Shell(CVE-2026-109618, CVE-2026-109619) 수정을 **공식 지원이 끝난 PHP 7.0~7.3**에 옮긴 **비공식 백포트**입니다.

> Unofficial backports of the PHP2Shell fix (CVE-2026-109618 / CVE-2026-109619) to end-of-life PHP 7.0–7.3.
> Not produced, reviewed or endorsed by the PHP project. Use at your own risk.

## 내 서버에 맞는 방법

먼저 무엇을 쓰고 있는지 확인하세요: `php -v`, 그리고 `rpm -qa 'php*'`(CentOS) 또는 `apt-cache policy php7.3-common`(Debian/Ubuntu, PHP 버전에 맞게)으로 패키지 출처를 봅니다.

| 내 서버 | 할 일 |
|---|---|
| PHP 7.4, 8.0, 8.1 | 공식 소스 백포트가 있습니다 (php-src 브랜치 `PHP-x.y-CVE-2026-109618-109619`). 또는 벤더 패키지를 쓰세요. 이 레포 대상 아님 |
| Debian·Ubuntu 배포판 기본 PHP | 벤더 수정을 쓰세요. [Debian·Ubuntu 사용자](#debianubuntu-사용자) 참고 |
| CentOS 7, Remi `remi-php73` 저장소 (패키지 이름 `php-cli`, `php-fpm` …, 버전 `7.3.33-*.el7.remi`) | RPM 설치, [패키지 설치](#패키지-설치) 참고 |
| Debian 10, Sury php7.3 | .deb 설치, [패키지 설치](#패키지-설치) 참고 |
| Ubuntu 18.04, Sury php7.2 | .deb 설치, [패키지 설치](#패키지-설치) 참고 |
| 그 밖의 PHP 7.0~7.3: CentOS 7의 Remi php70~php72나 Remi `php73-php-*` 컬렉션, Debian 9 / Ubuntu 16.04 / 20.04의 Sury 또는 다른 PHP 버전, 소스로 직접 빌드한 PHP, 공식 `php:7.x` Docker 이미지 | 여기에는 패키지가 없습니다. 소스에 패치하세요. [소스로 빌드](#소스로-빌드) 참고 |

어느 방법이든 먼저 [EXPECTED-CHANGES.md](EXPECTED-CHANGES.md)를 읽고 스테이징 서버에서 확인하세요. 메모리 한도를 넘는 요청은 nginx에서 502로 끝나고, 세션 업로드 진행 기능은 동작하지 않게 됩니다.

## 패키지 설치

패키지는 서명이 없고 php.net·Remi·Sury가 만든 것이 아닙니다. 아래 명령은 서버에 이미 설치된 패키지만 내려받아 릴리스의 SHA256SUMS로 확인한 뒤 제자리 업그레이드합니다.

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

확인: `rpm -q --changelog php-common | head -3`에 `sizlon1` 항목이 보여야 하고, `rpm -qa 'php*' | grep -v sizlon1`에는 이 릴리스가 바꾸지 않는 패키지(예: `php-pecl-*` 확장)만 나와야 합니다. `php -v`로 확장이 모두 로드되는지 보세요. 로드되지 않는 확장은 새 패키지에 맞게 다시 빌드해야 합니다.

되돌리기: `sudo yum --enablerepo=remi-php73 history undo last`로 Remi 7.3.33-14로 돌아갑니다. -14는 아직 `remi-php73` 저장소에 있습니다.

### Debian 10 + Sury php7.3, Ubuntu 18.04 + Sury php7.2

Ubuntu 18.04에서는 `TAG=deb-bionic-php7.2-7.2.34-66-sizlon1 X=7.2`를 쓰세요. 이 패키지는 Sury의 `php-common`(1:81 이상)이 필요합니다. Sury PPA를 쓰던 서버에는 이미 있습니다.

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

확인: `dpkg-query -W -f '${db:Status-Abbrev} ${Package} ${Version}\n' "php$X*" | awk '$1 == "ii" && $3 !~ /sizlon1/'`가 아무것도 출력하지 않고, `zcat /usr/share/doc/php$X-common/changelog.Debian.gz | head -4`에 `sizlon1` 항목이 보여야 합니다.

되돌리기: `sudo apt install --allow-downgrades $(awk '{print $1"="$2}' versions-before.txt)`. 이전 버전을 아직 내려받을 수 있을 때만 됩니다. Sury는 이 배포판들을 더 이상 제공하지 않으므로, 되돌릴 가능성이 있다면 업그레이드 전에 이전 .deb 파일(`/var/cache/apt/archives`)을 따로 보관하세요.

### 체크섬 교차 확인 (선택)

각 릴리스의 SHA256SUMS는 이 저장소에도 커밋되어 있어서, 릴리스 파일이 바뀌면 git 기록과 맞지 않게 됩니다:

```bash
curl -fsSL "https://raw.githubusercontent.com/ngenieer/php-eol-backports/main/checksums/$TAG.sha256" | diff - SHA256SUMS && echo same
```

## 상태

| 브랜치 | 기준 버전 | 상태 | 출처 |
|---|---|---|---|
| 7.4 / 8.0 / 8.1 | — | 공식 소스 백포트 있음 (이 레포 대상 아님) | php-src `PHP-x.y-CVE-2026-109618-109619` 브랜치 |
| 7.3 | 7.3.33 | 포팅·검증 완료 ([보고서](reports/7.3.md)) | 7.4 공식 백포트(712e60f9ed)에서 포팅 |
| 7.2 | 7.2.34 | 포팅·검증 완료 ([보고서](reports/7.2.md)) | 7.3 백포트에서 포팅 |
| 7.1 | 7.1.33 | 포팅·검증 완료 ([보고서](reports/7.1.md)) | 7.2 백포트에서 포팅, 종료 처리는 같은 의도로 새로 작성 |
| 7.0 | 7.0.33 | 포팅·검증 완료 ([보고서](reports/7.0.md)) | 7.1 백포트에서 포팅 |

모든 버전에서 "패치 후에만 실패하는 테스트" 목록이 7.4 공식 백포트와 같습니다(9개, [EXPECTED-CHANGES.md](EXPECTED-CHANGES.md)). 같은 백포트를 따로 옮긴 Sury 패키지의 패치와도 비교했습니다([보고서](reports/sury-crosscheck.md)). 그 결과로 7.3·7.2 패치를 한 곳 고쳤습니다(2026-10-25). 공식 Docker 이미지 구성 + PHP-FPM 실요청 검증 결과는 [reports/docker.md](reports/docker.md)에 있습니다.

### 패키지(RPM·deb)

| 대상 | 상태 | 비고 |
|---|---|---|
| CentOS 7 + Remi php73 | 빌드·검증 완료 ([보고서](reports/el7-remi-php73.md)) | Remi 7.3.33-23 소스(수정 포함) + 빠진 핸들러 초기화 보충 → `7.3.33-23.sizlon1.el7`. Remi el7(-14)과 이전 `22.sizlon1`에서 yum 제자리 업그레이드 확인 |

빌드된 RPM은 [Release `el7-php73-7.3.33-23.sizlon1`](../../releases/tag/el7-php73-7.3.33-23.sizlon1)에 있습니다 (SHA256SUMS 포함, GPG 서명 없음). 이전 릴리스 `22.sizlon1`은 7.3 패치를 고치기 전에 빌드한 것이라 대체했습니다.

| 대상 | 상태 | 비고 |
|---|---|---|
| Debian 10 + Sury php7.3 | 빌드·검증 완료 ([보고서](reports/deb-sury-rebuild.md)) | Sury 7.3.33-35 소스(수정 포함)를 buster에서 재빌드 → `…+debian10~1.gbpecf76f+sizlon1` |
| Ubuntu 18.04 + Sury php7.2 | 빌드·검증 완료 ([보고서](reports/deb-sury-rebuild.md)) | Sury 7.2.34-66 소스(수정 포함)를 bionic에서 재빌드 → `…+ubuntu18.04~1.gbpe0bcd4+sizlon1` |

빌드된 .deb는 Release [`deb-buster-php7.3-7.3.33-35-sizlon1`](../../releases/tag/deb-buster-php7.3-7.3.33-35-sizlon1), [`deb-bionic-php7.2-7.2.34-66-sizlon1`](../../releases/tag/deb-bionic-php7.2-7.2.34-66-sizlon1)에 있습니다 (SHA256SUMS 포함, 서명 없음).

### Debian·Ubuntu 사용자
배포판 기본 PHP를 쓴다면 벤더 수정이 이미 있습니다. 이 레포보다 벤더 패키지를 먼저 쓰세요.

| 설치 경로 | 수정 패키지 |
|---|---|
| Debian 9 php7.0 / Debian 10 php7.3 | Freexian ELTS 저장소 (`7.0.33-0+deb9u26`, `7.3.31-1~deb10u16`) |
| Ubuntu 16.04 php7.0 / 18.04 php7.2 | Ubuntu Pro ESM (`+esm22`, `+esm14`) |
| Sury, Debian 11 이상 / Ubuntu 22.04 이상 | packages.sury.org, `ppa:ondrej/php` (php7.3 -35, 7.2 -66, 7.1 -80, 7.0 -92 이상) |
| **Sury, Debian 9·10 / Ubuntu 16.04~20.04** | **없음** (Sury가 이 배포판들의 빌드를 중단함). 여기에 재빌드 패키지가 있는 것은 Debian 10 php7.3과 Ubuntu 18.04 php7.2뿐이고, 나머지는 [소스로 빌드](#소스로-빌드) 참고 |

## 원칙

- 각 패치는 php-src의 **7.4 공식 EOL 백포트**(Arnaud Le Blanc, Ilija Tovilo)를 기준으로, 의미를 바꾸지 않고 해당 버전 구조에 맞게만 옮깁니다.
- 자동 생성 파일(`Zend/zend_vm_execute.h`)은 손으로 고치지 않고 해당 버전의 `zend_vm_gen.php`로 다시 생성합니다. 최신 PHP로 구버전 생성기를 돌리면 무관한 차이가 생기는 버전(7.1, 7.0)은 원본·패치본 재생성 결과의 차이만 출시본에 적용합니다.
- 공식 EOL 백포트에는 이 버전들에 이식 가능한 회귀 테스트가 없습니다. 그래서 검증은 **해당 버전의 기존 테스트 전체를 패치 전후로 돌려 결과가 같은지 비교**하는 방식으로 합니다 (`scripts/compare-tests.sh`). 공격 코드로 재현하는 방식은 쓰지 않습니다.
- 이 패치는 취약점을 줄이기 위한 것이지, 안전을 보장하지 않습니다. 가능한 한 빨리 지원되는 버전(8.3 이상 권장, 8.2는 2026-12-31 지원 종료)으로 옮기세요.

**적용 전 반드시 [EXPECTED-CHANGES.md](EXPECTED-CHANGES.md)를 읽으세요.** 공식 패치와 마찬가지로 세션 업로드 진행 기능이 꺼지고, 메모리 한도 초과 시 프로세스가 즉시 종료됩니다.

## 소스로 빌드

패치는 각 브랜치의 마지막 릴리스(7.3.33, 7.2.34, 7.1.33, 7.0.33)에 맞춰 만들었습니다. 같은 브랜치라도 이전 릴리스에는 적용되지 않을 수 있으니, 먼저 마지막 릴리스로 옮기세요.

```bash
# 1. 지금 쓰는 PHP의 configure 옵션 확인
php -i | grep 'Configure Command'
# 2. 브랜치의 마지막 릴리스 소스(https://www.php.net/releases/)를 받아 패치 적용
tar xf php-7.3.33.tar.gz
git clone https://github.com/ngenieer/php-eol-backports
php-eol-backports/scripts/apply.sh php-7.3.33
# 3. 같은 옵션으로 configure 후 make && make install, 모든 PHP 워커(php-fpm, Apache) 재시작
```

공식 `php:7.x-fpm` Docker 이미지는 [docker/Dockerfile](docker/Dockerfile)에서 이미지 자체의 PHP를 원래 configure 옵션 그대로, 패치를 넣어 다시 빌드하는 방법을 볼 수 있습니다. 테스트용 이미지이므로 운영 환경에서는 archive.debian.org `trusted=yes` 설정을 빼세요.

배포판 패키지(apt/yum)로 설치한 PHP라면 배포판·LTS 벤더의 보안 공지를 먼저 확인하세요.

## 함께 적용할 설정 완화책

패치와 별개로 공식 권고 설정도 같이 적용하는 것을 권장합니다.

- `session.upload_progress.enabled = 0` (php.ini 또는 FPM 풀 설정, 이후 모든 워커 재시작)
- 파일 업로드가 없는 서비스는 웹서버·프록시에서 요청 크기와 multipart 요청을 제한

## 레이아웃

```
patches/<x.y>/NNNN-*.patch   버전별 패치 (git format-patch)
scripts/apply.sh             소스 트리에 패치 적용
scripts/compare-tests.sh     패치 전/후 빌드 후 PHP 테스트 결과 비교 (최소 구성)
docker/Dockerfile            공식 php:<x.y>-fpm 이미지의 PHP를 같은 옵션으로 재빌드(+mysqli, pdo_mysql, gd, opcache)
docker/verify.sh             버전별 원본/패치본 이미지 빌드 → 테스트 비교 → FPM 스모크 테스트 비교
docker/smoke/                FPM에 FastCGI 요청: GET/POST 배열, 업로드, 세션, opcache, 메모리 초과 동작
rpm/el7/                     CentOS 7용 RPM 빌드·검증 (Remi SRPM 기반, 버전별 패치와 spec 변경)
deb/                         Debian 10 / Ubuntu 18.04용 Sury PHP 재빌드·검증 (소스는 deb/sources.txt에 고정)
reports/<x.y>.md             버전별 검증 결과 (최소 구성)
reports/docker.md            Docker 실환경 검증 결과 (전 버전)
checksums/<tag>.sha256       릴리스별 패키지 SHA256 (릴리스의 SHA256SUMS와 같음)
RELEASING.md                 패키지 빌드·확인·릴리스 게시 절차 (영어)
```

## Docker로 검증하기

```bash
docker/verify.sh 7.3          # 한 버전
docker/verify.sh              # 7.3 7.2 7.1 7.0 전부 (2코어 기준 버전당 약 20분)
```

Docker 이미지 안의 Debian은 모두 지원이 끝난 배포판이라 archive.debian.org를 씁니다. stretch(7.0)는 아카이브 서명 키가 만료돼 `trusted=yes`로 받습니다. **테스트 전용 설정이니 운영용 Dockerfile에 옮기지 마세요.**

## 라이선스

이 레포의 모든 파일(패치, 스크립트, 문서)은 [PHP License 3.01](LICENSE)을 따릅니다. 패치가 PHP 소스에서 파생되었기 때문입니다.

PHP License 4조에 따라, 이 레포에서 빌드한 패키지는 PHP Group이 만들거나 보증한 것이 아닙니다.

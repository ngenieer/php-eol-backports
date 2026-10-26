# php-eol-backports

PHP2Shell(CVE-2026-109618, CVE-2026-109619) 수정을 **공식 지원이 끝난 PHP 7.0~7.3**에 옮긴 **비공식 백포트**입니다.

> Unofficial backports of the PHP2Shell fix (CVE-2026-109618 / CVE-2026-109619) to end-of-life PHP 7.0–7.3.
> Not produced, reviewed or endorsed by the PHP project. Use at your own risk.

## 상태

| 브랜치 | 기준 버전 | 상태 | 출처 |
|---|---|---|---|
| 7.4 / 8.0 / 8.1 | — | 공식 소스 백포트 있음 (이 레포 대상 아님) | php-src `PHP-x.y-CVE-2026-109618-109619` 브랜치 |
| 7.3 | 7.3.33 | 포팅·검증 완료 ([보고서](reports/7.3.md)) | 7.4 공식 백포트(712e60f9ed)에서 포팅 |
| 7.2 | 7.2.34 | 포팅·검증 완료 ([보고서](reports/7.2.md)) | 7.3 백포트에서 포팅 |
| 7.1 | 7.1.33 | 포팅·검증 완료 ([보고서](reports/7.1.md)) | 7.2 백포트에서 포팅, 종료 처리는 같은 의도로 새로 작성 |
| 7.0 | 7.0.33 | 포팅·검증 완료 ([보고서](reports/7.0.md)) | 7.1 백포트에서 포팅 |

모든 버전에서 "패치 후에만 실패하는 테스트" 목록이 7.4 공식 백포트와 같습니다(9개, [EXPECTED-CHANGES.md](EXPECTED-CHANGES.md)). 같은 백포트를 따로 옮긴 Sury 패키지의 패치와도 비교했습니다([보고서](reports/sury-crosscheck.md)). 그 결과로 7.3·7.2 패치를 한 곳 고쳤습니다(2026-10-25). 공식 Docker 이미지 구성 + PHP-FPM 실요청 검증 결과는 [reports/docker.md](reports/docker.md)에 있습니다.

### 패키지(RPM)

| 대상 | 상태 | 비고 |
|---|---|---|
| CentOS 7 + Remi php73 | 빌드·검증 완료 ([보고서](reports/el7-remi-php73.md)) | Remi 7.3.33-22 소스 + 이 백포트 → `7.3.33-22.sizlon1.el7`. Remi el7(-14)에서 yum 제자리 업그레이드 확인 |

빌드된 RPM은 [Release `el7-php73-7.3.33-22.sizlon1`](../../releases/tag/el7-php73-7.3.33-22.sizlon1)에 있습니다 (SHA256SUMS 포함, GPG 서명 없음). **이 RPM은 7.3 패치를 고치기 전에 빌드했으므로 `sizlon2`로 다시 빌드해야 합니다.**

## 원칙

- 각 패치는 php-src의 **7.4 공식 EOL 백포트**(Arnaud Le Blanc, Ilija Tovilo)를 기준으로, 의미를 바꾸지 않고 해당 버전 구조에 맞게만 옮깁니다.
- 자동 생성 파일(`Zend/zend_vm_execute.h`)은 손으로 고치지 않고 해당 버전의 `zend_vm_gen.php`로 다시 생성합니다. 최신 PHP로 구버전 생성기를 돌리면 무관한 차이가 생기는 버전(7.1, 7.0)은 원본·패치본 재생성 결과의 차이만 출시본에 적용합니다.
- 공식 EOL 백포트에는 이 버전들에 이식 가능한 회귀 테스트가 없습니다. 그래서 검증은 **해당 버전의 기존 테스트 전체를 패치 전후로 돌려 결과가 같은지 비교**하는 방식으로 합니다 (`scripts/compare-tests.sh`). 공격 코드로 재현하는 방식은 쓰지 않습니다.
- 이 패치는 취약점을 줄이기 위한 것이지, 안전을 보장하지 않습니다. 가능한 한 빨리 지원되는 버전(8.3 이상 권장, 8.2는 2026-12-31 지원 종료)으로 옮기세요.

**적용 전 반드시 [EXPECTED-CHANGES.md](EXPECTED-CHANGES.md)를 읽으세요.** 공식 패치와 마찬가지로 세션 업로드 진행 기능이 꺼지고, 메모리 한도 초과 시 프로세스가 즉시 종료됩니다.

## 사용법

```bash
# 1. 현재 쓰는 것과 같은 버전의 PHP 소스를 준비
tar xf php-7.3.33.tar.gz
# 2. 패치 적용
scripts/apply.sh php-7.3.33
# 3. 기존 configure 옵션 그대로 다시 빌드 후 설치, 모든 PHP 워커 재시작
```

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
reports/<x.y>.md             버전별 검증 결과 (최소 구성)
reports/docker.md            Docker 실환경 검증 결과 (전 버전)
```

## Docker로 검증하기

```bash
docker/verify.sh 7.3          # 한 버전
docker/verify.sh              # 7.3 7.2 7.1 7.0 전부 (2코어 기준 버전당 약 20분)
```

Docker 이미지 안의 Debian은 모두 지원이 끝난 배포판이라 archive.debian.org를 씁니다. stretch(7.0)는 아카이브 서명 키가 만료돼 `trusted=yes`로 받습니다. **테스트 전용 설정이니 운영용 Dockerfile에 옮기지 마세요.**

## 라이선스

패치는 PHP 소스에서 파생되었으므로 PHP License 3.01을 따릅니다.

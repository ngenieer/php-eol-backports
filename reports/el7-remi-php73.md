# CentOS 7 + Remi php73 RPM 검증 (2026-10-25)

## 배경
- Remi 저장소의 CentOS 7(el7)용 php73은 **7.3.33-14 (2024-06)**에서 멈췄습니다. 그 뒤 Remi는 EL8/EL9용으로만 -15부터 -22(2026-08)까지 보안 수정을 계속 냈습니다.
- PHP2Shell(CVE-2026-109618, CVE-2026-109619) 수정은 Remi에도 아직 없습니다 (2026-10-25 기준).
- 그래서 **Remi의 최신 소스 RPM(7.3.33-22)을 CentOS 7에서 빌드하고 우리 백포트를 추가**했습니다. CentOS 7 사용자는 PHP2Shell 수정과 함께 그동안 놓친 Remi 보안 수정(-15~-22, CVE 10여 건)도 받게 됩니다.

## 만든 것
- 패키지: `php-*-7.3.33-22.sizlon1.el7.x86_64.rpm` 34개 (Remi와 같은 서브패키지 구성, ZTS 포함)
- 재현 파일: `rpm/el7/php73/php-cve-2026-109618-109619.patch`, `rpm/el7/php73/php73.spec.diff`
- Remi의 기존 패치 53개 뒤에 `Patch234`로 추가했습니다.

### Remi 트리에 맞춘 부분
Remi가 이미 백포트해 둔 부분은 빼고 적용했습니다.

| 원본 7.3 백포트의 부분 | Remi 7.3.33-22 상태 | 처리 |
|---|---|---|
| `ZSTR_MAX_LEN` 매크로 (zend_string.h) | 이미 있음 | 제외 |
| `max_multipart_body_parts` 설정과 파트 수 제한 (main.c, rfc1867.c) | 이미 있음 (CVE-2023-0662 백포트) | 제외. 그대로 적용하면 제한 코드가 **두 번 삽입**되는 것을 확인하고 막음 |
| multipart 헤더 필터링, `size_t` 수정 (rfc1867.c) | 없음 | 적용 |
| 요청 종료 시 전역 상태 리셋 (main.c 2곳) | 없음 | 적용 |
| 나머지 Zend 엔진·세션·SAPI 변경 | 없음 | 그대로 적용 |

## 검증 A: yum 업그레이드 시나리오
CentOS 7 컨테이너에서 실제 서버처럼 진행했습니다.

1. Remi php73 저장소에서 `php-cli php-common php-fpm php-mysqlnd php-pdo php-gd php-opcache php-mbstring php-xml php-json` 설치 → **7.3.33-14.el7.remi**
2. FPM 스모크 테스트
3. `yum localinstall`로 패치 RPM 설치 → **7.3.33-22.sizlon1.el7**로 제자리 업그레이드 (의존성 문제 없음)
4. 같은 FPM 스모크 테스트

| 항목 | Remi -14 (현재 고객 서버) | 패치 RPM |
|---|---|---|
| opcache, mysqli, pdo_mysql, gd, session | 정상 | 정상 |
| 중첩 GET/POST 배열, multipart 업로드, 세션 유지 | 정상 | **동일** |
| 메모리 초과 요청 응답 | 500 (display_errors Off) | 빈 응답 → nginx에서 502 |
| 메모리 초과 시 종료 함수 | 실행됨 | 실행 안 됨 |
| 메모리 초과 후 워커 | 재사용 | 종료 후 FPM이 새로 띄움 |
| 메모리 초과 직후 정상 요청 4건 | 성공 | 성공 |

## 검증 B: 회귀 테스트
같은 Remi 7.3.33-22 소스를 패치 없이(`22.base0`) / 패치하여(`22.sizlon1`) 빌드한 RPM에서 PHP 테스트를 비교했습니다.

| | 원본 | 패치본 |
|---|---|---|
| 통과 | 6,206 | 6,197 |
| 실패 | 8 | 17 |

**패치 후에만 실패하는 테스트 9개는 php.net 7.4 공식 백포트의 목록과 완전히 같습니다** (업로드 진행 8개 + 메모리 초과 1개, EXPECTED-CHANGES.md). Remi 빌드에는 php-cgi가 있어서 업로드 진행 테스트도 실제로 실행됐습니다.

## 재현 방법
```bash
docker build -f rpm/el7/Dockerfile.builder -t peb-el7-builder .   # rpm/el7/ca/에 필요하면 프록시 CA
# Remi SRPM php-7.3.33-22.remi.src.rpm을 풀어 SOURCES/SPECS에 두고
# php73.spec.diff 적용, 패치 파일을 SOURCES에 복사한 뒤
# (빌드 전) yum install gd3php-devel libicu69-devel oniguruma5php-devel; yum-builddep php73.spec
rpmbuild -bb --define "runselftest 0" php73.spec
rpm/el7/verify.sh <rpm-dir> <php-source-tree> <out-dir>
```

## 수정 필요 (2026-10-25)
배포한 `7.3.33-22.sizlon1`은 핸들러 초기화 위치를 고치기 전의 패치로 빌드했습니다([sury-crosscheck.md](sury-crosscheck.md)). 레포의 `php-cve-2026-109618-109619.patch`는 이미 고쳤으므로, 이 파일로 `22.sizlon2`를 다시 빌드하고 검증 A·B를 다시 돌려야 합니다.

## 한계
- Remi가 만든 패키지가 아닙니다. Remi의 서명이 없고, 저장소로 배포하려면 별도 서명 키가 필요합니다.
- 고객 서버에 PHP 확장을 추가로 설치했다면(pecl 등) 그 확장도 같은 버전으로 다시 맞춰야 할 수 있습니다.
- 취약점 재현으로 확인하지 않았고, php.net이나 Remi가 보증한 패치가 아닙니다.

# CentOS 7 + Remi php73 RPM 검증 (2026-10-26)

## 배경
- Remi 저장소의 CentOS 7(el7)용 php73은 **7.3.33-14 (2024-06)**에서 멈췄습니다. 그 뒤로 Remi는 EL8/EL9용으로만 보안 수정을 냈습니다.
- 2026-10-25에 Remi가 **7.3.33-23**을 냈습니다. PHP2Shell(CVE-2026-109618, CVE-2026-109619) 수정과 SOAP 수정 2건(CVE-2026-91765, CVE-2025-14181)이 들어 있지만, 이번에도 EL8/EL9용만 나왔습니다.
- 그래서 **Remi 7.3.33-23 소스 RPM을 CentOS 7에서 다시 빌드**했습니다. CentOS 7 사용자는 PHP2Shell 수정과 함께 -15부터 -23까지의 Remi 보안 수정을 모두 받게 됩니다.

## 만든 것
- 패키지: `php-*-7.3.33-23.sizlon1.el7.x86_64.rpm` 35개. Remi와 같은 서브패키지 구성이고 debuginfo를 포함합니다.
- 소스: Remi `php-7.3.33-23.remi.src.rpm`. Remi 2026 키(`befa00e2`)로 서명을 확인했습니다. CentOS 7의 rpm은 이 서명 형식을 읽지 못해 Rocky 9에서 확인했습니다.
- 재현 파일: `rpm/el7/php73/php73.spec.diff`, `rpm/el7/php73/php-cve-2026-109618-109619-shutdown.patch`

### Remi 패치에 더한 것
Remi의 `php-from-8.2.35-to-7.3.patch`는 이 레포의 7.3 패치와 거의 같습니다. 줄 단위로 비교했을 때 `zend_execute_API.c`만 다릅니다. Remi 패치에는 `shutdown_executor()`의 빠른 종료 분기에 `objects_store` 초기화만 있고, 다음 두 가지가 빠져 있습니다.
- 객체 저장소를 해제하기 **전에** 사용자 오류·예외 핸들러를 초기화하는 부분
- 해제한 뒤 `EG(error_handling)`, `EG(exception)`을 초기화하는 부분

두 가지 모두 php.net 공식 수정(8.x의 802c210, 7.4의 712e60f9ed)과 Remi 자신의 7.4 패치(7.4.33-31)에는 있습니다. 빠지면 클로저로 등록한 핸들러가 해제된 뒤에도 참조가 남습니다([sury-crosscheck.md](sury-crosscheck.md) 참고). 이 두 부분만 `Patch236`으로 더했습니다. 내용은 `patches/7.3`의 해당 부분과 같습니다. Remi 7.2.34-30에도 같은 부분이 빠져 있어 Remi에 알렸습니다([remicollet/remirepo#364](https://github.com/remicollet/remirepo/issues/364)). Remi가 반영하면 `Patch236`을 빼고 Remi 소스만으로 빌드하면 됩니다.

이전 릴리스 `7.3.33-22.sizlon1`은 Remi -22에 이 레포의 전체 패치를 더해 빌드한 것이었고, 핸들러 초기화 위치를 고치기 전의 패치를 썼습니다. 이 릴리스는 `23.sizlon1`로 대체합니다. -22용 전체 패치 파일은 더 이상 쓰지 않아 지웠습니다. git 기록에는 남아 있습니다.

## 검증 A: yum 업그레이드 시나리오
CentOS 7 컨테이너에서 실제 서버처럼 진행했습니다.

1. Remi php73 저장소에서 `php-cli php-common php-fpm php-mysqlnd php-pdo php-gd php-opcache php-mbstring php-xml php-json`을 설치했습니다. → **7.3.33-14.el7.remi**
2. FPM 스모크 테스트를 돌렸습니다.
3. `yum localinstall`로 새 RPM을 설치했습니다. → **7.3.33-23.sizlon1.el7**로 제자리 업그레이드됐고 의존성 문제는 없었습니다.
4. 같은 FPM 스모크 테스트를 다시 돌렸습니다.

| 항목 | Remi -14 (현재 고객 서버) | 새 RPM |
|---|---|---|
| opcache, mysqli, pdo_mysql, gd, session | 정상 | 정상 |
| 중첩 GET/POST 배열, multipart 업로드, 세션 유지 | 정상 | **동일** |
| 메모리 초과 요청 응답 | 500 (display_errors Off) | 빈 응답 → nginx에서 502 |
| 메모리 초과 시 종료 함수 | 실행됨 | 실행 안 됨 |
| 메모리 초과 후 워커 | 재사용 | 종료 후 FPM이 새로 띄움 |
| 메모리 초과 직후 정상 요청 4건 | 성공 | 성공 |

이전 릴리스 `22.sizlon1`을 설치한 상태에서 `23.sizlon1`로 업그레이드하는 것도 확인했습니다. 업그레이드되지 않은 패키지는 없었습니다. 스모크 결과는 같았고, 차이는 누적되는 FPM 로그 카운트뿐이었습니다.

## 검증 B: 회귀 테스트
같은 Remi 7.3.33-23 소스로 두 가지를 빌드해 PHP 테스트 결과를 비교했습니다.
- `23.base0`: PHP2Shell 패치(Patch235, Patch236)를 뺀 빌드
- `23.sizlon1`: 두 패치를 넣은 빌드

| | 원본 | 패치본 |
|---|---|---|
| 통과 | 6,205 | 6,196 |
| 실패 | 9 | 18 |

**패치 후에만 실패하는 테스트 9개는 php.net 7.4 공식 백포트의 목록과 완전히 같습니다** (업로드 진행 8개 + 메모리 초과 1개, EXPECTED-CHANGES.md). Remi 빌드에는 php-cgi가 있어서 업로드 진행 테스트도 실제로 실행됐습니다.

업로드 진행(`session.upload_progress`) 기능은 코드에서 꺼져 있습니다. 그래서 KISA가 2026-10-24 권고한 CVE-2026-115560의 전제 조건(업로드 진행 기능 활성화)도 성립하지 않습니다.

## 재현 방법
```bash
docker build -f rpm/el7/Dockerfile.builder -t peb-el7-builder .   # rpm/el7/ca/에 필요하면 프록시 CA
# Remi SRPM php-7.3.33-23.remi.src.rpm은 EL8용 rpm 기능(RichDependencies)을 써서 el7에서 rpm -i가 안 됩니다.
# rpm2cpio로 풀어 SOURCES/SPECS에 두고, php73.spec.diff 적용, Patch236 파일을 SOURCES에 복사한 뒤
# (빌드 전) yum install gd3php-devel libicu69-devel oniguruma5php-devel; yum-builddep php73.spec
rpmbuild -bb --define "runselftest 0" php73.spec
rpm/el7/verify.sh <rpm-dir> <php-source-tree> <out-dir>
```

## 한계
- Remi가 만든 패키지가 아닙니다. Remi의 서명이 없고, 저장소로 배포하려면 별도 서명 키가 필요합니다.
- 고객 서버에 PHP 확장을 추가로 설치했다면(pecl 등) 그 확장도 같은 버전으로 다시 맞춰야 할 수 있습니다.
- 취약점을 재현해서 확인하지는 않았습니다. php.net이나 Remi가 보증한 패치가 아닙니다.

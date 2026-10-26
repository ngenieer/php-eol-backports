# Debian 10 / Ubuntu 18.04용 Sury PHP 재빌드 검증 (2026-10-25)

## 배경: Debian 계열은 어디서 수정을 받을 수 있나
2026-10-25 기준으로 저장소와 보안 트래커를 직접 확인한 결과입니다.

| 설치 경로 | PHP2Shell 수정 | 받는 방법 |
|---|---|---|
| Debian 9 기본 php7.0 | `7.0.33-0+deb9u26` (ELA-1855-1) | Freexian ELTS 저장소 (공개 접근 가능) |
| Debian 10 기본 php7.3 | `7.3.31-1~deb10u16` (ELA-1854-1) | Freexian ELTS 저장소 (공개 접근 가능) |
| Ubuntu 16.04 기본 php7.0 | `7.0.33-0ubuntu0.16.04.16+esm22` | Ubuntu Pro (ESM) |
| Ubuntu 18.04 기본 php7.2 | `7.2.24-0ubuntu0.18.04.17+esm14` | Ubuntu Pro (ESM) |
| Sury, Debian 11~13 / Ubuntu 22.04~ | php7.0 -92, 7.1 -80, 7.2 -66, 7.3 -35 | packages.sury.org, `ppa:ondrej/php` |
| **Sury, Debian 9·10 / Ubuntu 16.04~20.04** | **없음** | Sury가 이 배포판들의 빌드를 중단함 (buster 저장소 404, PPA bionic의 마지막 빌드는 2023년 php7.2 -39) |

수정을 받을 길이 없는 곳은 **지원이 끝난 배포판에 Sury로 PHP를 설치한 서버**입니다. 이 경우 Debian이나 Ubuntu의 기본 패키지로 내려가면 버전이 오히려 낮아집니다(7.3.33 → 7.3.31, 7.2.34 → 7.2.24). 그래서 **Sury의 현재 소스를 그대로 해당 배포판에서 다시 빌드**했습니다. Sury 소스에는 PHP2Shell 수정이 이미 들어 있으므로 우리 패치는 넣지 않았습니다. 두 패치를 비교한 결과는 [sury-crosscheck.md](sury-crosscheck.md)에 있습니다.

## 만든 것

| 대상 | 소스 | 패키지 버전 | 개수 |
|---|---|---|---|
| Debian 10 buster | Sury php7.3 `7.3.33-35` | `7.3.33-35+0~20261021.144+debian10~1.gbpecf76f+sizlon1` | 39 (+ dbgsym 36) |
| Ubuntu 18.04 bionic | Sury php7.2 `7.2.34-66` | `7.2.34-66+0~20261021.122+ubuntu18.04~1.gbpe0bcd4+sizlon1` | 39 |

- 재현: `deb/build.sh <buster|bionic> <x.y> <out>`, `deb/verify.sh <buster|bionic> <x.y> <out>`. 소스 버전과 SHA256은 `deb/sources.txt`에 고정했습니다.
- 소스는 고치지 않았고, 변경 기록(changelog)에 항목 하나만 추가했습니다. 검증을 위해 같은 소스에서 PHP2Shell 패치만 뺀 `+base0` 빌드도 만들었습니다.
- 버전이 기존 Sury 빌드(`-39` 등)와 배포판 패키지보다 높으므로 `apt install`로 제자리 업그레이드됩니다.

### php-common 의존성
이 패키지들은 `php-common (>= 1:81~)`을 요구합니다.
- Debian 10 기본 `2:69`: epoch가 2라서 조건을 만족합니다.
- Sury를 쓰던 서버: Sury의 `2:9x`가 이미 설치돼 있어 만족합니다.
- Ubuntu 18.04 기본 `1:60`: 조건을 **만족하지 않습니다**. Sury를 쓰지 않던 bionic 서버라면 Sury의 php-common도 함께 설치해야 하며, 이 경우 오래된 PECL 확장 패키지(php-redis 등)와 Breaks가 걸릴 수 있습니다. 이런 서버는 Ubuntu Pro(ESM)를 쓰는 편이 낫습니다.

## 검증 A: apt 업그레이드 시나리오
배포판 기본 PHP(`php*-cli common fpm mysql gd opcache mbstring xml json`)를 설치하고 FPM 스모크 테스트를 돌렸습니다. 그다음 설치된 모든 php 패키지를 재빌드 패키지로 `apt install` 하고 같은 테스트를 다시 돌렸습니다. bionic은 위 이유로 Sury php-common을 함께 설치했습니다.

| 항목 | buster 7.3.31-1~deb10u7 → 재빌드 | bionic 7.2.24-0ubuntu0.18.04.17 → 재빌드 |
|---|---|---|
| 의존성 문제, 업그레이드 안 된 패키지 | 없음 | 없음 |
| opcache, mysqli, pdo_mysql, gd, session | 정상 | 정상 |
| 중첩 GET/POST 배열, multipart 업로드, 세션 유지 | 동일 | 동일 |
| 메모리 초과 응답 | 500 → 빈 응답 (nginx에서 502) | 500 → 빈 응답 (nginx에서 502) |
| 메모리 초과 시 종료 함수 | 실행됨 → 실행 안 됨 | 실행됨 → 실행 안 됨 |
| 메모리 초과 후 워커 | 재사용 → 종료 후 새로 띄움 | 재사용 → 종료 후 새로 띄움 |
| 메모리 초과 직후 정상 요청 4건 | 성공 | 성공 |

FPM 로그 파일(`/var/log/php7.x-fpm.log`)은 업그레이드 전 기록도 남아 있으므로 `fpm_log_fatal` 값은 누적값입니다.

## 검증 B: 회귀 테스트
같은 Sury 소스를 PHP2Shell 패치 없이(`+base0`) 빌드한 패키지와 패치를 넣어(`+sizlon1`) 빌드한 패키지에서 PHP 테스트를 비교했습니다. php-cgi도 설치했으므로 업로드 진행 테스트까지 실제로 돌았습니다.

| | buster 원본 | buster 패치본 | bionic 원본 | bionic 패치본 |
|---|---|---|---|---|
| 통과 | 6,194 | 6,185 | 5,997 | 5,988 |
| 실패 | 10 | 19 | 10 | 19 |

두 배포판 모두 **패치 후에만 실패하는 테스트 9개가 7.4 공식 백포트의 목록과 완전히 같습니다**(업로드 진행 8개 + 메모리 초과 1개, EXPECTED-CHANGES.md).

## 한계
- Sury가 만든 패키지가 아니며 Sury의 서명이 없습니다. apt 저장소로 배포하려면 별도 서명 키가 필요합니다.
- 실제 고객 서버의 이전 상태(예전 Sury buster/bionic 빌드)는 Sury가 내려서 받을 수 없어, 배포판 기본 패키지에서 업그레이드하는 것으로 대신 확인했습니다.
- 7.3/buster와 7.2/bionic 두 조합만 빌드했습니다. 다른 조합은 `deb/sources.txt`에 소스를, `deb/build.sh`와 `deb/verify.sh`에 배포판을 추가하면 같은 방법으로 빌드할 수 있지만, 검증은 하지 않았습니다.
- 취약점 재현으로 확인하지 않았습니다.

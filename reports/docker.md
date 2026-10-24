# Docker 실환경 검증 (2026-10-25)

`docker/verify.sh`로 공식 `php:<x.y>-fpm` 이미지의 PHP를 **이미지 자체의 configure 옵션 그대로** 원본/패치본 두 번 재빌드하고, 국내 레거시 사이트에서 흔한 확장(mysqli, pdo_mysql, gd, opcache)을 더해 비교했습니다.

| 버전 | 기반 OS | 원본 통과/실패 | 패치본 통과/실패 | 패치 후에만 실패 |
|---|---|---|---|---|
| 7.3.33 | Debian 11 | 6,131 / 5 | 6,130 / 6 | `tests/lang/bug45392.phpt` |
| 7.2.34 | Debian 10 | 5,934 / 5 | 5,933 / 6 | `tests/lang/bug45392.phpt` |
| 7.1.33 | Debian 10 | 5,784 / 0 | 5,783 / 1 | `tests/lang/bug45392.phpt` |
| 7.0.33 | Debian 9 | 5,490 / 0 | 5,489 / 1 | `tests/lang/bug45392.phpt` |

테스트 범위: Zend/tests, tests, main, ext/session, ext/standard(file, strings, array), ext/opcache/tests

- 패치 후에만 실패하는 테스트는 네 버전 모두 메모리 초과 동작 변화(EXPECTED-CHANGES 2번)에 해당하는 1개뿐입니다.
- 업로드 진행 테스트(`ext/session/tests/rfc1867*.phpt`)는 공식 이미지가 php-cgi 없이 빌드되어 건너뛰어졌습니다. 이 동작 변화는 최소 구성 검증(reports/7.x.md)에서 확인했습니다.

## PHP-FPM 스모크 테스트

실제 FPM 워커 풀에 FastCGI로 요청을 보냈습니다(`docker/smoke/run.sh`). 네 버전 모두 같은 결과입니다.

| 항목 | 원본 | 패치본 |
|---|---|---|
| opcache, mysqli, pdo_mysql, gd, session 로드 | 정상 | 정상 |
| 중첩 GET/POST 배열 (`a[b][c]`, `x[]`) | 정상 | **동일** |
| multipart 업로드 2개 파일 + 일반 필드 (추가 헤더 포함) | 정상 | **동일** |
| 세션 유지 (쿠키로 두 번째 요청) | 정상 | **동일** |
| 메모리 초과 요청의 응답 본문 Fatal 메시지 | 있음 | 없음 (빈 응답 → nginx 502) |
| 메모리 초과 시 `register_shutdown_function` 실행 | 실행됨 | 실행 안 됨 |
| 메모리 초과 후 워커 | 그대로 재사용 | 종료 후 FPM이 새로 띄움 |
| FPM 로그에 Fatal·워커 종료 기록 | 없음 | 있음 |
| 메모리 초과 직후 정상 요청 4건 | 모두 성공 | 모두 성공 |

## 참고
- 7.1·7.0의 FPM은 `listen = 9000`을 IPv6로 열려 해서, IPv6가 없는 컨테이너에서는 시작하지 못합니다. 스모크 테스트는 `127.0.0.1:9000`으로 바꿔 실행합니다(패치와 무관한 환경 문제).
- 이 이미지들의 Debian은 모두 지원 종료라 archive.debian.org를 사용하며, Debian 9는 만료된 서명 키 때문에 `trusted=yes`로 받습니다. 테스트 전용 설정입니다.

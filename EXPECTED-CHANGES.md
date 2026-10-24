# 패치로 바뀌는 동작 (의도된 변화)

php.net의 7.4 공식 EOL 백포트(712e60f9ed)가 가져오는 동작 변화이며, 이 레포의 모든 백포트도 똑같이 바뀝니다.
고객 서버에 적용하기 전에 아래 항목이 서비스에 영향이 없는지 확인하세요.

## 1. 세션 업로드 진행 기능이 꺼짐
- `session.upload_progress`가 설정과 관계없이 동작하지 않습니다 (`$_SESSION`에 진행 정보가 생기지 않음).
- 업로드 진행 막대를 이 기능으로 구현한 사이트는 진행률 표시가 멈춥니다. 업로드 자체는 정상 동작합니다.
- 관련 테스트 실패(예상됨): `ext/session/tests/rfc1867*.phpt` 8개

## 2. 메모리 한도 초과 시 프로세스 즉시 종료
- `memory_limit` 초과나 할당 크기 오버플로가 나면 기존처럼 오류 처리 후 요청을 정리하지 않고, stderr에 `Fatal error`를 출력한 뒤 프로세스를 바로 종료합니다(`_exit(1)`).
- 따라서 이 경우 `register_shutdown_function`, 사용자 오류 핸들러, 출력 버퍼 정리가 실행되지 않고, 오류 메시지가 `error_log`가 아닌 stderr(FPM이면 FPM 로그)로 갑니다.
- PHP-FPM은 죽은 워커를 다시 띄우므로 서비스는 계속되지만, 메모리 초과가 잦은 사이트는 워커 재시작이 늘어납니다.
- 관련 테스트 실패(예상됨): `tests/lang/bug45392.phpt` 1개

## 3. multipart 본문 파트 수 제한 추가
- 새 설정 `max_multipart_body_parts`(기본 -1 = `max_input_vars + max_file_uploads`)를 넘는 파트는 무시하고 경고를 남깁니다.
- multipart 헤더 중 `Content-Disposition`, `Content-Type`만 보관하고 중복 헤더는 무시합니다.

## 검증 기준
`scripts/compare-tests.sh` 결과에서 "패치 후에만 실패"하는 테스트가 위 9개와 정확히 같아야 합니다. 그 밖의 항목이 나오면 포팅 오류입니다.

# Behaviour changed by the patch (intended)

These are the behaviour changes introduced by php.net's official 7.4 EOL backport (712e60f9ed). Every backport in this repository changes behaviour in exactly the same way.
Before applying it to a server, check that none of the items below affects the services it runs.

## 1. Session upload progress is disabled
- `session.upload_progress` no longer works, whatever the configuration (no progress information appears in `$_SESSION`).
- Sites that drive an upload progress bar with this feature will see the progress stop updating. The uploads themselves still work.
- Related test failures (expected): 8 tests, `ext/session/tests/rfc1867*.phpt`

## 2. The process exits immediately when the memory limit is exceeded
- When `memory_limit` is exceeded or an allocation size overflows, PHP no longer handles the error and cleans up the request. It prints `Fatal error` to stderr and exits the process at once (`_exit(1)`).
- In that case `register_shutdown_function` callbacks, user error handlers and output buffer cleanup do not run, and the error message goes to stderr (the FPM log under PHP-FPM) rather than `error_log`.
- PHP-FPM restarts the dead worker, so the service keeps running, but sites that hit the memory limit often will see more worker restarts.
- **The response body for that request is empty.** Unpatched PHP returns the fatal error message (when display_errors is on) or an empty 200/500 response. With the patch the worker disappears mid-response, so a front web server such as nginx reports **502 Bad Gateway**. If your monitoring treats 502 as an outage, review the alert thresholds.
- Related test failure (expected): 1 test, `tests/lang/bug45392.phpt`
- In the Docker FPM smoke test (`docker/smoke/run.sh`), this item is the only difference between unpatched and patched builds: shutdown function ran yes→no, worker replaced no→yes, fatal error and worker exit records in the FPM log 0→1, fatal message in the response body 1→0.

## 3. A limit on the number of multipart body parts
- Parts beyond the new setting `max_multipart_body_parts` (default -1 = `max_input_vars + max_file_uploads`) are ignored and a warning is logged.
- Of the multipart headers, only `Content-Disposition` and `Content-Type` are kept, and duplicate headers are ignored.

## Verification criteria
In the output of `scripts/compare-tests.sh`, the tests that fail only after the patch must be exactly the 9 listed above. Anything else indicates a porting error.
`docker/verify.sh` runs the same comparison with a realistic extension set (official image + mysqli, pdo_mysql, gd, opcache) and checks that item 2 is the only difference in the FPM smoke test.

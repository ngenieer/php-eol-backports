#!/usr/bin/env bash
# Run PHP's own test suites inside the image against the installed (rebuilt) PHP,
# and print the sorted list of failing tests.
set -u
cd /usr/src/php
SUITES="Zend/tests tests main ext/session ext/standard/tests/file ext/standard/tests/strings ext/standard/tests/array ext/opcache/tests"
TEST_PHP_EXECUTABLE=/usr/local/bin/php NO_INTERACTION=1 \
  /usr/local/bin/php run-tests.php -p /usr/local/bin/php -q --set-timeout 60 $SUITES > /tmp/runtests.out 2>&1 || true
grep -E '^Tests (passed|failed)' /tmp/runtests.out >&2
sed -n '/^FAILED TEST SUMMARY/,/^=====/p' /tmp/runtests.out | grep -oE '\[[^]]+\.phpt\]' | tr -d '[]' | sort -u

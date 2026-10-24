#!/usr/bin/env bash
# Smoke test against a real PHP-FPM worker pool over FastCGI.
# Checks ordinary behaviour (GET/POST arrays, multipart uploads, sessions, opcache)
# and the expected behaviour changes from EXPECTED-CHANGES.md (memory-limit exit).
# Not an exploit: it never tries to trigger the vulnerabilities.
set -u
W=/smoke/www
FPM_LOG=/tmp/fpm.log

# Works with the official Docker images (/usr/local) and distro packages (/etc, /usr/sbin).
FPM_BIN="$(command -v php-fpm || echo /usr/sbin/php-fpm)"
for d in /usr/local/etc/php-fpm.d /etc/php-fpm.d /etc/opt/remi/*/php-fpm.d; do [ -d "$d" ] && FPM_D="$d" && break; done
# Older FPM (7.0/7.1) binds a bare port to IPv6, which fails in containers without IPv6.
# Worker stderr (where the patched PHP writes its fatal error) is captured into the FPM log.
printf '[www]\nlisten = 127.0.0.1:9000\ncatch_workers_output = yes\n' > "$FPM_D/zzzz-smoke.conf"
mkdir -p /var/log/php-fpm /run/php-fpm 2>/dev/null
"$FPM_BIN" -F >"$FPM_LOG" 2>&1 &
for i in $(seq 1 50); do (echo > /dev/tcp/127.0.0.1/9000) 2>/dev/null && break; sleep 0.2; done

req () { # method script query content-type bodyfile cookie
  local len=0; [ -n "${5:-}" ] && len=$(stat -c %s "$5")
  env -i REQUEST_METHOD="$1" SCRIPT_FILENAME="$W/$2" SCRIPT_NAME="/$2" REQUEST_URI="/$2" \
    QUERY_STRING="${3:-}" CONTENT_TYPE="${4:-}" CONTENT_LENGTH="$len" HTTP_COOKIE="${6:-}" \
    GATEWAY_INTERFACE=CGI/1.1 SERVER_PROTOCOL=HTTP/1.1 SERVER_NAME=localhost SERVER_PORT=80 REMOTE_ADDR=127.0.0.1 \
    cgi-fcgi -bind -connect 127.0.0.1:9000 < "${5:-/dev/null}" 2>/dev/null | tr -d '\r'
}
body () { sed '1,/^$/d'; }
status () { grep -m1 '^Status:' | cut -d' ' -f2; }
workers () { for p in /proc/[0-9]*; do tr '\0' ' ' < "$p/cmdline" 2>/dev/null | grep -q '^php-fpm: pool' && basename "$p"; done | sort -n | tr '\n' ' '; }

echo "## info"
req GET info.php | body | grep -v '^pid='

echo "## get/post arrays"
printf 'a[b][c]=1&a[b][d]=2&x[]=p&x[]=q&plain=v' > /tmp/form
req POST post.php 'g[k][]=1&g[k][]=2&h=3' application/x-www-form-urlencoded /tmp/form | body

echo "## multipart upload"
B=XyZboundary
printf -- '--%s\r\nContent-Disposition: form-data; name="title"\r\n\r\nhello\r\n--%s\r\nContent-Disposition: form-data; name="f1"; filename="a.txt"\r\nContent-Type: text/plain\r\n\r\nfile-one\r\n--%s\r\nContent-Disposition: form-data; name="f2"; filename="b.txt"\r\nContent-Type: text/plain\r\nX-Extra-Header: ignored\r\n\r\nfile-two\r\n--%s--\r\n' $B $B $B $B > /tmp/mp
req POST upload.php '' "multipart/form-data; boundary=$B" /tmp/mp | body

echo "## session"
sid=$(req GET session.php | body | sed -n 's/^sid=//p')
req GET session.php '' '' '' "PHPSESSID=$sid" | body | grep '^n='

echo "## memory limit exceeded"
before=$(workers)
req GET oom.php > /tmp/oom.out
echo "status=$(status < /tmp/oom.out || true)"
echo "body_has_after=$(body < /tmp/oom.out | grep -c '^after')"
echo "body_has_fatal=$(body < /tmp/oom.out | grep -c 'Allowed memory size')"
echo "shutdown_function_ran=$([ -f /tmp/shutdown_ran ] && echo yes || echo no)"
sleep 1
after=$(workers)
echo "worker_replaced=$([ "$before" = "$after" ] && echo no || echo yes)"
LOGS="$FPM_LOG $(ls /var/log/php-fpm/*.log 2>/dev/null)"
echo "fpm_log_fatal=$(cat $LOGS 2>/dev/null | grep -c 'Allowed memory size')"
echo "fpm_log_worker_exit=$(cat $LOGS 2>/dev/null | grep -cE 'exited with code|exited on signal')"

echo "## still serving after oom"
for i in 1 2 3 4; do req GET info.php | body | grep -c '^version=' ; done | sort | uniq -c | sed 's/^ */ok_requests=/'

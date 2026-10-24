# Rebuild the official php:<ver>-fpm image's PHP from its own bundled source, with the
# same configure flags, optionally applying this repo's backport, then add the extensions
# most legacy sites use. Build twice (PATCH=0 / PATCH=1) to compare like with like.
#
#   docker build -f docker/Dockerfile --build-arg PHPVER=7.3 --build-arg PATCH=1 -t peb:7.3-fix .
ARG PHPVER=7.3
FROM php:${PHPVER}-fpm
ARG PHPVER
ARG PATCH=0

# These images' Debian releases (stretch/buster/bullseye) are EOL and live on archive.debian.org.
# The stretch archive keys have expired, so the archive is marked trusted. This is a throwaway
# test image; do not copy this into a production Dockerfile.
RUN set -eux; \
    . /etc/os-release; \
    C="${VERSION_CODENAME:-$(echo "$VERSION" | sed 's/.*(\(.*\)).*/\1/')}"; \
    S="$C/updates"; [ "$C" = bullseye ] && S="bullseye-security"; \
    rm -f /etc/apt/sources.list.d/*; \
    printf 'deb [trusted=yes] http://archive.debian.org/debian %s main\ndeb [trusted=yes] http://archive.debian.org/debian-security %s main\n' "$C" "$S" > /etc/apt/sources.list; \
    apt-get -o Acquire::Check-Valid-Until=false update; \
    pkgs=""; \
    for p in patch libfcgi-bin libargon2-dev libargon2-0-dev libcurl4-openssl-dev libedit-dev libreadline-dev \
             libsodium-dev libsqlite3-dev libssl-dev libxml2-dev zlib1g-dev libpng-dev libjpeg-dev libfreetype6-dev; do \
      if apt-cache show "$p" >/dev/null 2>&1; then pkgs="$pkgs $p"; fi; \
    done; \
    apt-get install -y --no-install-recommends $PHPIZE_DEPS $pkgs; \
    rm -rf /var/lib/apt/lists/*

COPY patches/ /patches/

RUN set -eux; \
    docker-php-source extract; \
    rm -f /usr/src/php/.docker-delete-me; \
    cd /usr/src/php; \
    if [ "$PATCH" = "1" ]; then for p in /patches/${PHPVER}/*.patch; do patch -p1 < "$p"; done; fi; \
    conf="$(php -i | sed -n "s/^Configure Command =>  //p")"; \
    eval "$conf"; \
    make -j"$(nproc)"; \
    make install; \
    make clean >/dev/null; \
    docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ --with-png-dir=/usr/include/ >/dev/null; \
    docker-php-ext-install -j"$(nproc)" mysqli pdo_mysql gd opcache >/dev/null; \
    rm -f /usr/src/php/.docker-delete-me; \
    php -v; php -m | tr '\n' ' '

COPY docker/smoke/ /smoke/
COPY docker/tests.sh /tests.sh

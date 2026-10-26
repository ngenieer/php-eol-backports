# Build and test environments for rebuilding Sury's php7.x Debian sources on EOL distros.
#   docker build -f deb/Dockerfile --build-arg BASE=debian:buster --target builder -t peb-deb-builder:buster .
#   docker build -f deb/Dockerfile --build-arg BASE=debian:buster --target runtime -t peb-deb-runtime:buster .
# Debian 10 lives on archive.debian.org; Ubuntu 18.04 is still on archive.ubuntu.com.
ARG BASE=debian:buster
FROM ${BASE} AS base
ENV DEBIAN_FRONTEND=noninteractive
COPY deb/ca/ /usr/local/share/ca-certificates/
RUN set -eux; \
    . /etc/os-release; \
    if [ "$ID" = debian ]; then \
      printf 'deb http://archive.debian.org/debian %s main\ndeb http://archive.debian.org/debian-security %s/updates main\n' "$VERSION_CODENAME" "$VERSION_CODENAME" > /etc/apt/sources.list; \
      rm -f /etc/apt/sources.list.d/*; \
    fi; \
    apt-get -o Acquire::Check-Valid-Until=false update; \
    apt-get install -y --no-install-recommends ca-certificates; \
    update-ca-certificates; \
    rm -rf /var/lib/apt/lists/*

FROM base AS builder
RUN set -eux; \
    apt-get -o Acquire::Check-Valid-Until=false update; \
    apt-get install -y --no-install-recommends build-essential devscripts equivs fakeroot xz-utils

FROM base AS runtime
RUN set -eux; \
    apt-get -o Acquire::Check-Valid-Until=false update; \
    apt-get install -y --no-install-recommends libfcgi-bin procps
COPY docker/smoke/ /smoke/

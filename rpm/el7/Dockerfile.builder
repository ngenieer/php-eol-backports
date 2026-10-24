# CentOS 7 RPM build environment for Remi's php SRPMs.
# CentOS 7 and EPEL 7 are EOL: packages come from vault.centos.org and the EPEL archive.
FROM centos:7
ARG EXTRA_CA=
COPY rpm/el7/ca/ /etc/pki/ca-trust/source/anchors/
RUN set -eux; \
    update-ca-trust; \
    rm -f /etc/yum.repos.d/*.repo; \
    for r in os updates extras; do \
      printf '[%s]\nname=CentOS 7 %s\nbaseurl=http://vault.centos.org/7.9.2009/%s/x86_64/\ngpgcheck=0\n' "$r" "$r" "$r" >> /etc/yum.repos.d/vault.repo; \
    done; \
    printf '[epel]\nname=EPEL 7 archive\nbaseurl=https://archive.fedoraproject.org/pub/archive/epel/7/x86_64/\ngpgcheck=0\n' > /etc/yum.repos.d/epel.repo; \
    printf '[remi]\nname=Remi\nbaseurl=http://rpms.remirepo.net/enterprise/7/remi/x86_64/\ngpgcheck=0\n' > /etc/yum.repos.d/remi.repo; \
    printf '[remi-safe]\nname=Remi safe\nbaseurl=http://rpms.remirepo.net/enterprise/7/safe/x86_64/\ngpgcheck=0\n' > /etc/yum.repos.d/remi-safe.repo; \
    yum -y install rpm-build yum-utils make gcc gcc-c++ patch which; \
    yum clean all

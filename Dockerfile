ARG SEAFILE_VERSION=8.0.3
ARG SYSTEM=buster
ARG ARCH=arm64v8

FROM debian:${SYSTEM} AS builder

ARG SEAFILE_VERSION
ARG SYSTEM
ARG ARCH

RUN apt-get update -y && apt-get install -y \
    wget \
    sudo

# Get seafile
WORKDIR /seafile

RUN wget -c https://github.com/haiwen/seafile-rpi/releases/download/v${SEAFILE_VERSION}/seafile-server-${SEAFILE_VERSION}-${SYSTEM}-${ARCH}.tar.gz -O seafile-server.tar.gz && \
    tar -zxvf seafile-server.tar.gz && \
    rm -f seafile-server.tar.gz

# For using TLS connection to LDAP/AD server with docker-ce.
RUN find /seafile/ \( -name "liblber-*" -o -name "libldap-*" -o -name "libldap_r*" -o -name "libsasl2.so*" \) -delete

# Prepare media folder to be exposed
RUN mv seafile-server-${SEAFILE_VERSION}/seahub/media . && echo "${SEAFILE_VERSION}" > ./media/version

FROM debian:${SYSTEM} AS seafile

ARG SEAFILE_VERSION

ENV LC_ALL=C
# Set default timezone.
ENV TZ=America/Los_Angeles
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install --no-install-recommends --yes \
    # For suport set local time zone.
    tzdata \
    sudo \
    procps \
    # For video thumbnail
    ffmpeg \
    libmariadbclient-dev \
    # libmemcached11 \
    # For compiling python memcached module.
    zlib1g-dev libmemcached-dev \
    python3 \
    python3-setuptools \
    python3-ldap \
    python3-sqlalchemy \
    python3-pip \
    # Mysql init script requirement only. Will probably be useless in the future
    python3-pymysql && \
    rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install --upgrade pip && \
    # For compiling memcache pip module
    pip3 install --timeout=3600 --upgrade \
    # Memcached
    pylibmc django-pylibmc
    # moviepy \
    # future mysqlclient jinja2 \

WORKDIR /opt/seafile

RUN useradd -ms /bin/bash -G sudo seafile && \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
    chown -R seafile:seafile /opt/seafile

COPY docker_entrypoint.sh /
COPY --chown=seafile:seafile scripts /home/seafile

# Add version in container context
ENV SEAFILE_VERSION=${SEAFILE_VERSION}

COPY --from=builder --chown=seafile:seafile /seafile /opt/seafile
# Fix import not found when running seafile
RUN ln -s /usr/bin/python3 /opt/seafile/seafile-server-${SEAFILE_VERSION}/seafile/lib/python3.6

CMD ["/docker_entrypoint.sh"]

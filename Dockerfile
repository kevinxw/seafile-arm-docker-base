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

# Python3
RUN apt-get install -y python3 python3-pip python3-setuptools
RUN python3 -m pip install --upgrade pip

# For building memcache library.
RUN apt-get install -y libmemcached-dev zlib1g-dev
# Install dependencies missing from stock seafile package.
RUN pip3 install --timeout=3600 --target seafile-server-${SEAFILE_VERSION}/seahub/thirdpart --upgrade \
    # Restrict django version, in case pip upgrade it accidentally.
    django==2.2.* \
    # Dependency for memcache
    pylibmc django-pylibmc \
    psd-tools \
    captcha django-simple-captcha

# Fix import not found when running seafile
RUN ln -s python3 seafile-server-${SEAFILE_VERSION}/seafile/lib/python3.6

# Prepare media folder to be exposed
RUN mv seafile-server-${SEAFILE_VERSION}/seahub/media . && echo "${SEAFILE_VERSION}" > ./media/version

FROM debian:${SYSTEM}

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
    # ffmpeg \
    libmariadbclient-dev \
    python3 \
    python3-setuptools \
    python3-ldap && \
#    python3-pip && \
#    python3 -m pip install --upgrade pip && \
#    pip3 install --timeout=3600 --upgrade \
#    pymysql \
#    django==2.2.* \
#    # pillow moviepy \
#    future mysqlclient jinja2 \
#    sqlalchemy && \
#    apt-get remove -y python3-pip && \
#    rm -rf /root/.cache/pip && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /opt/seafile

RUN useradd -ms /bin/bash -G sudo seafile && \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
    chown -R seafile:seafile /opt/seafile

COPY --from=builder --chown=seafile:seafile /seafile /opt/seafile

COPY docker_entrypoint.sh /
COPY --chown=seafile:seafile scripts /home/seafile

# Add version in container context
ENV SEAFILE_VERSION=${SEAFILE_VERSION}

CMD ["/docker_entrypoint.sh"]

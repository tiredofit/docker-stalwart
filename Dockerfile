ARG DISTRO="debian"
ARG DISTRO_VARIANT="bookworm"

FROM docker.io/tiredofit/${DISTRO}:${DISTRO_VARIANT}
LABEL maintainer="Dave Conroy (github.com/tiredofit)"

ARG STALWART_VERSION
ARG STALWART_REPO_URL

ENV STALWART_VERSION=${STALWART_VERSION:-"v0.7.1"} \
    STALWART_REPO_URL=${STALWART_REPO_URL:-"https://github.com/stalwartlabs/mail-server"} \
    CONTAINER_ENABLE_MESSAGING=FALSE \
    IMAGE_NAME="tiredofit/stalwart" \
    IMAGE_REPO_URL="https://github.com/tiredofit/docker-stalwart/"

RUN source /assets/functions/00-container && \
    set -x && \
    addgroup --gid 2525 stalwart && \
    adduser --uid 2525 \
            --gid 2525 \
            --gecos "Stalwart Mail" \
            --home /dev/null \
            --no-create-home \
            --shell /sbin/nologin \
            --disabled-login \
            --disabled-password \
            stalwart && \
    \
    curl -sSLk https://mariadb.org/mariadb_release_signing_key.asc | apt-key add - && \
    mariadb_client_ver="$(curl -sSLk https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | grep "mariadb_server_version=mariadb-" | head -n 1 | cut -d = -f 2 | cut -d - -f 2)" && \
    echo "deb https://mirror.its.dal.ca/mariadb/repo/${mariadb_client_ver}/debian $(cat /etc/os-release |grep "VERSION=" | awk 'NR>1{print $1}' RS='(' FS=')') main" > /etc/apt/sources.list.d/mariadb.list && \
    curl -ssL https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
    echo "deb http://apt.postgresql.org/pub/repos/apt/ $(cat /etc/os-release |grep "VERSION=" | awk 'NR>1{print $1}' RS='(' FS=')')-pgdg main" > /etc/apt/sources.list.d/postgres.list && \
    package update && \
    package upgrade && \
    \
    STALWART_BUILD_DEPS=" \
                            build-essential \
                            clang \
                            cmake \
                            protobuf-compiler \
                            " && \
    \
    STALWART_RUN_DEPS=" \
                            inotify-tools \
                            mariadb-client\
                            postgresql-client \
                            sqlite3 \
                            " && \
    package install \
                    ${STALWART_BUILD_DEPS} \
                    ${STALWART_RUN_DEPS} \
                    && \
    mkdir -p /usr/src && \
    curl https://sh.rustup.rs -sSf | env CARGO_HOME=/opt/rust/cargo sh -s -- -y --default-toolchain stable --profile minimal --no-modify-path && \
    \
    clone_git_repo "${STALWART_REPO_URL}" "${STALWART_VERSION}" /usr/src/stalwart && \
    CARGO_HOME=/opt/rust/cargo /opt/rust/cargo/bin/cargo build -p mail-server -p stalwart-cli --no-default-features --features "elastic s3 redis" --release && \
    strip /usr/src/stalwart/target/release/stalwart-cli && \
    cp -R /usr/src/stalwart/target/release/stalwart-cli /usr/sbin && \
    strip /usr/src/stalwart/target/release/stalwart-mail && \
    cp -R /usr/src/stalwart/target/release/stalwart-mail /usr/sbin && \
    mkdir -p /assets/stalwart/config && \
    cp -R resources/config/* /assets/stalwart/config/ && \
    for filename in $(find /assets/stalwart/config/* -type f) ; do if [[ ! ${filename##*.} =~ gz*|tar|zip|zst* ]] ; then sed -i "1 i\# Originally copied for ${IMAGE_NAME}. Stalwart version: ${STALWART_VERSION} on $(date +'%Y-%m-%d %H:%M:%S')" $filename ; fi ; done && \
    chown -R stalwart:stalwart /assets/stalwart && \
    \
    CARGO_HOME=/opt/rust/cargo /opt/rust/cargo/bin/rustup self uninstall -y && \
    \
    package remove \
                    "${STALWART_BUILD_DEPS}"\
                    && \
    package cleanup && \
    rm -rf \
            /opt/rust \
            /usr/src/*

COPY install /

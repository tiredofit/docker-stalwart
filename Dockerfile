ARG DISTRO="debian"
ARG DISTRO_VARIANT="bookworm"

FROM docker.io/tiredofit/${DISTRO}:${DISTRO_VARIANT}
LABEL maintainer="Dave Conroy (github.com/tiredofit)"

ARG STALWART_VERSION
ARG STALWART_REPO_URL

ENV STALWART_VERSION=${STALWART_VERSION:-"v0.4.2"} \
    STALWART_REPO_URL=${STALWART_REPO_URL:-"https://github.com/stalwartlabs/mail-server"} \
    #FOUNDATIONDB_CLIENT_VERSION=${FOUNDATIONDB_CLIENT_VERSION:-"7.1.43-1"} \
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
    package update && \
    package upgrade && \
    \
    STALWART_BUILD_DEPS=" \
                            build-essential \
                            cmake \
                            clang \
                            protobuf-compiler" \
                            && \
    \
    package install ${STALWART_BUILD_DEPS} && \
    mkdir -p /usr/src && \
    #curl -sSL https://github.com/apple/foundationdb/releases/download/${FOUNDATIONDB_CLIENT_VERSION/-*/}/foundationdb-clients_${FOUNDATIONDB_CLIENT_VERSION}_amd64.deb -o /usr/src/foundationdb-clients.deb && \
    #dpkg -i /usr/src/foundationdb-clients.deb && \
    curl https://sh.rustup.rs -sSf | env CARGO_HOME=/opt/rust/cargo sh -s -- -y --default-toolchain stable --profile minimal --no-modify-path && \
    \
    clone_git_repo "${STALWART_REPO_URL}" "${STALWART_VERSION}" /usr/src/stalwart && \
    #CARGO_HOME=/opt/rust/cargo /opt/rust/cargo/bin/cargo build --manifest-path=crates/main/Cargo.toml --no-default-features --features foundationdb --release && \
    CARGO_HOME=/opt/rust/cargo /opt/rust/cargo/bin/cargo build --manifest-path=crates/cli/Cargo.toml --release && \
    strip /usr/src/stalwart/target/release/stalwart-cli && \
    cp -R /usr/src/stalwart/target/release/stalwart-cli /usr/sbin && \
    CARGO_HOME=/opt/rust/cargo /opt/rust/cargo/bin/cargo build --manifest-path=crates/install/Cargo.toml --release && \
    strip /usr/src/stalwart/target/release/stalwart-install && \
    cp -R /usr/src/stalwart/target/release/stalwart-install /usr/sbin && \
    CARGO_HOME=/opt/rust/cargo /opt/rust/cargo/bin/cargo build --manifest-path=crates/main/Cargo.toml --release && \
    strip /usr/src/stalwart/target/release/stalwart-mail && \
    cp -R /usr/src/stalwart/target/release/stalwart-mail /usr/sbin && \
    mkdir -p /assets/stalwart/config && \
    cp -R resources/config/* /assets/stalwart/config/ && \
    for filename in $(find /assets/stalwart/config/* -type f) ; do sed -i "1 i\# Originally copied for ${IMAGE_NAME}. Stalwart version: ${STALWART_VERSION} on $(date +'%Y-%m-%d %H:%M:%S')" $filename ; done && \
    mkdir -p /assets/stalwart/htx && \
    cp -R resources/htx /assets/stalwart/htx/ &&\
    chown -R stalwart:stalwart /assets/stalwart && \
    \
    CARGO_HOME=/opt/rust/cargo /opt/rust/cargo/bin/rustup self uninstall -y && \
    \
    package remove \
                    "${STALWART_BUILD_DEPS}"\
                    #foundationdb-clients \
                    && \
    package cleanup && \
    rm -rf \
            /opt/rust

COPY install /

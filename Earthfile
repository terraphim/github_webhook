VERSION 0.8
PROJECT applied-knowledge-systems/terraphim-project
IMPORT github.com/earthly/lib/rust AS rust
FROM ubuntu:20.04

ARG --global TARGETOS
ARG --global TARGET
ARG --global TARGETPLATFORM
ARG --global tag=$TARGETOS-$TARGETARCH
ARG --global TARGETARCH
IF [ "$TARGETARCH" = amd64 ]
    ARG --global ARCH=x86_64
ELSE
    ARG --global ARCH=$TARGETARCH
END

WORKDIR /code

build-native:
  BUILD +build

build-linux-amd64:
  BUILD +build --platform=linux/amd64 --TARGET=x86_64-unknown-linux-gnu

build-all:
#   BUILD +build # x86_64-unknown-linux-gnu
  BUILD +cross-build --TARGET=x86_64-unknown-linux-gnu
  BUILD +cross-build --TARGET=x86_64-unknown-linux-musl
  BUILD +cross-build --TARGET=armv7-unknown-linux-musleabihf
  BUILD +cross-build --TARGET=aarch64-unknown-linux-musl

# this install uses rust lib and Earthly cache
install:
  FROM ubuntu:20.04
  RUN apt-get update -qq
  RUN apt install -y musl-tools musl-dev 
  RUN DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true TZ=Etc/UTC apt-get install -yqq --no-install-recommends build-essential bison flex ca-certificates openssl libssl-dev bc wget git curl cmake pkg-config
  RUN update-ca-certificates
  RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  DO rust+INIT --keep_fingerprints=true
  RUN rustup component add clippy
  RUN rustup component add rustfmt
  RUN cargo install cross --locked

docker-all:
  BUILD --platform=linux/amd64 +docker-musl --TARGET=x86_64-unknown-linux-musl
  BUILD --platform=linux/arm/v7 +docker-musl --TARGET=armv7-unknown-linux-musleabihf
  BUILD --platform=linux/arm64/v8 +docker-musl --TARGET=aarch64-unknown-linux-musl

source:
  FROM +install
  WORKDIR /code
  COPY --keep-ts . .
  DO rust+CARGO --args=fetch

build:
  FROM +source
  WORKDIR /code
  DO rust+SET_CACHE_MOUNTS_ENV
  DO rust+CARGO --args="build --offline --release" --output="release/[^/\.]+"
  RUN /code/target/release/github_webhook --version
  SAVE ARTIFACT /code/target/release/github_webhook AS LOCAL artifact/bin/github_webhook-$TARGET

# below is not checked, but used to work
cross-build:
  FROM +source
  ARG --required TARGET
  DO rust+SET_CACHE_MOUNTS_ENV
  WORKDIR /code
  COPY --keep-ts . .
  WITH DOCKER
    RUN --mount=$EARTHLY_RUST_CARGO_HOME_CACHE --mount=$EARTHLY_RUST_TARGET_CACHE  cross build --target $TARGET --release
  END
  DO rust+COPY_OUTPUT --output=".*" # Copies all files to ./target
   RUN ./target/$TARGET/release/github_webhook --version
  SAVE ARTIFACT ./target/$TARGET/release/github_webhook AS LOCAL artifact/bin/github_webhook-$TARGET


docker-aarch64:
  FROM rust:latest
  RUN apt update && apt upgrade -y
  RUN apt install -y libssl-dev g++-aarch64-linux-gnu libc6-dev-arm64-cross
  RUN DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true TZ=Etc/UTC apt-get install -yqq --no-install-recommends build-essential bison flex ca-certificates openssl libssl-dev bc wget git curl cmake pkg-config
  RUN apt install -y 
  RUN rustup target add aarch64-unknown-linux-gnu
  RUN rustup toolchain install stable-aarch64-unknown-linux-gnu

  WORKDIR /code
  COPY --keep-ts Cargo.toml Cargo.lock ./
  COPY --keep-ts --dir terraphim_server desktop default crates ./

  ENV CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=aarch64-linux-gnu-gcc \
      CC_aarch64_unknown_linux_gnu=aarch64-linux-gnu-gcc \
      CXX_aarch64_unknown_linux_gnu=aarch64-linux-gnu-g++ 
  ENV PKG_CONFIG_PATH=/usr/lib/aarch64-linux-gnu/pkgconfig
  RUN cargo build --release --target aarch64-unknown-linux-gnu
  SAVE ARTIFACT ./target/aarch64-unknown-linux-gnu/release/github_webhook AS LOCAL artifact/bin/github_webhook-aarch64-unknown-linux-gnu
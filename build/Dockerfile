# syntax=docker/dockerfile:1

FROM --platform=$BUILDPLATFORM rust:1.77.1-slim AS build
WORKDIR /src
COPY Cargo.toml .
COPY src ./src 
RUN <<EOT bash
    set -ex
    apt-get update
    apt-get install -y git clang wget
    rustup target add wasm32-wasi
    cargo build --target wasm32-wasi --release
EOT

FROM scratch
ENTRYPOINT [ "/server.wasm" ]
COPY --link --from=build /src/target/wasm32-wasi/release/server.wasm /server.wasm
# syntax=docker/dockerfile:1

FROM --platform=$BUILDPLATFORM rust:1.77-slim AS build
WORKDIR /src
RUN <<EOT bash
    set -ex
    apt update && apt install -y wget
    rustup target add wasm32-wasi
    mkdir src
    cd src
    wget https://raw.githubusercontent.com/second-state/microservice-rust-mysql/main/src/main.rs
    cd ..
    wget https://raw.githubusercontent.com/second-state/microservice-rust-mysql/main/Cargo.toml
    cargo build --target wasm32-wasi --release
    cp target/wasm32-wasi/release/order_demo_service.wasm order_demo_service.wasm
    chmod a+x order_demo_service.wasm
EOT

FROM scratch
ENTRYPOINT [ "/order_demo_service.wasm" ]
COPY --link --from=build /src/order_demo_service.wasm /order_demo_service.wasm
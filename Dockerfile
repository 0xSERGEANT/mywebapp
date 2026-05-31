FROM rust:1.88-slim-bookworm AS chef
WORKDIR /usr/src/app
RUN cargo install cargo-chef --locked

FROM chef AS planner
COPY . .

RUN cargo chef prepare --recipe-path recipe.json

FROM chef AS builder
# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get install -y --no-install-recommends pkg-config libssl-dev && \
    rm -rf /var/lib/apt/lists/*

COPY --from=planner /usr/src/app/recipe.json recipe.json
RUN cargo chef cook --release --recipe-path recipe.json

COPY . .
RUN cargo build --release

FROM debian:bookworm-slim
WORKDIR /opt/mywebapp

# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get install -y --no-install-recommends postgresql-client curl && \
    rm -rf /var/lib/apt/lists/* && \
    groupadd --system --gid 1001 app && \
    useradd --system --uid 1001 --gid app \
            --home-dir /opt/mywebapp --shell /usr/sbin/nologin app

COPY --from=builder --chown=app:app /usr/src/app/target/release/mywebapp .
COPY --chown=app:app scripts/ ./scripts/
COPY --chown=app:app migrations/ ./migrations/
RUN chmod +x ./scripts/*.sh

USER app
ENV MYWEBAPP_CONFIG=/opt/mywebapp/config.yml
EXPOSE 5200
ENTRYPOINT ["./scripts/entrypoint.sh"]
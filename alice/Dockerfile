# syntax=docker/dockerfile:1

ARG DEBIAN_VERSION=trixie

## Base
FROM debian:${DEBIAN_VERSION}-slim AS python-base

ENV PYTHONUNBUFFERED=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_FROZEN=1 \
    UV_PROJECT_ENVIRONMENT="/opt/uv/venv" \
    UV_PYTHON_INSTALL_DIR="/opt/uv/python" \
    UV_CACHE_DIR="/opt/uv/cache"

ENV PATH="${UV_PROJECT_ENVIRONMENT}/bin:${PATH}"

WORKDIR /app

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/
COPY .python-version .

RUN --mount=type=cache,target=${UV_CACHE_DIR} \
    uv python install


## Assemble alice.py from upstream source
FROM python-base AS alice-build

ARG ALICE_REF=7e10a292d9eac421176d33822aa14f9eb5a56550

ADD https://github.com/simoncirstoiu/alice.git#${ALICE_REF} /src

RUN mkdir /out \
    && uv run --no-project python /src/builder.py --no-venv -o /out/alice.py


## Base image
FROM python-base AS app-base

RUN --mount=type=cache,target=/var/cache/apt,sharing=private \
    apt-get update && apt-get install --no-install-recommends -y \
    ca-certificates \
    libglib2.0-0 \
    wget \
    && rm -rf /var/lib/apt/lists/*

ENV YOLO_AUTOINSTALL=false \
    YOLO_CONFIG_DIR="/app/models/.ultralytics" \
    MPLCONFIGDIR="/tmp/matplotlib"

COPY pyproject.toml uv.lock ./

RUN --mount=type=cache,target=${UV_CACHE_DIR} \
    uv sync --no-install-project

COPY . .
RUN ln -s /app/rootfs/* /

COPY --from=alice-build /out/alice.py /app/alice.py

VOLUME ["/app/config", "/app/datasets", "/app/models"]
EXPOSE 8080

ENTRYPOINT ["/docker-entrypoint.sh"]


## Production image
FROM app-base AS production

RUN --mount=type=cache,target=/var/cache/apt,sharing=private \
    apt-get update && apt-get install --no-install-recommends -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

HEALTHCHECK --start-interval=1s --start-period=30s --interval=30s --timeout=5s CMD ["/docker-healthcheck.sh"]

# syntax=docker/dockerfile:1

# TODO: use tini
# TODO: use non root user

# The builder image, used to build the virtual environment
FROM --platform=$BUILDPLATFORM python:3.12-bookworm as builder

ENV DEBIAN_FRONTEND=noninteractive \
  # python:
  PYTHONFAULTHANDLER=1 \
  PYTHONUNBUFFERED=1 \
  PYTHONHASHSEED=random \
  PYTHONDONTWRITEBYTECODE=1 \
  # pip:
  PIP_NO_CACHE_DIR=1 \
  PIP_DISABLE_PIP_VERSION_CHECK=1 \
  PIP_DEFAULT_TIMEOUT=100 \
  PIP_ROOT_USER_ACTION=ignore \
  # poetry:
  POETRY_VERSION=1.8.3 \
  POETRY_NO_INTERACTION=1 \
  POETRY_VIRTUALENVS_IN_PROJECT=1 \
  POETRY_VIRTUALENVS_CREATE=1 \
  POETRY_CACHE_DIR='/var/cache/pypoetry' \
  POETRY_HOME='/usr/local'

SHELL ["/bin/bash", "-eo", "pipefail", "-c"]

RUN pip install poetry==${POETRY_VERSION}

WORKDIR /app

COPY pyproject.toml poetry.lock README.md ./

RUN poetry install --without dev --no-root && rm -rf $POETRY_CACHE_DIR

# The runtime image, used to just run the code provided its virtual environment
FROM --platform=$BUILDPLATFORM python:3.12-slim-bookworm as runtime

# Needed for fixing permissions of files created by Docker:
ARG UID=1000
ARG GID=1000

ENV DEBIAN_FRONTEND=noninteractive \
    # python:
    PYTHONFAULTHANDLER=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONHASHSEED=random \
    PYTHONDONTWRITEBYTECODE=1 \
    # tini:
    TINI_VERSION=v0.19.0 \
    # pip:
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_DEFAULT_TIMEOUT=100 \
    PIP_ROOT_USER_ACTION=ignore \
    # prometheus exporter:
    PROMETHEUS_DISABLE_CREATED_SERIES=true

SHELL ["/bin/bash", "-eo", "pipefail", "-c"]

RUN apt-get update; \
    apt-get install -y --no-install-recommends curl libyaml-dev; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    apt-get clean -y; \
    rm -rf /var/lib/apt/lists/*;

# Installing `tini` utility - https://github.com/krallin/tini
# Get architecture to download appropriate tini release:
RUN  dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
     curl -o /usr/local/bin/tini -sSLO "https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-${dpkgArch}"; \
     chmod +x /usr/local/bin/tini && tini --version;

ENV VIRTUAL_ENV=/app/.venv \
    PATH="/app/.venv/bin:$PATH"

WORKDIR /app

RUN groupadd -g "${GID}" -r exporter; \
  useradd --home-dir /app --gid exporter --no-log-init  --system --uid "${UID}" exporter; \
  chown exporter:exporter -R /app;

COPY --from=builder --chown=exporter:exporter ${VIRTUAL_ENV} ${VIRTUAL_ENV}

COPY --chown=exporter:exporter rds_metadata_exporter /app/rds_metadata_exporter

USER ${UID}

ENTRYPOINT ["tini", "--", "python", "-m", "rds_metadata_exporter"]

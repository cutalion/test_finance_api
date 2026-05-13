# Mirrors what ghcr.io/rails/devcontainer/images/ruby provides, but pinned to a
# Ruby version that the Rails devcontainer image hasn't published yet (4.x).
# Keep RUBY_VERSION in sync with .ruby-version.
ARG RUBY_VERSION=4.0.4
FROM docker.io/library/ruby:${RUBY_VERSION}-bookworm

# System packages needed for development: building native gems, Postgres client,
# and common conveniences. Kept minimal — production deps live in the root Dockerfile.
RUN apt-get update -qq \
 && apt-get install --no-install-recommends -y \
      build-essential \
      curl \
      git \
      libjemalloc2 \
      libpq-dev \
      libyaml-dev \
      pkg-config \
      postgresql-client \
 && rm -rf /var/lib/apt/lists/*

# Bind to all interfaces so the container is reachable from the host.
ENV BINDING=0.0.0.0

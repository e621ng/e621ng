# --- Builder stages ------------------------------------------------------
# Neither of these ends up running; later stages COPY --from them. Isolating
# the installs here keeps the compilers out of the runtime images, and since
# only the lockfiles are copied in, source edits don't invalidate the cached
# gem/npm layers.

# Compiles the gem bundle (native extensions need build-base and the -dev libs).
FROM ruby:3.3.1-alpine3.20 AS ruby-builder

RUN apk --no-cache add build-base cmake git glib-dev postgresql15-dev gcompat ragel

COPY Gemfile Gemfile.lock ./

RUN gem i overmind && BUNDLE_IGNORE_CONFIG=true bundle install -j$(nproc) \
 && rm -rf /usr/local/bundle/cache/*.gem \
 && find /usr/local/bundle/gems/ -name "*.c" -delete \
 && find /usr/local/bundle/gems/ -name "*.o" -delete

# Installs node_modules, and doubles as the donor for the node runtime itself
# (the development stage copies node/npm binaries out of /usr/local).
FROM node:20-alpine3.20 AS node-builder
RUN apk --no-cache add git
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci


# --- Development stage ----------------------------------------------------
# What docker-compose builds (target: development). Contains no app source:
# compose bind-mounts the working tree over /app, so this image only provides
# the runtime (ruby, node, gems, node_modules) plus dev conveniences.

FROM ruby:3.3.1-alpine3.20 AS development

RUN apk --no-cache add vips \
  postgresql15-client \
  git jemalloc tzdata \
  sudo gcompat ragel build-base \
  tmux

# Alpine's ffmpeg lags behind production (6.1.x vs 8.x). Pull a fully-static,
# version-pinned ffmpeg/ffprobe instead so dev matches prod regardless of base image.
COPY --from=mwader/static-ffmpeg:8.1.2 /ffmpeg /ffprobe /usr/bin/

WORKDIR /app

ENV LD_PRELOAD=/usr/lib/libjemalloc.so.2
ENV RUBY_YJIT_ENABLE=1

# Setup node
COPY --from=node-builder /usr/lib /usr/lib
COPY --from=node-builder /usr/local/share /usr/local/share
COPY --from=node-builder /usr/local/lib /usr/local/lib
COPY --from=node-builder /usr/local/include /usr/local/include
COPY --from=node-builder /usr/local/bin /usr/local/bin

# Copy gems and js packages
COPY --from=node-builder /app/node_modules node_modules
COPY --from=ruby-builder /usr/local/bundle /usr/local/bundle

# Create a user with (potentially) the same id as on the host
ARG HOST_UID=1000
ARG HOST_GID=1000
RUN addgroup --gid ${HOST_GID} e621ng && \
  adduser -S --shell /bin/sh --uid ${HOST_UID} e621ng && \
  addgroup e621ng wheel && \
  echo "e621ng ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Ignore warnings from git about .git permission differences when running as root
RUN git config --global --add safe.directory $(pwd)

ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["overmind", "start"]


# --- Production stages ---------------------------------------------------
# The development stage relies on the compose bind mount for source and runs
# everything as root with sudo available. The production image instead bakes
# the source and precompiled assets in, and runs as an unprivileged user.

# Bakes the source in and precompiles assets. Extends development because the
# asset build needs the full toolchain; the result is only COPY'd from.
FROM development AS asset-builder

COPY . .

# application.rb requires this file unconditionally; the real one is gitignored
# and per-machine (prod hosts bind-mount theirs over it), so bake the empty one.
RUN cp docker/danbooru_local_config.rb config/danbooru_local_config.rb

# assets:precompile boots the full app, so every ENV.fetch without a default
# needs a value; none of these influence the built assets. vite_ruby runs
# `npm ci` itself before building (vite:install_dependencies).
RUN RAILS_ENV=production \
  SECRET_TOKEN=build \
  SESSION_SECRET_KEY=build \
  DB_HOST=build DB_PORT=5432 DB_PASSWORD=build \
  DB_POOL_SIZE=1 DB_WORKER_POOL_SIZE=1 \
  DANBOORU_TOTP_ENCRYPTION_KEY=build \
  bundle exec rails assets:precompile \
  && rm -rf node_modules tmp log \
  && mkdir -p tmp log public/data

# The shipped image. Starts from a fresh base rather than development so none
# of the build toolchain carries over; pulls gems from ruby-builder and the
# compiled app from asset-builder.
FROM ruby:3.3.1-alpine3.20 AS production

# Runtime dependencies only: no node, no build toolchain, no sudo.
# git stays because bundler resolves the git-sourced dtext gem at boot.
RUN apk --no-cache add vips \
  postgresql15-client \
  git jemalloc tzdata gcompat

COPY --from=mwader/static-ffmpeg:8.1.2 /ffmpeg /ffprobe /usr/bin/

WORKDIR /app

ENV RAILS_ENV=production
ENV LD_PRELOAD=/usr/lib/libjemalloc.so.2
ENV RUBY_YJIT_ENABLE=1
ENV RAILS_LOG_TO_STDOUT=1

# The image carries no .git; /health and version links read the tag from here.
ARG GIT_TAG=""
ENV DANBOORU_IMAGE_TAG=$GIT_TAG

COPY --from=ruby-builder /usr/local/bundle /usr/local/bundle
# The shared bundle includes overmind (dev-only process manager); drop it.
RUN gem uninstall -Ix overmind
COPY --from=asset-builder /app /app

# Fixed-UID unprivileged user; override with `docker run --user` to match the
# ownership of the NFS export mounted at public/data.
RUN addgroup --gid 1000 e621ng \
  && adduser -S --shell /bin/sh --uid 1000 -G e621ng e621ng \
  && chown -R e621ng:e621ng /app/tmp /app/log /app/public/data
USER e621ng

# Web mode. Jobs mode overrides with: bundle exec sidekiq
CMD ["bundle", "exec", "pitchfork", "-c", "config/pitchfork.rb"]

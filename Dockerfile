FROM ruby:3.2.2-alpine3.18 as ruby-builder

RUN apk --no-cache add build-base cmake git glib-dev postgresql15-dev

COPY Gemfile Gemfile.lock ./
RUN gem i foreman && BUNDLE_IGNORE_CONFIG=true bundle install -j$(nproc) \
 && rm -rf /usr/local/bundle/cache/*.gem \
 && find /usr/local/bundle/gems/ -name "*.c" -delete \
 && find /usr/local/bundle/gems/ -name "*.o" -delete

ARG COMPOSE_PROFILES
RUN if [[ $COMPOSE_PROFILES == *"solargraph"* ]]; then \
  bundle exec yard gems; \
fi

FROM node:18-alpine3.18 as node-builder
RUN apk --no-cache add git
WORKDIR /app
COPY package.json yarn.lock ./
RUN corepack enable && corepack prepare --activate && yarn install

FROM ruby:3.2.2-alpine3.18

RUN apk --no-cache add ffmpeg vips \
  postgresql15-client \
  git jemalloc tzdata

WORKDIR /app

RUN git config --global --add safe.directory $(pwd)

ENV LD_PRELOAD=/usr/lib/libjemalloc.so.2
ENV RUBY_YJIT_ENABLE=1

# Setup node and yarn
COPY --from=node-builder /usr/lib /usr/lib
COPY --from=node-builder /usr/local/share /usr/local/share
COPY --from=node-builder /usr/local/lib /usr/local/lib
COPY --from=node-builder /usr/local/include /usr/local/include
COPY --from=node-builder /usr/local/bin /usr/local/bin
COPY --from=node-builder /root/.cache/node /root/.cache/node

# Copy gems and js packages
COPY --from=node-builder /app/node_modules node_modules
COPY --from=ruby-builder /usr/local/bundle /usr/local/bundle

# Stop bin/rails console from offering autocomplete
RUN echo "IRB.conf[:USE_AUTOCOMPLETE] = false" > ~/.irbrc

CMD ["foreman", "start"]

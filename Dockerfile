FROM ruby:3.1.3-alpine3.17

# Dependencies for setup and runtime
RUN apk --no-cache add nodejs yarn ffmpeg vips \
  postgresql12-client postgresql12-dev \
  bash build-base git glib-dev jemalloc tzdata

RUN git config --global --add safe.directory /app

ENV LD_PRELOAD=/usr/lib/libjemalloc.so.2

# Install js packages and gems
# Put node_modules outside the app volume. Having node_modules be a named volume
# means that on subsequent package changes the named volume will overlay the newly
# installed packages. Not needed for gems since they already install somewhere else.
ENV NODE_PATH=/node_modules
COPY package.json yarn.lock ./
RUN yarn install

COPY Gemfile Gemfile.lock ./
RUN gem install bundler:2.3.12 && \
  bundle install -j$(nproc)

# shoreman
RUN wget -O /usr/bin/shoreman https://github.com/chrismytton/shoreman/raw/master/shoreman.sh \
  && chmod +x /usr/bin/shoreman


# Only setup solargraph stuff when the profile is selected
ARG COMPOSE_PROFILES
RUN if [[ $COMPOSE_PROFILES == *"solargraph"* ]]; then \
  solargraph download-core && bundle exec yard gems && solargraph bundle; \
fi

# Stop bin/rails console from offering autocomplete
RUN echo "IRB.conf[:USE_AUTOCOMPLETE] = false" > ~/.irbrc

WORKDIR /app
CMD [ "shoreman" ]

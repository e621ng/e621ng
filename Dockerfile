FROM ruby:3.1.2-alpine

# Dependencies for setup and runtime
RUN apk --no-cache add nodejs yarn postgresql-client ffmpeg vips tzdata \
  git build-base postgresql-dev glib-dev bash

RUN wget -O - https://github.com/jemalloc/jemalloc/releases/download/5.2.1/jemalloc-5.2.1.tar.bz2 | tar -xj && \
    cd jemalloc-5.2.1 && \
    ./configure && \
    make && \
    make install

RUN git config --global --add safe.directory /app

ENV LD_PRELOAD=/usr/local/lib/libjemalloc.so.2

# Install js packages and gems
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

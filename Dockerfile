FROM ruby:2.7.3-alpine

# Dependencies for setup and runtime
RUN apk --no-cache add nodejs yarn postgresql-client ffmpeg vips tzdata \
  git build-base postgresql-dev glib-dev

RUN wget -O - https://github.com/jemalloc/jemalloc/releases/download/5.2.1/jemalloc-5.2.1.tar.bz2 | tar -xj && \
    cd jemalloc-5.2.1 && \
    ./configure && \
    make && \
    make install

ENV LD_PRELOAD=/usr/local/lib/libjemalloc.so.2

# Install js packages and gems
COPY package.json yarn.lock ./
RUN yarn install

COPY Gemfile Gemfile.lock ./
RUN bundle install

# shoreman
RUN wget -O /usr/bin/shoreman https://github.com/chrismytton/shoreman/raw/master/shoreman.sh \
  && chmod +x /usr/bin/shoreman

WORKDIR /app
CMD [ "shoreman" ]

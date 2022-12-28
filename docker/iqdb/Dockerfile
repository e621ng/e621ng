FROM alpine:3.17 as builder

COPY iqdb.patch /tmp/iqdb.patch
ENV IQDB_VERSION=20161008
ENV IQDB_CHECKSUM=daa4812b35f84bc7e2f07661fd9abf73a06738c76beb92252666a86ebaea3c64
ARG BUILD_DEPS="build-base libjpeg-turbo-dev gd-dev"

RUN apk --no-cache add $BUILD_DEPS \
  && cd /tmp \
  && wget -q  https://iqdb.org/code/iqdb-$IQDB_VERSION.tar.bz2 \
  && echo "$IQDB_CHECKSUM  iqdb-$IQDB_VERSION.tar.bz2" | sha256sum -c - \
  && tar xjf iqdb-$IQDB_VERSION.tar.bz2 \
  && cd iqdb \
  && patch -N -i /tmp/iqdb.patch \
  && make EXTRADEFS="-include stdint.h" -j$(nproc) \
  && apk del $BUILD_DEPS

FROM ruby:3.1.3-alpine3.17

RUN apk --no-cache add git libjpeg-turbo gd tzdata

ADD https://api.github.com/repos/zwagoth/iqdbs/git/refs/heads/master /tmp/iqdbs_version.json
RUN git clone https://github.com/zwagoth/iqdbs /iqdbs \
  && bundler install --gemfile /iqdbs/Gemfile \
  && gem i foreman

COPY --from=builder /tmp/iqdb/iqdb /usr/bin/

WORKDIR /iqdbs

CMD ["foreman", "start"]

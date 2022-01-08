FROM ruby:2.7.3-alpine

ADD https://api.github.com/repos/zwagoth/iqdbs/git/refs/heads/master /tmp/iqdbs_version.json
COPY iqdb.patch /tmp/iqdb.patch
ENV IQDB_VERSION=20161008
ENV IQDB_CHECKSUM=daa4812b35f84bc7e2f07661fd9abf73a06738c76beb92252666a86ebaea3c64

RUN apk --no-cache add build-base git libjpeg-turbo-dev gd-dev bash \
  # iqdb
  && cd /tmp \
  && wget -q  https://iqdb.org/code/iqdb-$IQDB_VERSION.tar.bz2 \
  && echo "$IQDB_CHECKSUM  iqdb-$IQDB_VERSION.tar.bz2" | sha256sum -c - \
  && tar xjf iqdb-$IQDB_VERSION.tar.bz2 \
  && cd iqdb \
  && patch -N -i /tmp/iqdb.patch \
  && make EXTRADEFS="-include stdint.h" -j$(nproc) \
  && cp iqdb /usr/bin \
  # iqdbs
  && git clone https://github.com/zwagoth/iqdbs /iqdbs \
  && bundler install --gemfile /iqdbs/Gemfile \
  # cleanup
  && rm  /tmp/iqdb-$IQDB_VERSION.tar.bz2 \
  && rm -rf /tmp/iqdb \
  && apk del build-base git

# shoreman
RUN wget -O /usr/bin/shoreman https://github.com/chrismytton/shoreman/raw/master/shoreman.sh \
  && chmod +x /usr/bin/shoreman

WORKDIR /iqdbs

CMD [ "shoreman" ]

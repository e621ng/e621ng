FROM postgres:12
ARG BUILD_DEPS="git build-essential make postgresql-server-dev-12 ca-certificates"

RUN apt-get update && apt-get install -y $BUILD_DEPS --no-install-recommends \
  && rm -rf /var/lib/apt/lists/* \
  && git clone https://github.com/r888888888/test_parser.git /tmp/test_parser \
  && cd /tmp/test_parser \
  && make install \
  && rm -rf /tmp/test_parser \
  && apt-get purge -y --auto-remove $BUILD_DEPS

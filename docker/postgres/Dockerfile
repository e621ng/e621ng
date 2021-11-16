FROM postgres:12-alpine
ARG BUILD_DEPS="git make gcc libc-dev clang llvm"

ADD https://api.github.com/repos/r888888888/test_parser/git/refs/heads/master /tmp/test_parser_version.json
RUN apk --no-cache add $BUILD_DEPS \
  && git clone https://github.com/r888888888/test_parser.git /tmp/test_parser \
  && cd /tmp/test_parser \
  && make -j$(nproc) install \
  && rm -rf /tmp/test_parser \
  && apk del $BUILD_DEPS

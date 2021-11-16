FROM postgres:12-alpine
ARG BUILD_DEPS="git make gcc libc-dev clang llvm"

RUN apk --no-cache add $BUILD_DEPS \
  && git clone https://github.com/r888888888/test_parser.git /tmp/test_parser \
  && cd /tmp/test_parser \
  && make install \
  && rm -rf /tmp/test_parser \
  && apk del $BUILD_DEPS

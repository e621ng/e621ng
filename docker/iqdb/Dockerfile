FROM alpine as builder

RUN apk --no-cache add python3 sqlite-dev cmake git build-base

RUN git clone https://github.com/Earlopain/iqdb.git /iqdb \
  && cd /iqdb \
  && git reset --hard 74533c28a7283bd4dbe5f254e9d6cd71ce40bacb
WORKDIR /iqdb
RUN make release

FROM alpine

RUN apk --no-cache add sqlite-libs binutils

COPY --from=builder /iqdb/build/release/src/iqdb /usr/local/bin/

CMD ["iqdb", "http", "0.0.0.0", "5588", "/iqdb/data.db"]

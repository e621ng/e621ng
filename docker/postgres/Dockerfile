FROM postgres:12

RUN apt-get update
RUN apt-get install -y git build-essential postgresql-server-dev-12
RUN git clone https://github.com/r888888888/test_parser.git /tmp/test_parser
RUN make -C /tmp/test_parser install

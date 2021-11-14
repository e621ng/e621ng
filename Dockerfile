FROM ruby:2.7.3
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update
RUN apt-get install -y gnupg2 wget

# Add custom sources
RUN wget -qO - https://deb.nodesource.com/setup_14.x | bash - >/dev/null 2>&1
RUN wget -qO - https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list
RUN wget -qO - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
RUN echo "deb https://apt.postgresql.org/pub/repos/apt/ buster-pgdg main" > /etc/apt/sources.list.d/pgdg.list

RUN apt-get update
RUN apt-get install -y ffmpeg postgresql-client-12 nodejs yarn nginx build-essential pkg-config sudo

# User setup
RUN useradd -m -s /bin/bash -U danbooru
RUN usermod -aG www-data danbooru
RUN echo "%danbooru ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/danbooru

# libvips
RUN apt-get install -y libglib2.0-dev libexpat1-dev liblcms2-dev \
  optipng libjpeg62-turbo-dev libjpeg-progs libgif-dev libpng-dev libexif-dev
ARG VIPS_VERSION=8.10.5
WORKDIR /tmp
RUN wget -q https://github.com/libvips/libvips/releases/download/v$VIPS_VERSION/vips-$VIPS_VERSION.tar.gz
RUN tar xf vips-$VIPS_VERSION.tar.gz
WORKDIR /tmp/vips-$VIPS_VERSION
RUN ./configure --prefix=/usr
RUN make install

# shoreman
RUN wget -O /usr/bin/shoreman https://github.com/chrismytton/shoreman/raw/master/shoreman.sh
RUN chmod +x /usr/bin/shoreman

# prevent permission issues with volume mounts
RUN mkdir /app
RUN chown danbooru:danbooru /app
RUN mkdir /app/public
RUN chown danbooru:danbooru /app/public

RUN mkdir /app/node_modules
RUN mkdir /app/public/packs
RUN mkdir /app/public/packs-test
RUN mkdir /app/public/data

RUN chown  danbooru:danbooru /app/node_modules
RUN chown  danbooru:danbooru /app/public/packs
RUN chown  danbooru:danbooru /app/public/packs-test
RUN chown  danbooru:danbooru /app/public/data

RUN mkdir /home/danbooru/gems
RUN chown  danbooru:danbooru /home/danbooru/gems

USER danbooru

# Setup secrets
RUN mkdir -p ~/.danbooru/
RUN openssl rand -hex 32 > ~/.danbooru/secret_token
RUN openssl rand -hex 32 > ~/.danbooru/session_secret_key
RUN chmod 600 ~/.danbooru/*

WORKDIR /app
CMD [ "shoreman" ]

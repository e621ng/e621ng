FROM ruby:2.7.3
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get install -y gnupg2 wget \
  && rm -rf /var/lib/apt/lists/*

# Add custom sources
RUN wget -qO - https://deb.nodesource.com/setup_14.x | bash - >/dev/null 2>&1 \
  && wget -qO - https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
  && echo "deb https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list \
  && wget -qO - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
  && echo "deb https://apt.postgresql.org/pub/repos/apt/ buster-pgdg main" > /etc/apt/sources.list.d/pgdg.list

RUN apt-get update \
  && apt-get install -y ffmpeg postgresql-client-12 nodejs yarn nginx build-essential pkg-config sudo nano \
  && rm -rf /var/lib/apt/lists/*

# User setup
RUN useradd -m -s /bin/bash -U danbooru \
  && usermod -aG www-data danbooru \
  && echo "%danbooru ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/danbooru

# libvips
ARG VIPS_DEPS="libglib2.0-dev libexpat1-dev liblcms2-dev optipng libjpeg62-turbo-dev libjpeg-progs libgif-dev libpng-dev libexif-dev"
ARG VIPS_VERSION=8.10.5
RUN apt-get update \
  && apt-get install -y $VIPS_DEPS \
  && rm -rf /var/lib/apt/lists/* \
  && cd /tmp \
  && wget -q https://github.com/libvips/libvips/releases/download/v$VIPS_VERSION/vips-$VIPS_VERSION.tar.gz \
  && tar xf vips-$VIPS_VERSION.tar.gz \
  && cd vips-$VIPS_VERSION \
  && ./configure --prefix=/usr \
  && make install \
  && rm /tmp/vips-$VIPS_VERSION.tar.gz \
  && rm -rf /tmp/vips-$VIPS_VERSION

# shoreman
RUN wget -O /usr/bin/shoreman https://github.com/chrismytton/shoreman/raw/master/shoreman.sh \
  && chmod +x /usr/bin/shoreman

# prevent permission issues with volume mounts
RUN mkdir /app \
  && chown danbooru:danbooru /app \
  && mkdir /app/public \
  && chown danbooru:danbooru /app/public \
  && mkdir /app/node_modules \
  && mkdir /app/public/packs \
  && mkdir /app/public/packs-test \
  && mkdir /app/public/data \
  && chown  danbooru:danbooru /app/node_modules \
  && chown  danbooru:danbooru /app/public/packs \
  && chown  danbooru:danbooru /app/public/packs-test \
  && chown  danbooru:danbooru /app/public/data \
  && mkdir /home/danbooru/gems \
  && chown  danbooru:danbooru /home/danbooru/gems

USER danbooru

# Setup secrets
RUN mkdir -p ~/.danbooru/ \
  && openssl rand -hex 32 > ~/.danbooru/secret_token \
  && openssl rand -hex 32 > ~/.danbooru/session_secret_key \
  && chmod 600 ~/.danbooru/*

WORKDIR /app
CMD [ "shoreman" ]

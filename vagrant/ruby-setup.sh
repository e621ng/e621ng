#!/usr/bin/env bash

script_log() {
    echo -e "[setup.sh] >>> $@"
}

APP_DIR=$1
CHRUBY_PATH=$2

source $CHRUBY_PATH

RUBY_VER_NUM=$(cat $APP_DIR/.ruby-version)
RUBY_VER="ruby-$RUBY_VER_NUM"

cd $APP_DIR

if ! command -v ruby >/dev/null || ruby -v | grep -v "$RUBY_VER_NUM" >/dev/null 2>&1; then
    echo "Downloading, compiling and installing $RUBY_VER... (this will take a while)"
    ruby-install $RUBY_VER
    source $CHRUBY_PATH
    chruby $RUBY_VER
fi
if ! command -v ruby >/dev/null; then
    >&2 script_log "**** The install most likely worked, but you will need to run \`vagrant provision\` to finish the setup. ****"
    exit 1
else
    script_log "Installed ruby version: $(ruby -v)"
fi

script_log "Installing bundler gem..."
gem install bundler:2.0.1 >/dev/null
bundler config github.https true

script_log "Dropping existing databases (if any)..."
dropdb danbooru2
dropdb danbooru2_test

script_log "Creating config files..."
sed -s "s/url: <%= .* %>/host: localhost/g" script/install/database.yml.templ > config/database.yml
cp script/install/danbooru_local_config.rb.templ config/danbooru_local_config.rb
mkdir -p ~/.danbooru/
openssl rand -hex 32 > ~/.danbooru/secret_token
openssl rand -hex 32 > ~/.danbooru/session_secret_key
chmod 600 ~/.danbooru/*

script_log "Running yarn..."
yarn install

script_log "Running setup..."
./bin/setup
exit

server: bin/rails server -p 9000 -b 0.0.0.0 --pid=/tmp/rails-server.pid
# server: bundle exec unicorn -c config/unicorn/development.rb
jobs: SIDEKIQ_QUEUES="low_prio:1;video:1;iqdb:1;tags:2;default:3;high_prio:5" bundle exec sidekiq
cron: run-parts /etc/periodic/daily && crond -f

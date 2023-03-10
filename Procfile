server: bin/rails server -p 9000 -b 0.0.0.0
# server: bundle exec unicorn -c config/unicorn/development.rb
jobs: bundle exec sidekiq -c 1 -q low_prio -q tags -q default -q high_prio -q video
cron: run-parts /etc/periodic/daily && crond -f

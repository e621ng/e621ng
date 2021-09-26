unicorn: bin/rails server -p 9000
jobs: bundle exec sidekiq -c 1 -q low_prio -q tags -q default -q high_prio -q video
iqdb: cd iqdbs && shoreman

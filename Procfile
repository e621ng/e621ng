unicorn: bin/rails server -p 9000
jobs: bundle exec sidekiq -c 1 -q low_prio -q tags -q default -q high_prio
recommender: bundle exec ruby script/mock_services/recommender.rb
iqdbs: bundle exec ruby script/mock_services/iqdbs.rb
reportbooru: bundle exec ruby script/mock_services/reportbooru.rb

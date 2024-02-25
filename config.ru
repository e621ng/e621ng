# frozen_string_literal: true

# This file is used by Rack-based servers to start the application.

if defined?(Unicorn) && ENV["RAILS_ENV"] == "production"
  # Unicorn self-process killer
  require 'unicorn/worker_killer'

  # Max requests per worker
  use Unicorn::WorkerKiller::MaxRequests, 5_000, 10_000

  # Max memory size (RSS) per worker
  use Unicorn::WorkerKiller::Oom, (386*(1024**2)), (768*(1024**2))
end

require ::File.expand_path('../config/environment',  __FILE__)

run Rails.application

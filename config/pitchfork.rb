# frozen_string_literal: true

require "dotenv"

# Should be "production" by default, otherwise use other env
rails_env = ENV.fetch("RAILS_ENV", "production")

Dotenv.load(".env.#{rails_env}")

timeout 180
listen ENV.fetch("PITCHFORK_LISTEN_ADDRESS"), tcp_nopush: true, backlog: 2048
worker_processes ENV.fetch("PITCHFORK_WORKER_COUNT").to_i

after_worker_ready do |server, worker|
  max_requests = Random.rand(5_000..10_000)
  worker.instance_variable_set(:@_max_requests, max_requests)
  max_mem = Random.rand((386 * (1024**2))..(768 * (1024**2)))
  worker.instance_variable_set(:@_max_mem, max_mem)

  server.logger.info("worker=#{worker.nr} gen=#{worker.generation} ready, serving #{max_requests} requests, #{max_mem} bytes")
end

after_request_complete do |server, worker, _env|
  if worker.requests_count > worker.instance_variable_get(:@_max_requests)
    server.logger.info("worker=#{worker.nr} gen=#{worker.generation}) exit: request limit (#{worker.instance_variable_get(:@_max_requests)})")
    exit # rubocop:disable Rails/Exit
  end

  if worker.requests_count % 16 == 0
    mem_info = Pitchfork::MemInfo.new(worker.pid)
    if mem_info.pss > worker.instance_variable_get(:@_max_mem)
      server.logger.info("worker=#{worker.nr} gen=#{worker.generation}) exit: memory limit (#{mem_info.pss} bytes > #{worker.instance_variable_get(:@_max_mem)} bytes)")
      exit # rubocop:disable Rails/Exit
    end
  end
end

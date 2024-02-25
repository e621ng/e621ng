# frozen_string_literal: true

# Set your full path to application.
app_path = "/app"

# Set unicorn options
worker_processes 2

preload_app false
timeout 180
listen "0.0.0.0:9000"

# Fill path to your app
working_directory app_path

# Log everything to one file
stderr_path "log/unicorn.log"
stdout_path "log/unicorn.log"

# Set master PID location
pid "#{app_path}/tmp/pids/unicorn.pid"

# frozen_string_literal: true

# Runs ffmpeg and ffprobe on untrusted files with time, CPU and memory limits, so a
# malicious file can't make them run forever or use all the memory.
# Based on Danbooru's ExternalCommand (danbooru/danbooru@1e2e0b72, @1c2545c3). The timeout
# is enforced here rather than with timeout(1): the image's BusyBox version has no
# --kill-after and its exit status can't be told apart from the program's own.
module ExternalCommand
  class TimeoutError < StandardError; end

  MEMORY_LIMIT = 4.gigabytes
  # CPU seconds allowed per second of wall-clock timeout, summed across threads.
  CPU_PER_SECOND = 4
  # SIGXCPU arrives at the CPU limit; SIGKILL follows this much later for commands that
  # catch it (ffmpeg treats SIGXCPU like SIGTERM and exits with an ordinary error).
  CPU_KILL_GRACE = 10
  # Only the end of each output stream is kept, so a file that makes ffmpeg print errors
  # for the whole timeout can't fill the worker's memory. The end holds what callers parse.
  OUTPUT_LIMIT = 1.megabyte
  # Only these variables reach the command, so it can't read secrets such as the database
  # password or signing keys out of its own environment. PATH resolves bare program names;
  # LD_PRELOAD/MALLOC_CONF keep jemalloc (see the Dockerfile) for dynamically linked commands.
  ENVIRONMENT = %w[PATH LD_PRELOAD MALLOC_CONF].freeze

  module_function

  # Same return value as Open3.capture3: [stdout, stderr, Process::Status].
  # The command gets only the variables in ENVIRONMENT, not the Rails process's environment.
  # The CPU limit is enforced by the kernel, so it still applies if this process dies
  # and the command is orphaned.
  def run(*argv, timeout:, memory: MEMORY_LIMIT, cpu: timeout * CPU_PER_SECOND)
    program = File.basename(argv.first.to_s)
    cpu = cpu.ceil

    # Core dumps are disabled so a command that crashes at the memory limit can't fill the disk.
    Open3.popen3(ENV.slice(*ENVIRONMENT), *argv, unsetenv_others: true, rlimit_as: memory.to_i, rlimit_cpu: [cpu, cpu + CPU_KILL_GRACE], rlimit_core: 0, pgroup: true) do |stdin, stdout, stderr, wait_thr|
      stdin.close
      out_reader = Thread.new { read_tail(stdout) }
      err_reader = Thread.new { read_tail(stderr) }

      unless wait_thr.join(timeout)
        kill(wait_thr)
        out_reader.join
        err_reader.join
        raise TimeoutError, "#{program} timed out after #{timeout.to_i} seconds"
      end

      status = wait_thr.value
      raise TimeoutError, "#{program} exceeded its CPU time limit of #{cpu} seconds" if status.termsig == Signal.list["XCPU"]

      [out_reader.value, err_reader.value, status]
    ensure
      # An exception raised into this thread (e.g. a Sidekiq hard shutdown) would otherwise
      # leave popen3 waiting for the command to finish on its own.
      kill(wait_thr) if wait_thr&.alive?
    end
  end

  # Kills the whole process group, in case the command started children of its own.
  def kill(wait_thr)
    Process.kill(:KILL, -wait_thr.pid)
  rescue Errno::ESRCH
    nil
  ensure
    wait_thr.join
  end

  def read_tail(io)
    output = +"".b
    loop do
      output << io.readpartial(64.kilobytes)
      output = output.byteslice(-OUTPUT_LIMIT, OUTPUT_LIMIT) if output.bytesize > OUTPUT_LIMIT
    end
  rescue EOFError
    output.force_encoding(Encoding.default_external)
  end

  private_class_method :kill, :read_tail
end

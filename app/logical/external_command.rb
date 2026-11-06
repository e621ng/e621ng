# frozen_string_literal: true

# Runs ffmpeg and ffprobe on untrusted files with time, CPU and memory limits, so a
# malicious file can't make them run forever or use all the memory.
# Based on Danbooru's ExternalCommand (danbooru/danbooru@1e2e0b72). The timeout is
# enforced here rather than with timeout(1): the image's BusyBox version has no
# --kill-after and its exit status can't be told apart from the program's own.
module ExternalCommand
  class TimeoutError < StandardError; end

  MEMORY_LIMIT = 4.gigabytes
  # CPU seconds allowed per second of wall-clock timeout, summed across threads.
  CPU_PER_SECOND = 4
  # SIGXCPU arrives at the CPU limit; SIGKILL follows this much later for commands that
  # catch it (ffmpeg treats SIGXCPU like SIGTERM and exits with an ordinary error).
  CPU_KILL_GRACE = 10

  module_function

  # Same return value as Open3.capture3: [stdout, stderr, Process::Status].
  # The CPU limit is enforced by the kernel, so it still applies if this process dies
  # and the command is orphaned.
  def run(*argv, timeout:, memory: MEMORY_LIMIT, cpu: timeout * CPU_PER_SECOND)
    program = File.basename(argv.first.to_s)
    cpu = cpu.ceil

    # Core dumps are disabled so a command that crashes at the memory limit can't fill the disk.
    Open3.popen3(*argv, rlimit_as: memory.to_i, rlimit_cpu: [cpu, cpu + CPU_KILL_GRACE], rlimit_core: 0, pgroup: true) do |stdin, stdout, stderr, wait_thr|
      stdin.close
      out_reader = Thread.new { stdout.read }
      err_reader = Thread.new { stderr.read }

      unless wait_thr.join(timeout)
        # Kill the whole process group, in case the command started children of its own.
        begin
          Process.kill(:KILL, -wait_thr.pid)
        rescue Errno::ESRCH
          nil
        end
        wait_thr.join
        out_reader.join
        err_reader.join
        raise TimeoutError, "#{program} timed out after #{timeout.to_i} seconds"
      end

      status = wait_thr.value
      raise TimeoutError, "#{program} exceeded its CPU time limit of #{cpu} seconds" if status.termsig == Signal.list["XCPU"]

      [out_reader.value, err_reader.value, status]
    end
  end
end

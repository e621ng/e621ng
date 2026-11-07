# frozen_string_literal: true

require "rails_helper"

# Cases adapted from Danbooru's ExternalCommand tests (danbooru/danbooru@1e2e0b72, @1c2545c3, @fb5fb418).
RSpec.describe ExternalCommand do
  def seconds_taken
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
  rescue described_class::TimeoutError
    Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
  end

  # A killed orphan is reparented to PID 1, which may never reap it, so a zombie counts as dead.
  def running?(pid)
    File.read("/proc/#{pid}/stat")[/\) (\S)/, 1] != "Z"
  rescue Errno::ENOENT
    false
  end

  def still_running_after_one_second?(pid)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 1
    while running?(pid)
      return true if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      sleep 0.05
    end
    false
  end

  describe ".run" do
    it "returns stdout, stderr and the exit status" do
      stdout, stderr, status = described_class.run("sh", "-c", "echo out; echo err >&2; exit 3", timeout: 5)
      expect(stdout).to eq("out\n")
      expect(stderr).to eq("err\n")
      expect(status.exitstatus).to eq(3)
    end

    it "kills commands that run longer than the timeout" do
      expect { described_class.run("sleep", "30", timeout: 1) }
        .to raise_error(described_class::TimeoutError, "sleep timed out after 1 seconds")
      expect(seconds_taken { described_class.run("sleep", "30", timeout: 1) }).to be < 5
    end

    it "kills the command's own children on timeout" do
      pid_file = Tempfile.new("child-pid")
      expect { described_class.run("sh", "-c", "sleep 30 & echo $! > #{pid_file.path}; wait", timeout: 1) }
        .to raise_error(described_class::TimeoutError)

      child_pid = File.read(pid_file.path).to_i
      expect(child_pid).to be > 0
      expect(still_running_after_one_second?(child_pid)).to be(false)
    ensure
      pid_file&.close!
    end

    it "stops commands that use more CPU time than allowed" do
      expect { described_class.run("sh", "-c", "while :; do :; done", timeout: 30, cpu: 1) }
        .to raise_error(described_class::TimeoutError, "sh exceeded its CPU time limit of 1 seconds")
      expect(seconds_taken { described_class.run("sh", "-c", "while :; do :; done", timeout: 30, cpu: 1) }).to be < 10
    end

    it "lets commands that catch SIGXCPU exit on their own" do
      script = "trap 'exit 7' XCPU; while :; do :; done"
      _stdout, _stderr, status = described_class.run("sh", "-c", script, timeout: 30, cpu: 1)
      expect(status.exitstatus).to eq(7)
    end

    it "kills the command when the waiting thread is interrupted" do
      pid_file = Tempfile.new("command-pid")
      waiter = Thread.new { described_class.run("sh", "-c", "echo $$ > #{pid_file.path}; exec sleep 30", timeout: 60) }
      waiter.report_on_exception = false
      sleep 0.05 until File.size?(pid_file.path)

      waiter.raise(RuntimeError, "shutdown")
      expect { waiter.join }.to raise_error(RuntimeError, "shutdown")
      expect(still_running_after_one_second?(File.read(pid_file.path).to_i)).to be(false)
    ensure
      pid_file&.close!
    end

    it "keeps only the end of long output" do
      stdout, _stderr, _status = described_class.run("sh", "-c", "yes x | head -c 3000000; echo TAIL", timeout: 30)
      expect(stdout.bytesize).to eq(described_class::OUTPUT_LIMIT)
      expect(stdout).to end_with("TAIL\n")
      expect(stdout.encoding).to eq(Encoding.default_external)
    end

    it "does not let commands write core dumps" do
      stdout, _stderr, _status = described_class.run("sh", "-c", "ulimit -c", timeout: 5)
      expect(stdout).to eq("0\n")
    end

    it "does not pass the environment to commands" do
      ENV["E621_EXTERNAL_COMMAND_TEST_SECRET"] = "secret"
      stdout, _stderr, _status = described_class.run("env", timeout: 5)
      expect(stdout.lines.map { |line| line.split("=").first }.sort)
        .to eq(ENV.slice(*described_class::ENVIRONMENT).keys.sort)
    ensure
      ENV.delete("E621_EXTERNAL_COMMAND_TEST_SECRET")
    end

    it "passes extra variables given with env" do
      stdout, _stderr, _status = described_class.run("env", env: { "E621_EXTERNAL_COMMAND_EXTRA" => "1" }, timeout: 5)
      expect(stdout.lines).to include("E621_EXTERNAL_COMMAND_EXTRA=1\n")
      expect(stdout.lines.map { |line| line.split("=").first }.sort)
        .to eq((ENV.slice(*described_class::ENVIRONMENT).keys + ["E621_EXTERNAL_COMMAND_EXTRA"]).sort)
    end

    it "does not let commands read the environment of the Rails process" do
      _stdout, stderr, status = described_class.run("cat", "/proc/#{Process.pid}/environ", timeout: 5)
      expect(status).not_to be_success
      expect(stderr).to include("Permission denied")
    end

    it "does not let commands use more memory than the limit" do
      _stdout, _stderr, status = described_class.run("ruby", "--disable=jit", "-e", "puts 1", timeout: 30, memory: 500.megabytes)
      expect(status).to be_success

      _stdout, stderr, status = described_class.run("ruby", "--disable=jit", "-e", %{puts ("a" * 1_000_000_000).size}, timeout: 30, memory: 500.megabytes)
      expect(status).not_to be_success
      expect(stderr).to match(/NoMemoryError|failed to allocate memory/)
    end
  end
end

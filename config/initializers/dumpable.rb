# frozen_string_literal: true

require "ffi"

# Marks the process non-dumpable so other processes running as the same user (e.g. ffmpeg
# exploited by a malicious upload) can't read our secrets from /proc/<pid>/environ or
# /proc/<pid>/mem, or attach with ptrace. Also disables core dumps. Forked Pitchfork and
# Sidekiq workers inherit it. Based on danbooru/danbooru@fb5fb418.
# @see https://man7.org/linux/man-pages/man2/PR_SET_DUMPABLE.2const.html
module Prctl
  extend FFI::Library

  ffi_lib FFI::Library::LIBC

  PR_SET_DUMPABLE = 4

  attach_function :prctl, %i[int ulong ulong ulong ulong], :int
end

raise SystemCallError.new("prctl(PR_SET_DUMPABLE, 0) failed", FFI.errno) if Prctl.prctl(Prctl::PR_SET_DUMPABLE, 0, 0, 0, 0) < 0

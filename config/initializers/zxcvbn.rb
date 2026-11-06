# frozen_string_literal: true

# Building a Tester reads ~650 KB of word-list files from disk.
# Build it once at boot so the work happens before workers fork.
ZXCVBN_TESTER = Zxcvbn.tester_builder.build

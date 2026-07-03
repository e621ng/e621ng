# frozen_string_literal: true

# Zxcvbn::Tester reads ~650 KB of word-list files from disk on initialization.
# Zxcvbn.test() creates a new Tester on every call, making password validation
# extremely slow. Cache a single instance here so the work only happens once
# per process.
ZXCVBN_TESTER = Zxcvbn::Tester.new

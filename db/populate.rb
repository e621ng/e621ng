# frozen_string_literal: true

# Loads the development data generators. Run them through the populate:* rake
# tasks (lib/tasks/populate.rake) or bin/populate.

require_relative "populate/base"
Dir[File.join(__dir__, "populate", "*.rb")].each { |file| require file }

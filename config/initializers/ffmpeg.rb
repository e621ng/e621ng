# frozen_string_literal: true

unless Rails.env.development?
  FFMPEG.logger.level = Logger::ERROR
end

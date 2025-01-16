# frozen_string_literal: true

class DanbooruLogger
  def self.log(exception, expected: false)
    if expected
      Rails.logger.info("#{exception.class}: #{exception.message}")
    else
      backtrace = Rails.backtrace_cleaner.clean(exception.backtrace).join("\n")
      Rails.logger.error("#{exception.class}: #{exception.message}\n#{backtrace}")
    end

    Datadog::Tracing.active_span&.set_error(exception) unless expected
  end

  def self.initialize(user)
    add_attributes("user.id" => user.id) unless user.is_anonymous?
  end

  def self.add_attributes(**)
    Datadog::Tracing.active_span&.set_tags(**)
  end
end

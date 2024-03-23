# frozen_string_literal: true

class DanbooruLogger
  def self.log(exception, expected: false, **_params)
    if expected
      Rails.logger.info("#{exception.class}: #{exception.message}")
    else
      backtrace = Rails.backtrace_cleaner.clean(exception.backtrace).join("\n")
      Rails.logger.error("#{exception.class}: #{exception.message}\n#{backtrace}")
    end
  end

  def self.initialize(user)
    add_attributes("user.id" => user.id, "user.name" => user.name)
  end

  def self.add_attributes(**)
    # noop
  end
end

require 'securerandom'

class ExceptionLog < ApplicationRecord
  serialize :extra_params, JSON

  def self.add(exc, ip_addr, params = {})
    log = self.new(
        ip_addr: ip_addr || '0.0.0.0',
        class_name: exc.class.name,
        message: exc.message,
        trace: exc.backtrace.join("\n"),
        code: SecureRandom.uuid,
        version: "#{Danbooru.config.version} (#{Rails.application.config.x.git_hash})",
        extra_params: params
    )
    log.save!
    log
  end
end

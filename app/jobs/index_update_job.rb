# frozen_string_literal: true

class IndexUpdateJob
  include Sidekiq::Worker
  sidekiq_options queue: 'high_prio', lock: :until_executing

  def perform(klass, id)
    begin
      obj = klass.constantize.find(id)
      obj.update_index(defer: false) if obj
    rescue ActiveRecord::RecordNotFound
      return
    end
  end

  def unique_args(args)
    Rails.logger.error("Unique args called: #{args.inspect}")
    [args[1]]
  end
end

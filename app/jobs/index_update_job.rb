# frozen_string_literal: true

class IndexUpdateJob
  include Sidekiq::Worker
  sidekiq_options queue: 'high_prio', lock: :until_executing, unique_args: ->(args) { args[1] }

  def perform(klass, id)
    begin
      obj = klass.constantize.find(id)
      obj.update_index(defer: false) if obj
    rescue ActiveRecord::RecordNotFound
      return
    end
  end
end

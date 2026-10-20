# frozen_string_literal: true

module DocumentStore
  class ReindexWorker
    include Sidekiq::Worker
    sidekiq_options queue: :default, retry: 5

    def perform(model_class, record_id)
      record = model_class.constantize.find_by(id: record_id)
      return unless record

      record.update_index
      Rails.logger.info("[DocumentStore] Successfully re-indexed #{model_class}##{record_id}")
    end
  end
end

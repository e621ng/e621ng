# frozen_string_literal: true

# Enqueue only after the surrounding DB transaction commits (and drop on rollback),
# so the worker never runs before the row it reads is committed. Off in test, where
# transactional fixtures never commit and a deferred push would never fire.
module TransactionalEnqueue
  extend ActiveSupport::Concern

  included do
    unless Rails.env.test?
      require "sidekiq/transaction_aware_client"
      sidekiq_options client_class: Sidekiq::TransactionAwareClient
    end
  end
end

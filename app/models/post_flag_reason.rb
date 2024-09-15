# frozen_string_literal: true

class PostFlagReason < ApplicationRecord
  belongs_to_creator
  belongs_to_updater

  validates :name, uniqueness: true, length: { maximum: 128 }, presence: true
  validates :reason, length: { maximum: 256 }, presence: true
  validates :text, length: { maximum: 1024 }, presence: true
  validates :order, uniqueness: true, numericality: { only_integer: true, greater_than: 0 }
  scope :ordered, -> { order(:order) }

  before_validation :initialize_order, on: :create
  after_create :log_create
  after_update :log_update
  after_destroy :log_destroy
  after_commit :invalidate_cache

  def initialize_order
    self.order = PostFlagReason.maximum(:order).to_i + 1
  end

  def invalidate_cache
    Cache.delete("post_flag_reasons")
  end

  def self.cached
    Cache.fetch("post_flag_reasons", expires_in: 12.hours) do
      PostFlagReason.ordered.index_by { |x| x[:name] }
    end
  end

  module LogMethods
    extend ActiveSupport::Concern

    module ClassMethods
      def log_reorder(count)
        ModAction.log(:post_flag_reasons_reorder, { count: count })
      end
    end

    def log_create
      ModAction.log(:post_flag_reason_create, { post_flag_reason_id: id, name: name, reason: reason, text: text, parent: parent })
    end

    def log_update
      ModAction.log(:post_flag_reason_update, { post_flag_reason_id: id, name: name, reason: reason, text: text, parent: parent })
    end

    def log_destroy
      ModAction.log(:post_flag_reason_delete, { post_flag_reason_id: id, name: name, reason: reason, text: text, parent: parent })
    end
  end

  include LogMethods
end

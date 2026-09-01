# frozen_string_literal: true

class UserVote < ApplicationRecord
  class Error < Exception; end

  self.abstract_class = true

  belongs_to :user
  validates :score, inclusion: { in: [-1, 0, 1], message: "must be 1 or -1" }
  after_initialize :initialize_attributes, if: :new_record?
  scope :for_user, ->(uid) { where("user_id = ?", uid) }

  def self.inherited(child_class)
    super
    child_class.class_eval do
      belongs_to model_type
    end
  end

  # PostVote => :post
  def self.model_type
    model_name.singular.delete_suffix("_vote").to_sym
  end

  def initialize_attributes
    self.user_id ||= CurrentUser.user.id
    self.user_ip_addr ||= CurrentUser.ip_addr
  end

  def is_positive?
    score == 1
  end

  def is_negative?
    score == -1
  end

  def is_locked?
    score == 0
  end

  module SearchMethods
    def search(params)
      q = super

      if params["#{model_type}_id"].present?
        q = q.where("#{model_type}_id" => params["#{model_type}_id"].split(",").first(Danbooru.config.max_per_page))
      end

      q = q.where_user(:user_id, :user, params)

      # Plain single-column filters on this table. Cheap to apply on top of the
      # default id-ordered pagination, so they don't need a narrowing param.
      if params[:score].present?
        q = q.where("#{table_name}.score = ?", params[:score])
      end

      if params[:timeframe].present?
        q = q.where("#{table_name}.updated_at >= ?", params[:timeframe].to_i.days.ago)
      end

      if params[:user_ip_addr].present?
        q = q.where("user_ip_addr <<= ?", params[:user_ip_addr])
      end

      # Whether the query is already narrowed to a specific subject or voter.
      # Gates operations that would otherwise scan/join/aggregate the whole table.
      narrowed = (params.keys & ["#{model_type}_id", "user_name", "user_id"]).any?

      if narrowed
        q = q.where_user({ model_type => :"#{model_creator_column}_id" }, :"#{model_type}_creator", params) do |q, _user_ids|
          q.joins(model_type)
        end

        if params[:duplicates_only].to_s.truthy?
          subselect = search(params.except("duplicates_only")).select(:user_ip_addr).group(:user_ip_addr).having("count(user_ip_addr) > 1").reorder("")
          q = q.where(user_ip_addr: subselect)
        end
      end

      if params[:order] == "ip_addr" && narrowed
        q = q.order(:user_ip_addr)
      else
        q = q.apply_basic_order(params)
      end
      q
    end
  end

  extend SearchMethods
end

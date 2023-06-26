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
        q = q.where("#{model_type}_id" => params["#{model_type}_id"].split(",").first(100))
      end

      if params[:user_name].present?
        user_id = User.name_to_id(params[:user_name])
        if user_id
          q = q.where("user_id = ?", user_id)
        else
          q = q.none
        end
      end

      if params[:user_id].present?
        q = q.where(user_id: params[:user_id].split(",").first(100))
      end

      allow_complex_params = (params.keys & ["#{model_type}_id", "user_name", "user_id"]).any?

      if allow_complex_params
        if params[:"#{model_type}_creator_name"].present?
          creator_id = User.name_to_id(params[:"#{model_type}_creator_name"])
          if creator_id
            q = q.joins(model_type).where(model_type => { "#{model_creator_column}_id": creator_id })
          else
            q = q.none
          end
        end

        if params[:timeframe].present?
          q = q.where("#{table_name}.updated_at >= ?", params[:timeframe].to_i.days.ago)
        end

        if params[:user_ip_addr].present?
          q = q.where("user_ip_addr <<= ?", params[:user_ip_addr])
        end

        if params[:score].present?
          q = q.where("#{table_name}.score = ?", params[:score])
        end

        if params[:duplicates_only].to_s.truthy?
          subselect = search(params.except("duplicates_only")).select(:user_ip_addr).group(:user_ip_addr).having("count(user_ip_addr) > 1").reorder("")
          q = q.where(user_ip_addr: subselect)
        end
      end

      if params[:order] == "ip_addr" && allow_complex_params
        q = q.order(:user_ip_addr)
      else
        q = q.apply_default_order(params)
      end
      q
    end
  end

  extend SearchMethods
end

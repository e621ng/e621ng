# frozen_string_literal: true

class ExceptionLog < ApplicationRecord
  serialize :extra_params, coder: JSON
  belongs_to :user, class_name: "User", optional: true

  def self.add(exception, user_id, request)
    extra_params = {
      host: Socket.gethostname,
      params: request.filtered_parameters,
      user_id: user_id,
      referrer: request.referrer,
      user_agent: request.user_agent,
    }

    # Required to unwrap exceptions that occur inside template rendering.
    unwrapped_exception = exception
    if exception.is_a?(ActionView::Template::Error)
      unwrapped_exception = exception.cause
    end

    if unwrapped_exception.is_a?(ActiveRecord::QueryCanceled)
      extra_params[:sql] = {}
      extra_params[:sql][:query] = unwrapped_exception&.sql || "[NOT FOUND?]"
      extra_params[:sql][:binds] = unwrapped_exception&.binds&.map(&:value_for_database)
    end

    create!(
      ip_addr: request.remote_ip || "0.0.0.0",
      class_name: unwrapped_exception.class.name,
      message: unwrapped_exception.message,
      trace: unwrapped_exception.backtrace.join("\n"),
      code: SecureRandom.uuid,
      version: GitHelper.short_hash,
      user_id: user_id,
      extra_params: extra_params,
    )
  end

  def user
    # Prior to March 2024, user IDs were only stored in the extra_params["user_id"] field,
    # instead of the user_id database column. As of March 2024, this was fixed and user_id is now
    # properly stored in the user_id column. This fallback is needed to support old records.
    return super if super.present?
    User.find_by(id: extra_params["user_id"])
  end

  def self.search(params)
    q = super

    if params[:user_name].present?
      q = q.where_user(:user_id, :user, params)
    end

    if params[:code].present?
      q = q.where(code: params[:code])
    end

    if params[:commit].present?
      q = q.where(version: params[:commit])
    end

    if params[:class_name].present?
      q = q.where(class_name: params[:class_name])
    end

    if params[:without_class_name].present?
      q = q.where.not(class_name: params[:without_class_name])
    end

    q.apply_basic_order(params)
  end
end

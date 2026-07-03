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
      extra_params[:sql][:binds] = unwrapped_exception&.binds&.map do |bind|
        if bind.respond_to?(:value_for_database)
          bind.value_for_database
        else
          bind.to_s
        end
      end
    end

    create!(
      ip_addr: request.remote_ip,
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
    # Prior to September 2025, user IDs were only stored in the extra_params["user_id"] field,
    # instead of the user_id database column. As of March 2024, this was fixed and user_id is now
    # properly stored in the user_id column. This fallback is needed to support old records.
    # TODO: Remove this fallback in September 2026.
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

  # Delete exception logs older than the given duration (defaults to 1 year).
  # Uses batched deletes to avoid long-running transactions and excessive locks.
  def self.prune!(older_than: 1.year, batch_size: 1_000)
    cutoff = Time.zone.now - older_than

    # Determine the maximum id for the cutoff set to avoid scanning through irrelevant rows.
    max_id = where("created_at < ?", cutoff).maximum(:id)
    return 0 if max_id.nil?

    total = 0
    where("id <= ? AND created_at < ?", max_id, cutoff)
      .in_batches(of: batch_size, load: false) do |relation|
        total += relation.delete_all
      end

    total
  end

  def viewable_message
    if CurrentUser.is_admin?
      message
    else
      scrub_ips(scrub_emails(message))
    end
  end

  def viewable_extra_params
    if CurrentUser.is_admin?
      extra_params
    else
      extra_params.deep_transform_values do |value|
        next value unless value.is_a?(String)
        next scrub_emails(value) if value == extra_params["user_agent"]
        scrub_ips(scrub_emails(value))
      end
    end
  end

  private

  def scrub_ips(text)
    return text unless text.is_a?(String)

    # First, explicitly replace dotted IPv4 addresses (with optional port/brackets/CIDR)
    ipv4_regex = /(?:\b|\[)((?:\d{1,3}\.){3}\d{1,3})(?:\]|\b)(?::\d{1,5})?/

    text = text.gsub(ipv4_regex) do |match|
      ip = Regexp.last_match(1)
      begin
        IPAddr.new(ip)
        "[IP PROTECTED]"
      rescue StandardError
        match
      end
    end

    # Then handle IPv6 and other candidate tokens (bracketed or bare), stripping CIDR/zone ids
    candidate_regex = %r{(?:\b|\[)([0-9A-Fa-f:.%/]+)(?:\]|\b)(?::\d{1,5})?}

    text.gsub(candidate_regex) do |match|
      token = Regexp.last_match(1)
      candidate = token.sub(%r{/\d+\z}, "").sub(/%.+\z/, "")

      # Skip the literal "::" separator to avoid false positives in log messages
      if candidate == "::"
        match
      else
        begin
          IPAddr.new(candidate)
          "[IP PROTECTED]"
        rescue StandardError
          match
        end
      end
    end
  end

  def scrub_emails(text)
    text.gsub(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i, "[EMAIL PROTECTED]")
  end
end

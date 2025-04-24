# frozen_string_literal: true

module RenderPartialSafely
  extend ActiveSupport::Concern

  private

  def render_partial_safely(path, locals = {})
    render partial: path, locals: locals
  rescue StandardError => e
    logger.error("Partial render failed: #{e.class} - #{e.message}")
    logger.error(e.backtrace.join("\n")) if Rails.env.development?

    message = if request.local? || CurrentUser.user&.is_janitor?
                "#{e.class}: #{e.message}"
              else
                "An unexpected error occurred while updating the page."
              end

    render plain: message, status: 500
  end
end

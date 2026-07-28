# frozen_string_literal: true

module RenderPartialSafely
  extend ActiveSupport::Concern

  private

  def render_partial_safely(path, locals = {})
    render partial: path, locals: locals
  rescue StandardError => e
    render_safe_failure(e)
  end

  def render_component_safely(component)
    render(component)
  rescue StandardError => e
    render_safe_failure(e)
  end

  def render_safe_failure(error)
    logger.error("Partial render failed: #{error.class} - #{error.message}")
    logger.error(error.backtrace.join("\n")) if Rails.env.development?

    message = if request.local? || CurrentUser.user&.is_staff?
                "#{error.class}: #{error.message}"
              else
                "An unexpected error occurred while updating the page."
              end

    render plain: message, status: 500
  end
end

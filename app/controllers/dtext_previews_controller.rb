# frozen_string_literal: true

class DtextPreviewsController < ApplicationController
  # Tripwire only: the parse has already allocated the string by the time this runs.
  MAX_OUTPUT_BYTES = 2.megabytes

  before_action :logged_in_only
  before_action :check_throttle

  def create
    body = params[:body]
    body = "" unless body.is_a?(String)
    max_size = Danbooru.config.dtext_preview_max_size.to_i
    return render_expected_error(413, "Preview input is too long (max #{max_size} characters)") if body.length > max_size

    dtext = helpers.format_text(body, allow_color: params[:allow_color].to_s.truthy?)
    return render_expected_error(413, "Preview output is too large") if dtext.bytesize > MAX_OUTPUT_BYTES

    render json: { html: dtext, posts: deferred_posts }
  end

  private

  def check_throttle
    raise APIThrottled if RateLimiter.throttle!("dtext_preview:#{CurrentUser.id}", limit: 20, period: 1.minute)
  end
end

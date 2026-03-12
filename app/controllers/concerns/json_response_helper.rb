# frozen_string_literal: true

module JsonResponseHelper
  extend ActiveSupport::Concern

  private

  # Renders JSON data with optional unwrapping for API transition
  #
  # @param data [Hash, Array] The data to render
  # @param wrapper_key [Symbol] The key to wrap the data in (e.g., :posts, :post)
  # @param collection [Boolean] Whether this is a collection response (for auto-wrapper naming)
  def render_json_with_wrapper(data, wrapper_key: nil, collection: false)
    if params[:only].present?
      render json: data
    else
      # Backward compatibility: wrap in object
      wrapper_key ||= collection ? :posts : :post
      render json: { wrapper_key => data }
    end
  end

  def render_posts_json(posts_data, collection: false)
    wrapper_key = collection ? :posts : :post
    render_json_with_wrapper(posts_data, wrapper_key: wrapper_key)
  end

  def render_events_json(events_data)
    render_json_with_wrapper(events_data, wrapper_key: :post_events)
  end
end

# frozen_string_literal: true

module IqdbProxy
  class Error < StandardError; end
  class BusyError < Error; end

  IQDB_NUM_PIXELS = 128

  module_function

  def endpoint
    Danbooru.config.iqdb_server
  end

  def enabled?
    endpoint.present?
  end

  def make_request(path, request_type, body = nil)
    opts = Danbooru.config.faraday_options.deep_merge(request: { timeout: Danbooru.config.iqdb_read_timeout })
    conn = Faraday.new(opts)
    conn.send(request_type, endpoint + path, body&.to_json, { content_type: "application/json" })
  rescue Faraday::Error
    raise Error, "This service is temporarily unavailable. Please try again later."
  end

  def update_post(post)
    return unless post.has_preview?

    thumb = generate_thumbnail(post.preview_file_path)
    raise Error, "failed to generate thumb for #{post.id}" unless thumb

    response = make_request("/images/#{post.id}", :post, get_channels_data(thumb))
    raise Error, "iqdb request failed" if response.status != 200
  end

  def remove_post(post_id)
    response = make_request("/images/#{post_id}", :delete)
    raise Error, "iqdb request failed" if response.status != 200
  end

  def query_url(image_url, score_cutoff, v2_format: false)
    file, _strategy = Downloads::File.new(image_url).download!
    query_file(file, score_cutoff, v2_format: v2_format)
  end

  def query_post(post, score_cutoff, v2_format: false)
    return [] unless post&.has_preview?

    File.open(post.preview_file_path) do |f|
      query_file(f, score_cutoff, v2_format: v2_format)
    end
  rescue Errno::ENOENT # Preview file not found
    []
  end

  def query_file(file, score_cutoff, v2_format: false)
    with_query_semaphore do
      thumb = generate_thumbnail(file.path)
      return [] unless thumb

      response = make_request("/query", :post, get_channels_data(thumb))
      return [] if response.status != 200

      process_iqdb_result(JSON.parse(response.body), score_cutoff, v2_format: v2_format)
    end
  end

  def query_hash(hash, score_cutoff, v2_format: false)
    with_query_semaphore do
      response = make_request "/query", :post, { hash: hash }
      return [] if response.status != 200

      process_iqdb_result(JSON.parse(response.body), score_cutoff, v2_format: v2_format)
    end
  end

  def process_iqdb_result(json, score_cutoff, v2_format: false)
    raise Error, "Server returned an error. Most likely the url is not found." unless json.is_a?(Array)

    json.filter! { |entry| (entry["score"] || 0) >= (score_cutoff.presence || 60).to_i }

    post_ids = json.pluck("post_id").compact
    posts = Post.where(id: post_ids).includes(:uploader).index_by(&:id)
    Post.preload_stats!(posts.values)

    json.map do |x|
      post = posts[x["post_id"]]
      next if post.blank? # Skip deleted or missing posts
      x["post"] = v2_format ? PostBlueprint.render_as_hash(post, view: :basic) : post
      x
    end.compact
  end

  def generate_thumbnail(file_path)
    Vips::Image.thumbnail(file_path, IQDB_NUM_PIXELS, height: IQDB_NUM_PIXELS, size: :force)
  rescue Vips::Error => e
    Rails.logger.error "Failed to generate thumbnail for #{file_path}: #{e.message}"
    nil
  end

  def get_channels_data(thumbnail)
    r = []
    g = []
    b = []
    is_grayscale = thumbnail.bands == 1
    thumbnail.to_a.each do |data|
      data.each do |rgb|
        r << rgb[0]
        g << (is_grayscale ? rgb[0] : rgb[1])
        b << (is_grayscale ? rgb[0] : rgb[2])
      end
    end
    { channels: { r: r, g: g, b: b } }
  end

  def redis_key
    ["iqdb:concurrent", Danbooru.config.server_name].compact.join(":")
  end

  # Atomically decrements the key but floors it at zero.
  # Prevents the counter from going negative when a reset races with an in-flight request.
  DECR_FLOOR_ZERO = <<~LUA
    local v = redis.call('decr', KEYS[1])
    if v < 0 then redis.call('set', KEYS[1], '0') end
    return v
  LUA

  def with_query_semaphore
    count = Cache.redis.incr(redis_key)
    if count > Danbooru.config.iqdb_max_concurrent_queries
      Cache.redis.eval(DECR_FLOOR_ZERO, keys: [redis_key])
      raise BusyError, "IQDB is temporarily busy. Please try again later."
    end
    begin
      yield
    ensure
      Cache.redis.eval(DECR_FLOOR_ZERO, keys: [redis_key])
    end
  end
  private_class_method :with_query_semaphore
end

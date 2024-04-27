# frozen_string_literal: true

module IqdbProxy
  class Error < StandardError; end

  IQDB_NUM_PIXELS = 128

  module_function

  def endpoint
    Danbooru.config.iqdb_server
  end

  def enabled?
    endpoint.present?
  end

  def make_request(path, request_type, params = {})
    conn = Faraday.new(Danbooru.config.faraday_options)
    conn.send(request_type, endpoint + path, params.to_json, { content_type: "application/json" })
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

  def query_url(image_url, score_cutoff)
    file, _strategy = Downloads::File.new(image_url).download!
    query_file(file, score_cutoff)
  end

  def query_post(post, score_cutoff)
    return [] unless post&.has_preview?

    File.open(post.preview_file_path) do |f|
      query_file(f, score_cutoff)
    end
  end

  def query_file(file, score_cutoff)
    thumb = generate_thumbnail(file.path)
    return [] unless thumb

    response = make_request("/query", :post, get_channels_data(thumb))
    return [] if response.status != 200

    process_iqdb_result(JSON.parse(response.body), score_cutoff)
  end

  def query_hash(hash, score_cutoff)
    response = make_request "/query", :post, { hash: hash }
    return [] if response.status != 200

    process_iqdb_result(JSON.parse(response.body), score_cutoff)
  end

  def process_iqdb_result(json, score_cutoff)
    raise Error, "Server returned an error. Most likely the url is not found." unless json.is_a?(Array)

    json.filter! { |entry| (entry["score"] || 0) >= (score_cutoff.presence || 60).to_i }
    json.map do |x|
      x["post"] = Post.find(x["post_id"])
      x
    rescue ActiveRecord::RecordNotFound
      nil
    end.compact
  end

  def generate_thumbnail(file_path)
    Vips::Image.thumbnail(file_path, IQDB_NUM_PIXELS, height: IQDB_NUM_PIXELS, size: :force)
  rescue Vips::Error
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
end

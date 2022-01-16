class IqdbProxy
  class Error < ::Exception; end

  IQDB_NUM_PIXELS = 128

  def self.make_request(path, request_type, params = {})
    url = URI.parse(Danbooru.config.iqdb_server)
    url.path = path
    HTTParty.send request_type, url, { body: params }
  end

  def self.update_post(post)
    File.open(post.preview_file_path)  do |f|
      make_request "/images/#{post.id}", :post, get_channels_data(f)
    end
  end

  def self.remove_post(post_id)
    make_request "/images/#{post_id}", :delete
  end

  def self.query_url(image_url)
    file, _strategy = Downloads::File.new(image_url).download!
    query_file(file)
  end

  def self.query_path(image_path)
    File.open(image_path) do |f|
      query_file(f)
    end
  end

  def self.query_file(image)
    response = make_request "/query", :post, get_channels_data(image)
    return [] if response.code != 200

    process_iqdb_result(response.parsed_response)
  end

  def self.get_channels_data(file)
    begin
      thumbnail = DanbooruImageResizer.thumbnail(file, IQDB_NUM_PIXELS, IQDB_NUM_PIXELS, DanbooruImageResizer::THUMBNAIL_OPTIONS.merge(size: :force))
    rescue Vips::Error
      raise Error, "Unsupported file"
    end
    r = []
    g = []
    b = []
    thumbnail.to_a.each do |data|
      data.each do |rgb|
        r << rgb[0]
        g << rgb[1]
        b << rgb[2]
      end
    end
    { channels: { r: r, g: g, b: b } }.to_json
  end

  def self.process_iqdb_result(json, score_cutoff = 80)
    raise Error, "Server returned an error. Most likely the url is not found." unless json.is_a?(Array)
    json.filter! { |entry| entry["score"] >= score_cutoff }
    post_ids = json.pluck("post_id")
    posts = Post.where(id: post_ids).index_by(&:id)

    json.filter_map do |entry|
      entry["post"] = posts[entry["post_id"]]
      entry if entry["post"]
    end
  end
end

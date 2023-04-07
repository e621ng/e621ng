class IqdbProxy
  class Error < StandardError; end

  def self.query(image_url)
    response = make_request(url: image_url)
    decorate_posts(response)
  end

  def self.query_file(image)
    response = make_request(file: image)
    decorate_posts(response)
  end

  def self.query_path(image_path)
    File.open(image_path) do |f|
      query_file(f)
    end
  end

  def self.decorate_posts(json)
    raise Error, "Server returned an error. Most likely the url is not found." unless json.is_a?(Array)
    json.map do |x|
      x["post"] = Post.find(x["post_id"])
      x
    rescue ActiveRecord::RecordNotFound
      nil
    end.compact
  end

  def self.make_request(**params)
    raise NotImplementedError if Danbooru.config.iqdbs_server.blank?

    url = URI.parse(Danbooru.config.iqdbs_server)
    url.path = "/similar"

    json = HTTParty.post(url.to_s, { body: params }.merge(Danbooru.config.httparty_options))
    return {} if json.code != 200

    json.parsed_response
  end
end

class IqdbProxy
  class Error < ::Exception; end
  def self.query(image_url)
    raise NotImplementedError unless Danbooru.config.iqdbs_server.present?

    url = URI.parse(Danbooru.config.iqdbs_server)
    url.path = "/similar"
    url.query = {url: image_url}.to_query
    json = HTTParty.get(url.to_s, Danbooru.config.httparty_options)
    return [] if json.code != 200
    decorate_posts(json.parsed_response)
  end

  def self.query_file(image)
    raise NotImplementedError unless Danbooru.config.iqdbs_server.present?

    url = URI.parse(Danbooru.config.iqdbs_server)
    url.path = "/similar"
    json = HTTParty.post(url.to_s, body: {
        file: image
    }.merge(Danbooru.config.httparty_options))
    return [] if json.code != 200
    decorate_posts(json.parsed_response)
  end

  def self.query_path(image_path)
    raise NotImplementedError unless Danbooru.config.iqdbs_server.present?

    f = File.open(image_path)
    url = URI.parse(Danbooru.config.iqdbs_server)
    url.path = "/similar"
    json = HTTParty.post(url.to_s, body: {
        file: f
    }.merge(Danbooru.config.httparty_options))
    f.close
    return [] if json.code != 200
    decorate_posts(json.parsed_response)
  end

  def self.decorate_posts(json)
    raise Error.new("Server returned an error. Most likely the url is not found.") unless json.kind_of?(Array)
    json.map do |x|
      begin
        x["post"] = Post.find(x["post_id"])
        x
      rescue ActiveRecord::RecordNotFound
        nil
      end
    end.compact
  end
end

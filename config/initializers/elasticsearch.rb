Elasticsearch::Model.client = Elasticsearch::Client.new host: Danbooru.config.elasticsearch_host
Rails.configuration.to_prepare do
  Elasticsearch::Model::Response::Response.include(Danbooru::Paginator::ElasticsearchExtensions)
end

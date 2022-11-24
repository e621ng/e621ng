Rails.configuration.to_prepare do
  Elasticsearch::Model::Response::Response.__send__ :include, Danbooru::Paginator::ElasticsearchExtensions
end

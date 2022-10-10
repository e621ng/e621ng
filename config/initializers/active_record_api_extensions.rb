Rails.configuration.after_initialize do
  Elasticsearch::Model::Response::Response.__send__ :include, Danbooru::Paginator::ElasticsearchExtensions
end

# class Delayed::Job
#   def hidden_attributes
#     [:handler]
#   end
# end

Elasticsearch::Model::Response::Response.__send__ :include, Danbooru::Paginator::ElasticsearchExtensions

# frozen_string_literal: true

module DocumentStore
  class ClassMethodProxy
    delegate_missing_to :@target
    attr_accessor :index, :index_name

    def initialize(target)
      @target = target
    end

    def search(body)
      search = SearchRequest.new({ index: index_name, body: body }, client)
      Response.new(@target, search)
    end

    def create_index!(delete_existing: false)
      exists = index_exist?
      return if exists && !delete_existing

      delete_index! if exists && delete_existing

      client.indices.create(index: index_name, body: index)
    end

    def delete_index!
      client.indices.delete(index: index_name, ignore: 404)
    end

    def index_exist?
      client.indices.exists(index: index_name)
    end

    def refresh_index!
      client.indices.refresh(index: index_name)
    end

    def delete_by_query(query:, body:)
      client.delete_by_query(index: index_name, q: query, body: body)
    end

    def client
      DocumentStore.client
    end
  end
end

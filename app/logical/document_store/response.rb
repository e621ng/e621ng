module DocumentStore
  class Response
    include Danbooru::Paginator::DocumentStoreExtensions

    delegate_missing_to :records
    attr_reader :klass, :search

    def initialize(klass, search)
      @klass = klass
      @search = search
    end

    def response
      @response ||= @search.execute!
    end

    def hits
      response["hits"]["hits"]
    end

    def relation
      klass.where(id: hits.pluck("_id"))
    end

    def records(includes: nil)
      @records ||= begin
        sql_records = relation
        sql_records = sql_records.includes(includes) if includes
        sql_records.records.sort_by { |sql_record| hits.index { |hit| hit["_id"] == sql_record.id.to_s } }
      end
    end
  end
end

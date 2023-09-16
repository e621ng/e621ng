module DocumentStore
  class SearchRequest
    attr_reader :definition

    def initialize(definition, client)
      @definition = definition
      @client = client
    end

    def execute!
      @client.search(@definition)
    end
  end
end

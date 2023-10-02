module DocumentStore
  class InstanceMethodProxy
    delegate :client, :index_name, to: :class_document_store
    delegate_missing_to :@target

    def initialize(target)
      @target = target
    end

    def update_index(refresh: "false")
      client.index(index: index_name, id: id, body: as_indexed_json, refresh: refresh)
    end

    def delete_document(refresh: "false")
      client.delete(index: index_name, id: id, refresh: refresh)
    end

    private

    def class_document_store
      @target.class.document_store
    end
  end
end

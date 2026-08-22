# frozen_string_literal: true

module DocumentStore
  class InstanceMethodProxy
    delegate :client, :index_name, to: :class_document_store
    delegate_missing_to :@target

    def initialize(target)
      @target = target
    end

    def update_index(refresh: "false")
      params = { index: index_name, id: id, body: as_indexed_json, refresh: refresh }

      # Optimistic concurrency control.
      # Any indexer that reads a record and writes the document some time later can otherwise
      # clobber a fresher document with the stale snapshot it read. Tagging the write with
      # the record's own version makes OpenSearch reject it (409) instead.
      if (version = index_version)
        params[:version] = version
        params[:version_type] = "external_gte"
        params[:ignore] = 409
      end

      client.index(**params)
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

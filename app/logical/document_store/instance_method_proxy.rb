# frozen_string_literal: true

module DocumentStore
  class VersionConflictError < StandardError; end

  class InstanceMethodProxy
    # A write that still conflicts after refreshing the version means something is
    # actively racing ahead of us; give up loudly instead of looping.
    MAX_CONFLICT_RETRIES = 2

    delegate :client, :index_name, to: :class_document_store
    delegate_missing_to :@target

    def initialize(target)
      @target = target
    end

    def update_index(refresh: "false")
      version = index_version
      body = as_indexed_json
      return client.index(index: index_name, id: id, body: body, refresh: refresh) if version.nil?

      # Optimistic concurrency control.
      # Any indexer that reads a record and writes the document some time later can otherwise
      # clobber a fresher document with the stale snapshot it read. Tagging the write with
      # the record's own version makes OpenSearch reject it (409) instead.
      (MAX_CONFLICT_RETRIES + 1).times do
        response = client.index(index: index_name, id: id, body: body, refresh: refresh,
                                version: version, version_type: "external_gte", ignore: 409)
        return response unless conflict?(response)

        # The document is ahead of the record, typically after an unstamped write bumped
        # its version. The content being written here is fresher than whatever is indexed,
        # so retry at the document's own version (external_gte accepts equal) rather than
        # dropping the update.
        version = [version, current_document_version].compact.max
        @target.reload
        body = as_indexed_json
        version = [version, index_version].compact.max
        Rails.logger.warn("[DocumentStore] version conflict indexing #{index_name}/#{id}: retrying at version #{version}")
      end

      raise VersionConflictError, "#{index_name}/#{id} still conflicts after #{MAX_CONFLICT_RETRIES} retries at version #{version}"
    end

    def delete_document(refresh: "false")
      client.delete(index: index_name, id: id, refresh: refresh)
    end

    private

    def conflict?(response)
      response.is_a?(Hash) && response["status"] == 409
    end

    def current_document_version
      response = client.get(index: index_name, id: id, _source: false, ignore: 404)
      response["_version"] if response.is_a?(Hash)
    end

    def class_document_store
      @target.class.document_store
    end
  end
end

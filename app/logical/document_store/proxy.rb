# frozen_string_literal: true

module DocumentStore
  module Proxy
    def self.included(base)
      base.class_eval do
        def self.document_store
          @document_store ||= ClassMethodProxy.new(self)
        end

        def document_store
          @document_store ||= InstanceMethodProxy.new(self)
        end
      end
    end
  end
end

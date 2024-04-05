# frozen_string_literal: true

class ApplicationDecorator < Draper::Decorator
  # NOTE: This is required for correct serialization of member models, otherwise hidden_attributes is ignored!!!
  delegate :as_json, :serializable_hash
end

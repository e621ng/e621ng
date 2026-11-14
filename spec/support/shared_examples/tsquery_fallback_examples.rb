# frozen_string_literal: true

# Shared examples for full-text search params that go through
# ApplicationRecord.tsquery_matches. Postgres rejects queries with no lexemes
# (stopwords, punctuation, emoji), so these should fall back to a substring match.
#
# Usage:
#
#   it_behaves_like "tsquery fallback search", :body_matches, :body
#   it_behaves_like "tsquery fallback search", :reason_matches, :reason, factory: :deletion_post_flag
#   it_behaves_like "tsquery fallback search", :body_matches, :body, build: ->(text) { make_note(body: text) }
#   it_behaves_like "tsquery fallback search", :body_matches, :body, extra_params: { advanced_search: true }
#
# `build` is run in the example's scope, so it can use the spec's helpers.

RSpec.shared_examples "tsquery fallback search" do |param, attribute, factory: nil, build: nil, extra_params: {}|
  describe "#{param} with a query that has no lexemes#{" (#{extra_params.keys.join(', ')})" if extra_params.present?}" do
    def make_tsquery_record(text, attribute, factory, build)
      return instance_exec(text, &build) if build

      create(factory || described_class.model_name.singular.to_sym, attribute => text)
    end

    let!(:tsquery_match) { make_tsquery_record("made it myself >_< 😀", attribute, factory, build) }
    let!(:tsquery_miss)  { make_tsquery_record("nothing relevant here", attribute, factory, build) }

    { "only stopwords" => "myself", "only punctuation" => ">_<", "only emoji" => "😀" }.each do |label, query|
      it "falls back to a substring match for #{label}" do
        result = described_class.search({ param => query, **extra_params })
        expect(result).to include(tsquery_match)
        expect(result).not_to include(tsquery_miss)
      end
    end
  end
end

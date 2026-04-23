# frozen_string_literal: true

require "English"
require "rails_helper"

#            Prefix Verb URI Pattern                       Controller#Action
# diff_pool_version GET  /pool_versions/:id/diff(.:format) pool_versions#diff
#     pool_versions GET  /pool_versions(.:format)          pool_versions#index
RSpec.describe PoolVersionsController do
  let(:user) { create(:user) }
  let(:posts) { create_list(:post, 4) }

  describe "#index" do
    let!(:pool) { CurrentUser.scoped(user) { create(:pool) } }
    let(:user2) { create(:user) }
    let(:versions) { pool.versions }

    before do
      CurrentUser.scoped(user2, "1.2.3.4") { pool.update(post_ids: [posts[0].id, posts[1].id]) }

      CurrentUser.scoped(create(:user), "5.6.7.8") do
        pool.update(post_ids: [posts[0].id, posts[1].id, posts[2].id, posts[3].id])
      end

      CurrentUser.scoped(user2, "1.2.3.4") { pool.update(description: "this is the final change") }
    end

    # Renders the index path w/ JSON & HTML, and checks that the items rendered & not rendered are
    # as expected
    # TODO: Make a generic helper for all indexes/searches
    def render_given_versions(*versions, excluded_versions: [], params: nil)
      make_session(user)
      get pool_versions_path(params: params, format: :json)
      begin
        expect(response).to have_http_status(:success)
        expect(response.parsed_body.pluck("id")).to match_array(versions.pluck(:id))
        if excluded_versions.present?
          expect(response.parsed_body.pluck("id")).not_to include(*excluded_versions.pluck(:id))
        end

        get_auth pool_versions_path, user, params: params
        expect(response).to have_http_status(:success)
        versions.each { |p| assert_select "#pool-version-#{p.id}", true }
        if excluded_versions.present?
          excluded_versions.each { |p| assert_select "#pool-version-#{p.id}", false }
        end
      rescue RSpec::Expectations::ExpectationNotMetError => e
        raise RSpec::Expectations::ExpectationNotMetError, "#{e.message}\n\tParams: #{params.inspect}\n\tbody: #{response.parsed_body}", e.backtrace, cause: nil
      end
    end

    it "list all versions" do # rubocop:disable RSpec/NoExpectationExample
      render_given_versions(*versions)
    end

    it "list all versions that match the search criteria" do # rubocop:disable RSpec/NoExpectationExample
      render_given_versions(versions[1], versions[3], excluded_versions: [versions[0], versions[2]], params: { search: { updater_id: user2.id } })
    end
  end
end

# frozen_string_literal: true

require "rails_helper"

#             Prefix Verb   URI Pattern                        Controller#Action
# regenerate_api_key POST   /api_keys/:id/regenerate(.:format) api_keys#regenerate
#           api_keys GET    /api_keys(.:format)                api_keys#index
#                    POST   /api_keys(.:format)                api_keys#create
#        new_api_key GET    /api_keys/new(.:format)            api_keys#new
#            api_key GET    /api_keys/:id(.:format)            api_keys#show
#                    DELETE /api_keys/:id(.:format)            api_keys#destroy
RSpec.describe ApiKeysController do
  describe "Every route" do
    it "denies access to non-members" do
      CurrentUser.scoped(User.anonymous) do
        # NOTE: Doesn't test `api_key_path(id: 0)`; 404 before redirect
        [api_keys_path, new_api_key_path].each do |p|
          get p
          expect(response).to have_http_status(:redirect), "expected the response for #{p} to have a redirect status code (3xx) but it was #{response.status}"
          expect(response).to redirect_to(new_session_path(url: p))
        end
      end
    end

    it "denies access when using an API key" do
      api_user = create(:user, name: "apiUser")
      k = create(:api_key, user: api_user)
      CurrentUser.scoped(User.anonymous) do
        # NOTE: Doesn't test `api_key_path(id: k.id)` or `regenerate_api_key_path(k.id)`; 404 before redirect
        [api_keys_path, new_api_key_path].each do |p|
          get p, params: { login: api_user.name, api_key: k.key }
          expect(response).to have_http_status(:forbidden), "expected the response from #{p} to have status code :forbidden (403) but it was #{response.status}"
        end
      end
    end

    it "requires reauthentication if last authenticated over an hour ago" do
      api_user = travel_to 2.hours.ago, &method(:make_session) # do
      CurrentUser.scoped(api_user) do
        # NOTE: Doesn't test `api_key_path(id: k.id)` or `regenerate_api_key_path(k.id)`; 404 before redirect
        [new_api_key_path, api_keys_path].each do |p|
          get p
          expect(response).to have_http_status(:redirect), -"expected the response for #{p} to have a redirect status code (3xx) but it was #{response.status}"
          expect(response).to redirect_to(confirm_password_session_path(url: p))
        end
      end
    end
  end

  # api_keys | GET | /api_keys(.:format) | api_keys#index
  describe "GET /api_keys" do
    include_context "validating JSON"

    it "loads correctly with HTML" do
      def run_expectations
        get api_keys_path
        expect(response).to have_http_status(:success)
      end
      user = make_session
      run_expectations
      create(:api_key, user: user)
      run_expectations
    end

    it "loads correctly with JSON" do
      user = make_session
      create(:api_key, user: user)
      get api_keys_path(format: :json)
      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to match_json_format(
        {
          id: Integer,
          created_at: DateTime,
          updated_at: DateTime,
          user_id: Integer,
          key: String,
          name: String,
          last_used_at: DateTime,
          last_ip_address: IPAddr,
          last_user_agent: String,
          expires_at: DateTime,
          notified_at: DateTime,
        },
        %i[last_used_at last_ip_address last_user_agent expires_at notified_at],
        root_type: Array,
      )
    end
  end

  # new_api_key | GET | /api_keys/new(.:format) | api_keys#new
  describe "GET /api_keys/new" do
    it "loads correctly" do
      get_auth(new_api_key_path, create(:user))
      expect(response).to have_http_status(:success)
    end

    it "has inputs for all the required parameters" do
      get_auth(new_api_key_path, create(:user))
      # TODO: Move this to a view spec (https://rspec.info/features/8-0/rspec-rails/view-specs/view-spec/)
      expect(response.body).to include("name=\"api_key[name]\"")
      expect(response.body).to include("name=\"api_key[duration]\"")
      expect(response.body).to include("name=\"api_key[expires_at]\"")
    end
  end

  # api_key | GET | /api_keys/:id(.:format) | api_keys#show
  # TODO: This actually doesn't have an action in the controller, but is assigned a route in `../../config/routes.rb`; errors out with 404 currently.
  describe "GET /api_keys/:id", skip: "has no action" do
    def do_it(**path_params)
      user = make_session(user)
      api_key = create(:api_key, user: user, name: "A horse with no name")
      get api_key_path(api_key.id, **path_params)
      expect(response).to have_http_status(:success)
    end

    it "loads correctly with HTML" do
      do_it
      expect(response.body).to include("A horse with no name")
    end

    it "loads correctly with JSON" do
      do_it(format: :json)
      expect(response.parsed_body).to include(:user_id, :key, :expires_at)
    end
  end

  # api_keys | POST | /api_keys(.:format) | api_keys#create
  describe "POST /api_keys" do
    let!(:user) { make_session }

    def do_with_success(api_key_param)
      expect do
        post api_keys_path(api_key: api_key_param)
        expect(response).to have_http_status(:found)
        expect(response).to redirect_to(api_keys_path)
      end.to change(ApiKey, :count).by(1)
      relation = user.api_keys.active
      expect(relation.count).to be(1)
      relation
    end

    def do_with_failure(api_key_param)
      expect do
        post api_keys_path(api_key: api_key_param)
        expect(response).to have_http_status(:success)
      end.not_to change(ApiKey, :count)
    end

    it "creates a new API key active for the given number of days" do
      freeze_time do
        relation = do_with_success({ name: "TestKey", expires_at: "Shouldn't be used", duration: 14 })
        expect(relation.first.expires_at).to match(Time.now.advance(days: 14))
      end
    end

    it "creates a new API key active until the given time" do
      freeze_time do
        relation = do_with_success({ name: "TestKey", expires_at: Time.now.advance(days: 14), duration: "custom" })
        expect(relation.first.expires_at).to match(Time.now.advance(days: 14))
      end
    end

    it "creates a new API key that never expires" do
      freeze_time do
        relation = do_with_success({ name: "TestKey", expires_at: "Shouldn't be used", duration: "never" })
        expect(relation.first.expires_at).to be_nil
      end
    end

    it "coerces the duration to the number of days until expiration" do
      freeze_time do
        relation = do_with_success({ name: "TestKey", expires_at: "Shouldn't be used", duration: "1 more time" })
        expect(relation.first.expires_at).to match(Time.now.advance(days: 1))
      end
    end

    it "fails with duplicate name for same user" do
      post api_keys_path(api_key: { name: "test_key" })
      do_with_failure({ name: "test_key" })
      expect(response.body).to match(/Name has already been taken/)
    end

    it "fails with empty name" do
      do_with_failure({ name: "" })
      expect(response.body).to match(/Name can&#39;t be blank/)
    end

    it "fails when API key limit is reached" do
      # Create keys up to the limit
      limit = user.api_key_limit
      limit.times { |i| create(:api_key, user: user, name: "key_#{i}") }

      expect(user.api_keys.count).to eq(limit)

      # Try to create one more - should fail
      do_with_failure({ name: "over_limit_key" })
      expect(response.body).to match(/API key limit reached/)
    end
  end

  # regenerate_api_key | POST | /api_keys/:id/regenerate(.:format) | api_keys#regenerate
  describe "POST /api_keys/:id/regenerate" do
    let(:user) { make_session }

    it "regenerates an expired API key" do
      expired_api_key = create(:api_key, user: user, name: "expired_key")
      expired_api_key.update_columns(created_at: 2.days.ago, expires_at: 1.day.ago) # skip validation
      old_key = expired_api_key.key
      post regenerate_api_key_path(expired_api_key)

      expired_api_key.reload
      expect(expired_api_key.key).not_to eq(old_key)
      expect(expired_api_key.expires_at).to be > Time.current
      expect(response).to redirect_to(api_keys_path)
      expect(flash[:notice]).to eq("API key regenerated")
    end

    it "doesn't allow regenerating an active API key" do
      active_api_key = create(:api_key, user: user, name: "active_key", expires_at: 1.day.from_now)
      old_key = active_api_key.key
      post regenerate_api_key_path(active_api_key)

      active_api_key.reload
      expect(active_api_key.key).to eq(old_key)
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  # api_key | DELETE | /api_keys/:id(.:format) | api_keys#destroy
  describe "DELETE /api_keys/:id" do
    let(:user) { create(:user) }
    let!(:api_key) { create(:api_key, user: user, name: "test_key") }

    it "deletes the user's API key" do
      expect { delete_auth(api_key_path(api_key), user) }.to change(ApiKey, :count).by(-1)

      expect(response).to redirect_to(api_keys_path)
      expect { api_key.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "doesn't allow deleting another user's API key" do
      expect { delete_auth(api_key_path(api_key), create(:user)) }.not_to change(ApiKey, :count)

      expect(response).to have_http_status(:not_found)
      expect(api_key.reload).not_to be_nil
    end
  end
end

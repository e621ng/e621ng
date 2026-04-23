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
  # def make_session(user = nil, password = "hexerade", remember: true)
  #   user = create(:user, password: password) if user.blank?
  #   unless user.is_a?(String)
  #     ret = user
  #     password = user.password.presence || password
  #     user = user.name
  #   end
  #   post session_path(session: { name: user, password: password, remember: remember })
  #   expect(response).to have_http_status(:found)
  #   ret || user
  # end

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
      #   api_user = create(:user, name: "apiUser")
      #   post "/session?session%5Bname%5D=apiUser&session%5Bpassword%5D=hexerade&session%5Bremember%5D=true"
      #   expect(response).to have_http_status(:found)
      #   api_user
      # end
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
    let(:json_format) do
      {
        id: Numeric,
        created_at: Date,
        updated_at: Date,
        user_id: Numeric,
        key: String,
        name: String,
        last_used_at: Date,
        last_ip_address: IPAddr,
        last_user_agent: String,
        expires_at: Date,
        notified_at: Date,
      }.freeze
    end

    let(:nullable_keys) do
      %i[last_used_at last_ip_address last_user_agent expires_at notified_at].freeze
    end

    it "loads correctly with HTML" do
      def run_expectations
        get api_keys_path
        expect(response).to have_http_status(:success)
        # expect(response).to render_template("api_keys/index")
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
      expect(response.parsed_body).to match_json_format
    end
  end

  # new_api_key | GET | /api_keys/new(.:format) | api_keys#new
  describe "GET /api_keys/new" do
    def send_request(**)
      make_session
      get new_api_key_path(**)
    end

    it "loads correctly" do
      send_request
      expect(response).to have_http_status(:success)
      # expect(response).to render_template("api_keys/new")
    end

    it "has inputs for all the required parameters" do
      send_request
      # TODO: Move this to a view spec (https://rspec.info/features/8-0/rspec-rails/view-specs/view-spec/)
      expect(response.body).to include("name=\"api_key[name]\"")
      expect(response.body).to include("name=\"api_key[duration]\"")
      expect(response.body).to include("name=\"api_key[expires_at]\"")
    end
  end

  # api_key | GET | /api_keys/:id(.:format) | api_keys#show
  # TODO: This actually doesn't have an action in the controller, but is assigned a route in `../../config/routes.rb`; errors out with 404 currently.
  describe "GET /api_keys/:id" do
    def do_it(**path_params)
      user = make_session(user)
      api_key = create(:api_key, user: user, name: "A horse with no name")
      get api_key_path(api_key.id, **path_params)
      expect(response).to have_http_status(:success)
    end

    it "loads correctly with HTML", skip: "has no action" do
      do_it
      # expect(response).to render_template("api_keys/new")
      expect(response.body).to include("A horse with no name")
    end

    it "loads correctly with JSON", skip: "has no action" do
      do_it(format: :json)
      expect(response.parsed_body).to include(:user_id, :key, :expires_at)
    end
  end

  # api_keys | POST | /api_keys(.:format) | api_keys#create
  describe "POST /api_keys" do
    it "creates a new API key active for the given number of days" do
      user = make_session
      freeze_time do
        post api_keys_path(api_key: { name: "TestKey", expires_at: "Shouldn't be used", duration: 14 })
        expect(response).to have_http_status(:found)
        expect(response).to redirect_to(api_keys_path)
        relation = user.api_keys.active
        expect(relation.count).to be(1)
        expect(relation.first.expires_at).to match(Time.now.advance(days: 14))
      end
    end

    it "creates a new API key active until the given time" do
      user = make_session
      freeze_time do
        CurrentUser.scoped(user) do
          post api_keys_path(api_key: { name: "TestKey", expires_at: Time.now.advance(days: 14), duration: "custom" })
        end
        expect(response).to have_http_status(:found)
        expect(response).to redirect_to(api_keys_path)
        relation = user.api_keys.active
        expect(relation.count).to be(1)
        expect(relation.first.expires_at).to match(Time.now.advance(days: 14))
      end
    end

    it "creates a new API key that never expires" do
      user = make_session
      freeze_time do
        CurrentUser.scoped(user) do
          post api_keys_path(api_key: { name: "TestKey", expires_at: "Shouldn't be used", duration: "never" })
        end
        expect(response).to have_http_status(:found)
        expect(response).to redirect_to(api_keys_path)
        relation = user.api_keys.active
        expect(relation.count).to be(1)
        expect(relation.first.expires_at).to be_nil
      end
    end

    it "coerces the duration to the number of days until expiration" do
      user = make_session
      freeze_time do
        CurrentUser.scoped(user) do
          post api_keys_path(api_key: { name: "TestKey", expires_at: "Shouldn't be used", duration: "1 more time" })
        end
        expect(response).to have_http_status(:found)
        expect(response).to redirect_to(api_keys_path)
        relation = user.api_keys.active
        expect(relation.count).to be(1)
        expect(relation.first.expires_at).to match(Time.now.advance(days: 1))
      end
    end
  end

  # TODO: regenerate_api_key | POST | /api_keys/:id/regenerate(.:format) | api_keys#regenerate
  # TODO: api_key | DELETE | /api_keys/:id(.:format) | api_keys#destroy
end

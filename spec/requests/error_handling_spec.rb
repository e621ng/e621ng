# frozen_string_literal: true

require "rails_helper"

# How ApplicationController#rescue_exception maps exceptions raised inside an action to responses.
RSpec.describe ApplicationController do
  include_context "as admin"

  let(:member) { create(:user) }
  let(:admin)  { create(:admin_user) }

  def raise_in_action(exception)
    allow_any_instance_of(TagsController).to receive(:index).and_raise(exception) # rubocop:disable RSpec/AnyInstance
  end

  def json_error
    get tags_path(format: :json)
    response.parsed_body
  end

  describe "expected errors" do
    {
      "a ProcessingError" => [ProcessingError.new("could not process"), 400, "could not process"],
      "a missing parameter" => [ActionController::ParameterMissing.new(:tag), 400, /param is missing/],
      "an invalid password hash" => [BCrypt::Errors::InvalidHash.new("invalid hash"), 400, "You must reset your password."],
      "an unavailable feature" => [ApplicationController::FeatureUnavailable.new, 400, "This feature isn't available"],
      "an invalid CSRF token" => [ActionController::InvalidAuthenticityToken.new, 403, /InvalidAuthenticityToken/],
      "a regexp timeout" => [Regexp::TimeoutError.new("regexp match timeout"), 422, "Your query was too complex to process. Try simplifying it."],
      "an over-long tag query" => [TagQuery::CountExceededError.new, 422, /./],
      "an API throttle" => [ApplicationController::APIThrottled.new, 429, "Throttled: Too many requests"],
    }.each do |name, (exception, status, message)|
      it "renders #{status} for #{name}" do
        raise_in_action(exception)
        body = json_error
        expect(response).to have_http_status(status)
        expect(body["message"]).to match(message)
      end

      it "does not log #{name}" do
        raise_in_action(exception)
        expect { get tags_path(format: :json) }.not_to change(ExceptionLog, :count)
      end
    end

    it "renders the HTML error page for a browser" do
      raise_in_action(ProcessingError.new("could not process"))
      get tags_path
      expect(response).to have_http_status(:bad_request)
      expect(response.body).to include("could not process")
    end
  end

  describe "OAuth bearer failures" do
    it "renders 401 with an insufficient_scope challenge" do
      raise_in_action(SessionLoader::InsufficientScope.new)
      body = json_error
      expect(response).to have_http_status(:unauthorized)
      expect(response.headers["WWW-Authenticate"]).to eq(%(Bearer error="insufficient_scope", scope="full"))
      expect(body["message"]).to eq("Insufficient scope")
    end

    it "renders 401 with an invalid_token challenge when the user is below the application minimum" do
      raise_in_action(SessionLoader::LevelBelowMinimum.new)
      body = json_error
      expect(response).to have_http_status(:unauthorized)
      expect(response.headers["WWW-Authenticate"]).to include(%(error="invalid_token"))
      expect(body["message"]).to eq("Account level below application minimum")
    end
  end

  describe "database failures" do
    it "renders 500 with a timeout message and logs the exception" do
      raise_in_action(ActiveRecord::QueryCanceled.new("PG::QueryCanceled: canceling statement due to statement timeout"))
      expect { get tags_path(format: :json) }.to change(ExceptionLog, :count).by(1)
      expect(response).to have_http_status(:internal_server_error)
      expect(response.parsed_body["message"]).to eq("The database timed out running your query.")
    end

    it "renders 503 when the database is unavailable" do
      raise_in_action(PG::ConnectionBad.new("connection refused"))
      expect { get tags_path(format: :json) }.to change(ExceptionLog, :count).by(1)
      expect(response).to have_http_status(:service_unavailable)
      expect(response.parsed_body["message"]).to eq("The database is unavailable. Try again later.")
    end
  end

  describe "unexpected errors" do
    before { raise_in_action(RuntimeError.new("secret internal detail")) }

    it "renders 500 and logs the exception" do
      expect { get tags_path(format: :json) }.to change(ExceptionLog, :count).by(1)
      expect(response).to have_http_status(:internal_server_error)
    end

    it "hides the exception message from a member" do
      sign_in_as member
      expect(json_error["message"]).to eq("An unexpected error occurred.")
      expect(response.body).not_to include("secret internal detail")
    end

    it "hides the exception message from anonymous" do
      expect(json_error["message"]).to eq("An unexpected error occurred.")
    end

    it "shows the exception message to staff" do
      sign_in_as admin
      expect(json_error["message"]).to eq("secret internal detail")
    end
  end

  describe "routing errors" do
    it "renders 405 without logging" do
      raise_in_action(ActionController::RoutingError.new("No route matches"))
      expect { get tags_path(format: :json) }.not_to change(ExceptionLog, :count)
      expect(response).to have_http_status(:method_not_allowed)
    end
  end

  describe "invalid usernames" do
    let(:user) { create(:user).tap { |u| u.update_columns(name: "__bad__name") } }

    before { sign_in_as user }

    it "redirects HTML requests to the name change page" do
      get tags_path
      expect(response).to redirect_to(new_user_name_change_request_path)
    end

    it "lets the name change page itself through" do
      sign_in_as user, reauthenticated: true
      get new_user_name_change_request_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("must not begin with a special character")
    end

    it "does not redirect JSON requests" do
      get tags_path(format: :json)
      expect(response).to have_http_status(:ok)
    end
  end
end

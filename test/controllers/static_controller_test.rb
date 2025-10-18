# frozen_string_literal: true

require "test_helper"

class StaticControllerTest < ActionDispatch::IntegrationTest
  context "The static controller" do
    context "terms_of_service action" do
      should "render" do
        get static_terms_of_service_path
        assert_response :success
      end
    end

    context "rules action" do
      should "render" do
        get static_rules_path
        assert_response :success
      end
    end

    context "api action" do
      should "render" do
        get static_api_path
        assert_response :success
      end
    end

    context "routing" do
      should "route to the static pages" do
        assert_routing "/static/terms_of_service", controller: "static", action: "terms_of_service"
        assert_routing "/static/privacy", controller: "static", action: "privacy"
        assert_routing "/static/rules", controller: "static", action: "rules"
        assert_routing "/static/api", controller: "static", action: "api"
      end

      should "redirect old routes" do
        assert_redirects "/terms_of_use", "/static/terms_of_service", 301
        assert_redirects "/help/api", "/static/api", 301
      end
    end
  end
end

# frozen_string_literal: true

require "rails_helper"

# Route-coverage guarantee for the site map: every linkable index route must be
# either a registered SiteMap page or an explicitly-excluded route. A new index
# route that is neither fails this spec.
RSpec.describe SiteMap do
  # route name (symbol) => "controller#action"
  def self.route_actions
    Rails.application.routes.routes.each_with_object({}) do |route, memo|
      next if route.name.blank?
      memo[route.name.to_sym] = "#{route.defaults[:controller]}##{route.defaults[:action]}"
    end
  end

  # Candidate = a route a human must classify: GET, named, no required dynamic
  # segments, an :index action, and not a framework/engine namespace.
  def self.candidate_actions
    Rails.application.routes.routes.filter_map do |route|
      verb_ok = route.verb.blank? || route.verb.to_s.include?("GET")
      controller = route.defaults[:controller]
      next unless verb_ok && route.name.present? && route.path.required_names.blank?
      next unless route.defaults[:action] == "index" && controller.present?
      next if controller.match?(%r{\A(rails|doorkeeper)/}) || controller == "health"
      "#{controller}##{route.defaults[:action]}"
    end.uniq
  end

  let(:route_actions) { self.class.route_actions }

  def actions_for(route_names)
    route_names.filter_map { |name| route_actions[name.to_sym] }.uniq
  end

  describe "route coverage" do
    it "classifies every candidate index route as a page or an exclusion" do
      covered = actions_for(described_class.registered_route_names + described_class.excluded_route_names)
      unclassified = self.class.candidate_actions - covered

      expect(unclassified).to be_empty,
                              "New linkable index route(s) are neither a SiteMap page nor excluded:\n" \
                              "#{unclassified.sort.join("\n")}\n" \
                              "Add each to SiteMap as a `page` or `exclude` it with a reason."
    end
  end

  describe "registry integrity" do
    it "references only route names that still exist" do
      known = route_actions.keys.map(&:to_s)
      registered = described_class.registered_route_names.map(&:to_s)
      excluded = described_class.excluded_route_names.map(&:to_s)

      expect(registered - known).to be_empty, "SiteMap pages reference missing routes: #{(registered - known).inspect}"
      expect(excluded - known).to be_empty, "SiteMap excludes reference missing routes: #{(excluded - known).inspect}"
    end

    it "never lists the same action as both a page and an exclusion" do
      overlap = actions_for(described_class.registered_route_names) & actions_for(described_class.excluded_route_names)
      expect(overlap).to be_empty, "Action(s) both registered and excluded: #{overlap.inspect}"
    end

    it "uses only known exclusion reasons" do
      bad = described_class.exclusions.map(&:reason) - SiteMap::EXCLUDE_REASONS
      expect(bad).to be_empty, "Unknown exclusion reason(s): #{bad.uniq.inspect}"
    end
  end
end

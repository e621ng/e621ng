# frozen_string_literal: true

require "action_view/dependency_tracker"

# Rails' render parser names a dependency after the method in a render call,
# so `render(FooComponent.new(...))` becomes the partial "news/new" and
# `render(Foo.with_collection(...))` "with_collections/with_collection".
# Neither exists, and every cache digest of such a template logs
# "Couldn't find template for digesting" at error level.
class ComponentRenderTracker < ActionView::DependencyTracker::RubyTracker
  COMPONENT_RENDERS = %w[news/new with_collections/with_collection].freeze

  def dependencies
    super - COMPONENT_RENDERS
  end
end

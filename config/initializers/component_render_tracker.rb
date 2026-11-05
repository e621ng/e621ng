# frozen_string_literal: true

require_relative "../../lib/component_render_tracker"

# Rails' action_view.set_render_tracker initializer re-registers RubyTracker after this file runs
Rails.application.config.after_initialize do
  ActionView::DependencyTracker.register_tracker :erb, ComponentRenderTracker
end

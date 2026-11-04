# frozen_string_literal: true

require_relative "../../lib/component_render_tracker"

ActionView::DependencyTracker.register_tracker :erb, ComponentRenderTracker

# frozen_string_literal: true

require "rails_helper"

# Rails' render parser misreads `render(Component.new(...))` as the partial "news/new" (and
# `.with_collection` as "with_collections/with_collection"), logging "Couldn't find template
# for digesting" on every cache digest. view_component >= 4.20 discards those and tracks the
# component instead.
RSpec.describe ActionView::DependencyTracker, ".find_dependencies" do
  def dependencies(source)
    template = ActionView::Template.new(source, "posts/show.html.erb", ActionView::Template.handler_for_extension(:erb), locals: [], format: :html)
    ActionView::DependencyTracker.find_dependencies("posts/show", template)
  end

  it "tracks components instead of phantom partials" do
    source = <<~ERB
      <%= render(PostThumbnailComponent.new(post: @post)) %>
      <%= render(PostThumbnailComponent.with_collection(@posts)) %>
      <%= render "posts/partials/show/notes" %>
    ERB

    expect(dependencies(source)).to contain_exactly("posts/partials/show/notes", "view_component/cache_digest/post_thumbnail_component")
  end
end

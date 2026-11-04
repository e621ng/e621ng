# frozen_string_literal: true

require "rails_helper"

RSpec.describe ComponentRenderTracker do
  def template(source)
    ActionView::Template.new(source, "posts/show.html.erb", ActionView::Template.handler_for_extension(:erb), locals: [], format: :html)
  end

  it "is the registered tracker for ERB templates" do
    source = <<~ERB
      <%= render(PostThumbnailComponent.new(post: @post)) %>
      <%= render(PostThumbnailComponent.with_collection(@posts)) %>
      <%= render "posts/partials/show/notes" %>
    ERB

    expect(ActionView::DependencyTracker.find_dependencies("posts/show", template(source))).to eq(["posts/partials/show/notes"])
  end

  # If this starts failing, Rails parses component renders correctly and this class can go.
  it "works around Rails misreading component renders as partials" do
    source = "<%= render(PostThumbnailComponent.new(post: @post)) %><%= render(PostThumbnailComponent.with_collection(@posts)) %>"

    expect(ActionView::DependencyTracker::RubyTracker.call("posts/show", template(source))).to match_array(described_class::COMPONENT_RENDERS)
  end

  it "keeps real partial dependencies" do
    expect(described_class.call("posts/show", template(%(<%= render "posts/partials/common/inline_blacklist" %>)))).to eq(["posts/partials/common/inline_blacklist"])
  end
end

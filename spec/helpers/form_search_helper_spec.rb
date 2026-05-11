# frozen_string_literal: true

require "rails_helper"

RSpec.describe FormSearchHelper do
  before do
    allow(helper).to receive_messages(
      params: ActionController::Parameters.new({}),
      request: instance_double(ActionDispatch::Request, path: "/posts"),
    )
  end

  describe "#filled_form_fields" do
    def collect(search_params, exclude_default_fields: [], &block)
      block ||= proc {}
      helper.filled_form_fields(search_params, exclude_default_fields: exclude_default_fields, &block)
    end

    context "with empty search params" do
      it { expect(collect({})).to eq([]) }
    end

    context "when search params contains a default field" do
      it "returns :id when present" do
        expect(collect({ id: "1" })).to include(:id)
      end

      it "returns :created_at when present" do
        expect(collect({ created_at: "2024-01-01" })).to include(:created_at)
      end

      it "returns :updated_at when present" do
        expect(collect({ updated_at: "2024-01-01" })).to include(:updated_at)
      end
    end

    context "when :id is in exclude_default_fields" do
      it "does not return :id even when present in search params" do
        expect(collect({ id: "1" }, exclude_default_fields: [:id])).not_to include(:id)
      end
    end

    context "when the block registers a field" do
      it "returns the field when it is also in search params" do
        expect(collect({ name: "foo" }) { |f| f.input(:name) }).to include(:name)
      end

      it "does not return the field when it is absent from search params" do
        expect(collect({}) { |f| f.input(:name) }).not_to include(:name)
      end
    end

    context "when search params contains a key not registered in the form" do
      it "does not include that key" do
        expect(collect({ ghost_field: "x" })).not_to include(:ghost_field)
      end
    end

    context "when the block calls f.user with a symbol prefix" do
      it "includes :creator_name when present in search params" do
        expect(collect({ creator_name: "bob" }) { |f| f.user(:creator) }).to include(:creator_name)
      end

      it "includes :creator_id when present in search params" do
        expect(collect({ creator_id: "1" }) { |f| f.user(:creator) }).to include(:creator_id)
      end
    end
  end

  describe "#form_search" do
    include_context "as member"

    def render_form(**opts, &block)
      block ||= proc {}
      Nokogiri::HTML.fragment(helper.form_search(path: "/posts", **opts, &block))
    end

    context "when hideable (default for a non-search path)" do
      it "renders the show toggle link" do
        expect(render_form.at_css("#search-form-show-link")).not_to be_nil
      end

      it "renders the hide toggle link" do
        expect(render_form.at_css("#search-form-hide-link")).not_to be_nil
      end
    end

    context "when hideable: false" do
      it "omits the show toggle link" do
        expect(render_form(hideable: false).at_css("#search-form-show-link")).to be_nil
      end

      it "renders #searchform without display:none" do
        expect(render_form(hideable: false).at_css("#searchform")["style"].to_s).not_to include("display:none")
      end
    end

    context "when the path is a dedicated search route" do
      before do
        allow(helper).to receive(:request).and_return(
          instance_double(ActionDispatch::Request, path: "/comments/search"),
        )
      end

      it "is not hideable (omits show toggle link)" do
        expect(render_form.at_css("#search-form-show-link")).to be_nil
      end
    end

    context "with no filled search params" do
      it "renders #searchform with display:none" do
        expect(render_form.at_css("#searchform")["style"]).to include("display:none")
      end
    end

    context "when always_display: true" do
      it "renders #searchform without display:none" do
        expect(render_form(always_display: true).at_css("#searchform")["style"].to_s).not_to include("display:none")
      end
    end

    context "when search params has a filled field" do
      before do
        allow(helper).to receive(:params).and_return(
          ActionController::Parameters.new(search: { id: "1" }),
        )
      end

      it "renders #searchform without display:none" do
        expect(render_form.at_css("#searchform")["style"].to_s).not_to include("display:none")
      end
    end

    context "default field rendering" do
      include_context "as admin"

      it "renders the ID input by default" do
        expect(render_form.at_css("input[name='search[id]']")).not_to be_nil
      end

      it "renders the created_at input by default" do
        expect(render_form.at_css("input[name='search[created_at]']")).not_to be_nil
      end

      it "omits the ID input when :id is in exclude_default_fields" do
        expect(render_form(exclude_default_fields: [:id]).at_css("input[name='search[id]']")).to be_nil
      end
    end
  end
end
